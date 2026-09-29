import {
  BadRequestException,
  Injectable,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import { msg } from '../common/i18n/locale-context.js';
import { InjectRepository } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { DataSource, EntityManager, Repository } from 'typeorm';
import { AgentCreditPayment } from '../database/entities/agent-credit-payment.entity.js';
import {
  Collection,
  CollectionIncomingSplit,
} from '../database/entities/collection.entity.js';
import { FinancialAccount } from '../database/entities/financial-account.entity.js';
import { PurchaseVisa } from '../database/entities/purchase-visa.entity.js';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { Treasury } from '../database/entities/treasury.entity.js';
import { Wallet } from '../database/entities/wallet.entity.js';
import { WalletLimitNoticeService } from '../wallets/wallet-limit-notice.service.js';
import {
  AccountType,
  CollectionStatus,
  ExecutionMode,
  LedgerCategory,
} from '../database/enums.js';
import { ExecuteHoldDto } from './dto/execute-hold.dto.js';
import { ReceiveCollectionDto } from './dto/receive-collection.dto.js';
import { PayAgentCreditDto } from './dto/pay-agent-credit.dto.js';
import {
  profitQrOutgoingFee,
  purchaseVisaProfit,
  profitAccountServiceCommission,
  regularProfitCollectionCommission,
} from '../accounts/profit-commission.js';
import { shouldSeedDemoData } from '../config/demo-data.js';
import { recordWalletIncoming } from '../wallets/wallets.service.js';

@Injectable()
export class CollectionsService implements OnModuleInit {
  constructor(
    @InjectRepository(Collection)
    private readonly collections: Repository<Collection>,
    @InjectRepository(AgentCreditPayment)
    private readonly agentCreditPayments: Repository<AgentCreditPayment>,
    @InjectRepository(Treasury) private readonly treasury: Repository<Treasury>,
    private readonly dataSource: DataSource,
    private readonly config: ConfigService,
    private readonly walletLimitNotices: WalletLimitNoticeService,
  ) {}

  async onModuleInit() {
    if (!(await this.treasury.exists({ where: { id: 'main' } }))) {
      await this.treasury.save({
        id: 'main',
        balance: shouldSeedDemoData(this.config) ? 148750 : 0,
      });
    }
    if (!shouldSeedDemoData(this.config)) return;
    if (await this.collections.count()) return;
    await this.collections.save({
      reference: 'HLD-001',
      agentName: 'أحمد علي',
      companyName: 'جهينة',
      amount: 50000,
      cashAmount: 50000,
      incomingSplits: null,
      agentCreditChange: 0,
      executionMode: ExecutionMode.HOLD,
      status: CollectionStatus.PENDING,
      receivedAt: new Date(),
      executedAt: null,
      account: null,
      commission: 0,
    });
  }

  findAll() {
    return this.collections.find({
      relations: { account: true, purchaseVisa: true },
      order: { createdAt: 'DESC' },
    });
  }

  async findAgentCredits() {
    const rows = await this.collections
      .createQueryBuilder('collection')
      .select('MIN(collection.agentName)', 'agentName')
      .addSelect('LOWER(TRIM(collection.agentName))', 'agentKey')
      .addSelect('SUM(collection.agentCreditChange)', 'balance')
      .addSelect(
        'MAX(collection.receivedAt) FILTER (WHERE collection.agentCreditChange <> 0)',
        'lastActivityAt',
      )
      .addSelect(
        'COUNT(*) FILTER (WHERE collection.agentCreditChange <> 0)',
        'movementsCount',
      )
      .where('collection.status <> :reversed', {
        reversed: CollectionStatus.REVERSED,
      })
      .groupBy('LOWER(TRIM(collection.agentName))')
      .having('SUM(collection.agentCreditChange) > 0')
      .orderBy('SUM(collection.agentCreditChange)', 'DESC')
      .getRawMany<{
        agentName: string;
        agentKey: string;
        balance: string;
        lastActivityAt: Date;
        movementsCount: string;
      }>();
    const payments = await this.agentCreditPayments
      .createQueryBuilder('payment')
      .select('LOWER(TRIM(payment.agentName))', 'agentKey')
      .addSelect('SUM(payment.amount)', 'paid')
      .addSelect('MAX(payment.createdAt)', 'lastPaymentAt')
      .addSelect('COUNT(*)', 'paymentsCount')
      .groupBy('LOWER(TRIM(payment.agentName))')
      .getRawMany<{
        agentKey: string;
        paid: string;
        lastPaymentAt: Date;
        paymentsCount: string;
      }>();
    const paymentsByAgent = new Map(
      payments.map((payment) => [payment.agentKey, payment]),
    );
    return rows
      .map((row) => {
        const payment = paymentsByAgent.get(row.agentKey);
        const balance =
          moneyCents(Number(row.balance) - Number(payment?.paid ?? 0)) / 100;
        const collectionAt = new Date(row.lastActivityAt).getTime();
        const paymentAt = payment?.lastPaymentAt
          ? new Date(payment.lastPaymentAt).getTime()
          : 0;
        return {
          agentName: row.agentName,
          balance,
          lastActivityAt:
            paymentAt > collectionAt
              ? payment!.lastPaymentAt
              : row.lastActivityAt,
          movementsCount:
            Number(row.movementsCount) + Number(payment?.paymentsCount ?? 0),
        };
      })
      .filter((row) => row.balance > 0)
      .sort((left, right) => right.balance - left.balance);
  }

  async payAgentCredit(dto: PayAgentCreditDto, username: string) {
    return this.dataSource.transaction(async (manager) => {
      const agentName = dto.agentName.trim();
      await lockAgentCredit(manager, agentName);
      const currentBalance = await agentCreditBalance(manager, agentName);
      const amount = moneyCents(dto.amount) / 100;
      if (currentBalance <= 0) {
        throw new BadRequestException(
          msg({
            ar: 'المندوب ده ملوش آجل مستحق',
            en: 'This agent has no outstanding credit',
          }),
        );
      }
      if (amount > currentBalance) {
        throw new BadRequestException(
          msg({
            ar: `أقصى مبلغ تسديد هو ${currentBalance}`,
            en: `The maximum repayment is ${currentBalance}`,
          }),
        );
      }

      await manager.query(
        `SELECT pg_advisory_xact_lock(hashtext('hesba:agent-credit-payment-reference'))`,
      );
      const referenceNumber =
        (await manager.getRepository(AgentCreditPayment).count()) + 1;
      const reference = `CRD-${String(referenceNumber).padStart(3, '0')}`;
      const treasury = await manager.getRepository(Treasury).findOne({
        where: { id: 'main' },
        lock: { mode: 'pessimistic_write' },
      });
      if (!treasury) {
        throw new NotFoundException(
          msg({ ar: 'الخزنة غير مهيأة', en: 'Treasury is not initialized' }),
        );
      }
      treasury.balance = Number((Number(treasury.balance) + amount).toFixed(2));
      await manager.getRepository(Treasury).save(treasury);

      const payment = await manager.getRepository(AgentCreditPayment).save({
        reference,
        agentName,
        amount,
        performedBy: username,
      });
      await manager.getRepository(LedgerEntry).save({
        category: LedgerCategory.CASH_RECEIPT,
        amount,
        entityType: 'agent_credit',
        entityId: payment.id,
        reference,
        description: `سداد آجل من المندوب ${agentName}`,
        performedBy: username,
        metadata: {
          agentCreditPayment: true,
          agentName,
          remainingBalance: moneyCents(currentBalance - amount) / 100,
        },
      });
      return {
        ...payment,
        remainingBalance: moneyCents(currentBalance - amount) / 100,
        treasuryBalance: treasury.balance,
      };
    });
  }

  async findOne(id: string) {
    const collection = await this.collections.findOne({
      where: { id },
      relations: { account: true, purchaseVisa: true },
    });
    if (!collection)
      throw new NotFoundException(
        msg({ ar: 'التحصيل غير موجود', en: 'Collection not found' }),
      );
    return collection;
  }

  async receive(dto: ReceiveCollectionDto, username: string) {
    if (dto.executionMode === ExecutionMode.IMMEDIATE) {
      assertOneExecutionSource(dto.accountId, dto.purchaseVisaId);
    }
    const incoming = resolveIncoming(dto);
    const outcome = await this.dataSource.transaction(async (manager) => {
      const dailyNotices: Wallet[] = [];
      // Reference generation must be serialized. count()+1 outside the
      // transaction allowed two simultaneous receipts to choose the same
      // unique reference and made one of them fail.
      await manager.query(
        `SELECT pg_advisory_xact_lock(hashtext('hesba:collection-reference'))`,
      );
      const referenceNumber =
        (await manager.getRepository(Collection).count()) + 1;
      const reference = `${dto.executionMode === ExecutionMode.HOLD ? 'HLD' : 'COL'}-${String(referenceNumber).padStart(3, '0')}`;

      const agentCreditChange =
        (moneyCents(dto.amount) - moneyCents(incoming.totalReceived)) / 100;
      if (dto.useAgentCredit) {
        await lockAgentCredit(manager, dto.agentName);
      }
      if (agentCreditChange < 0) {
        const currentCredit = await agentCreditBalance(manager, dto.agentName);
        if (-agentCreditChange > currentCredit) {
          throw new BadRequestException(
            msg({
              ar: `المبلغ الزيادة ${-agentCreditChange} أكبر من آجل المندوب الحالي ${currentCredit}`,
              en: `The extra payment ${-agentCreditChange} exceeds the agent's current credit ${currentCredit}`,
            }),
          );
        }
      }

      const treasuryRepo = manager.getRepository(Treasury);
      const treasury = await treasuryRepo.findOne({
        where: { id: 'main' },
        lock: { mode: 'pessimistic_write' },
      });
      if (!treasury)
        throw new NotFoundException(
          msg({ ar: 'الخزنة غير مهيأة', en: 'Treasury is not initialized' }),
        );

      let account: FinancialAccount | null = null;
      let visa: PurchaseVisa | null = null;
      let visaProfit = { grossProfit: 0, serviceFee: 0, netProfit: 0 };
      if (dto.executionMode === ExecutionMode.IMMEDIATE && dto.purchaseVisaId) {
        const prepared = await preparePurchaseVisa(
          manager,
          dto.purchaseVisaId,
          Number(dto.amount),
          dto.withService,
        );
        visa = prepared.visa;
        visaProfit = prepared.profit;
        dto.commission = visaProfit.netProfit;
      } else if (dto.executionMode === ExecutionMode.IMMEDIATE) {
        account = await manager.getRepository(FinancialAccount).findOne({
          where: { id: dto.accountId, active: true },
          lock: { mode: 'pessimistic_write' },
        });
        if (!account)
          throw new NotFoundException(
            msg({
              ar: 'الحساب المستخدم غير موجود أو موقوف',
              en: 'Selected account not found or inactive',
            }),
          );
        if (account.type === AccountType.PROFIT) {
          dto.commission = profitCollectionCommissionFor(
            Number(dto.amount),
            dto.withService,
          );
        } else if (account.type === AccountType.PROFIT_QR) {
          dto.commission = -profitQrOutgoingFee(Number(dto.amount));
        }
        const requiredBalance = Number(
          (
            Number(dto.amount) +
            (account.type === AccountType.PROFIT_QR
              ? Math.abs(dto.commission)
              : 0)
          ).toFixed(2),
        );
        if (Number(account.balance) < requiredBalance)
          throw new BadRequestException(
            msg({
              ar: 'رصيد الحساب غير كافٍ لتغطية المبلغ وخصم مكسب',
              en: 'Insufficient account balance for the amount and provider fee',
            }),
          );
        assertNoFawryOperationCommission(account, dto.commission);
      }

      const credited = new Map<string, CollectionIncomingSplit>();
      const orderedParts = [...incoming.parts].sort((left, right) =>
        left.walletId.localeCompare(right.walletId),
      );
      for (const part of orderedParts) {
        const wallet = await manager.getRepository(Wallet).findOne({
          where: { id: part.walletId, active: true },
          lock: { mode: 'pessimistic_write' },
        });
        if (!wallet) {
          throw new NotFoundException(
            msg({
              ar: 'المحفظة غير موجودة أو موقوفة',
              en: 'Wallet not found or inactive',
            }),
          );
        }
        const usage = recordWalletIncoming(wallet, part.amount);
        if (usage.crossedDailyNotice) dailyNotices.push(wallet);
        await manager.getRepository(Wallet).save(wallet);
        credited.set(wallet.id, {
          walletId: wallet.id,
          walletName: wallet.name,
          amount: part.amount,
        });
      }
      const splits = incoming.parts.map((part) => credited.get(part.walletId)!);

      if (incoming.cashAmount > 0) {
        treasury.balance = Number(
          (Number(treasury.balance) + incoming.cashAmount).toFixed(2),
        );
      }
      if (visa) {
        visa.balance = Number(
          (Number(visa.balance) - Number(dto.amount)).toFixed(2),
        );
        visa.commissionBalance = Number(
          (Number(visa.commissionBalance) + visaProfit.netProfit).toFixed(2),
        );
        treasury.balance = Number(
          (Number(treasury.balance) + visaProfit.netProfit).toFixed(2),
        );
        await manager.getRepository(PurchaseVisa).save(visa);
      }
      if (incoming.cashAmount > 0 || visaProfit.netProfit > 0) {
        await treasuryRepo.save(treasury);
      }

      if (account) {
        const accountDebit =
          Number(dto.amount) +
          (account.type === AccountType.PROFIT_QR
            ? Math.abs(Number(dto.commission))
            : 0);
        account.balance = Number(
          (Number(account.balance) - accountDebit).toFixed(2),
        );
        account.commissionBalance = Number(
          (Number(account.commissionBalance) + Number(dto.commission)).toFixed(
            2,
          ),
        );
        await manager.getRepository(FinancialAccount).save(account);
      }

      const collection = await manager.getRepository(Collection).save({
        reference,
        agentName: dto.agentName,
        companyName: dto.companyName,
        amount: dto.amount,
        cashAmount: incoming.cashAmount,
        incomingSplits: splits.length ? splits : null,
        agentCreditChange,
        executionMode: dto.executionMode,
        status:
          dto.executionMode === ExecutionMode.IMMEDIATE
            ? CollectionStatus.DONE
            : CollectionStatus.PENDING,
        receivedAt: dto.receivedAt ? new Date(dto.receivedAt) : new Date(),
        executedAt:
          dto.executionMode === ExecutionMode.IMMEDIATE ? new Date() : null,
        account,
        purchaseVisa: visa,
        withService:
          visa || account?.type === AccountType.PROFIT
            ? (dto.withService ?? null)
            : null,
        commission: dto.commission,
      });

      const ledger = manager.getRepository(LedgerEntry);
      if (incoming.cashAmount > 0) {
        await ledger.save({
          category: LedgerCategory.CASH_RECEIPT,
          amount: incoming.cashAmount,
          entityType: 'collection',
          entityId: collection.id,
          reference,
          description: splits.length
            ? `استلام كاش ${incoming.cashAmount} من أصل ${dto.amount} من ${dto.agentName} لصالح ${dto.companyName}`
            : `استلام كاش من ${dto.agentName} لصالح ${dto.companyName}`,
          performedBy: username,
          metadata: splits.length
            ? {
                collectionSplit: true,
                totalAmount: dto.amount,
                agentCreditChange,
              }
            : agentCreditChange !== 0
              ? { totalAmount: dto.amount, agentCreditChange }
              : null,
        });
      }
      for (const split of splits) {
        await ledger.save({
          category: LedgerCategory.TOP_UP,
          amount: split.amount,
          entityType: 'wallet',
          entityId: split.walletId,
          reference,
          description: `استلام ${split.amount} على محفظة ${split.walletName} من مندوب ${dto.agentName} لصالح ${dto.companyName}`,
          performedBy: username,
          metadata: {
            collectionReceipt: true,
            collectionId: collection.id,
          },
        });
      }
      if (account) {
        await ledger.save({
          category: LedgerCategory.COMPANY_EXECUTION,
          amount: -dto.amount,
          entityType: 'account',
          entityId: account.id,
          reference,
          description: `تنفيذ فوري لصالح ${dto.companyName}`,
          performedBy: username,
          metadata: splits.length
            ? {
                collectionSplit: true,
                cashAmount: incoming.cashAmount,
                totalAmount: dto.amount,
              }
            : null,
        });
        if (dto.commission !== 0) {
          await ledger.save({
            category: LedgerCategory.COMMISSION,
            amount: dto.commission,
            entityType: 'account',
            entityId: account.id,
            reference,
            description:
              dto.commission < 0
                ? `خصم مكسب QR عند التوريد لصالح ${dto.companyName}: ٤ جنيه لكل ألف`
                : `عمولة تنفيذ لصالح ${dto.companyName}`,
            performedBy: username,
          });
        }
      }
      if (visa) {
        await recordPurchaseVisaCollection(manager, {
          visa,
          amount: Number(dto.amount),
          profit: visaProfit,
          withService: dto.withService!,
          reference,
          companyName: dto.companyName,
          agentName: dto.agentName,
          collectionId: collection.id,
          username,
          pending: false,
        });
      }
      return { collection, dailyNotices };
    });
    for (const wallet of outcome.dailyNotices) {
      await this.walletLimitNotices.notifyDailyThreshold(wallet);
    }
    return outcome.collection;
  }

  async execute(id: string, dto: ExecuteHoldDto, username: string) {
    const outcome = await this.dataSource.transaction(async (manager) => {
      const dailyNotices: Wallet[] = [];
      const collectionRepo = manager.getRepository(Collection);
      const collection = await collectionRepo.findOne({
        where: { id },
        lock: { mode: 'pessimistic_write' },
      });
      if (!collection)
        throw new NotFoundException(
          msg({ ar: 'المعلّق غير موجود', en: 'Pending item not found' }),
        );
      if (collection.status !== CollectionStatus.PENDING)
        throw new BadRequestException(
          msg({ ar: 'العملية منفذة بالفعل', en: 'Operation already executed' }),
        );
      assertOneExecutionSource(dto.accountId, dto.purchaseVisaId);
      if (dto.purchaseVisaId) {
        const treasury = await manager.getRepository(Treasury).findOne({
          where: { id: 'main' },
          lock: { mode: 'pessimistic_write' },
        });
        if (!treasury)
          throw new NotFoundException(
            msg({ ar: 'الخزنة غير مهيأة', en: 'Treasury is not initialized' }),
          );
        const prepared = await preparePurchaseVisa(
          manager,
          dto.purchaseVisaId,
          Number(collection.amount),
          dto.withService,
        );
        const { visa, profit } = prepared;
        visa.balance = Number(
          (Number(visa.balance) - Number(collection.amount)).toFixed(2),
        );
        visa.commissionBalance = Number(
          (Number(visa.commissionBalance) + profit.netProfit).toFixed(2),
        );
        treasury.balance = Number(
          (Number(treasury.balance) + profit.netProfit).toFixed(2),
        );
        await manager.getRepository(PurchaseVisa).save(visa);
        if (profit.netProfit > 0) await manager.save(treasury);
        collection.status = CollectionStatus.DONE;
        collection.executedAt = new Date();
        collection.purchaseVisa = visa;
        collection.withService = dto.withService!;
        collection.commission = profit.netProfit;
        await collectionRepo.save(collection);
        await recordPurchaseVisaCollection(manager, {
          visa,
          amount: Number(collection.amount),
          profit,
          withService: dto.withService!,
          reference: collection.reference,
          companyName: collection.companyName,
          agentName: collection.agentName,
          collectionId: collection.id,
          username,
          pending: true,
        });
      } else {
        const account = await manager.getRepository(FinancialAccount).findOne({
          where: { id: dto.accountId, active: true },
          lock: { mode: 'pessimistic_write' },
        });
        if (!account)
          throw new NotFoundException(
            msg({
              ar: 'الحساب المستخدم غير موجود أو موقوف',
              en: 'Selected account not found or inactive',
            }),
          );
        if (account.type === AccountType.PROFIT) {
          dto.commission = profitCollectionCommissionFor(
            Number(collection.amount),
            dto.withService,
          );
          collection.withService = dto.withService ?? null;
        } else if (account.type === AccountType.PROFIT_QR) {
          dto.commission = -profitQrOutgoingFee(Number(collection.amount));
        }
        const accountDebit =
          Number(collection.amount) +
          (account.type === AccountType.PROFIT_QR
            ? Math.abs(Number(dto.commission))
            : 0);
        if (Number(account.balance) < accountDebit)
          throw new BadRequestException(
            msg({
              ar: 'رصيد الحساب غير كافٍ لتغطية المبلغ وخصم مكسب',
              en: 'Insufficient account balance for the amount and provider fee',
            }),
          );
        assertNoFawryOperationCommission(account, dto.commission);
        account.balance = Number(
          (Number(account.balance) - accountDebit).toFixed(2),
        );
        account.commissionBalance += dto.commission;
        await manager.getRepository(FinancialAccount).save(account);
        collection.status = CollectionStatus.DONE;
        collection.executedAt = new Date();
        collection.account = account;
        collection.commission = dto.commission;
        await collectionRepo.save(collection);
        await manager.getRepository(LedgerEntry).save({
          category: LedgerCategory.COMPANY_EXECUTION,
          amount: -collection.amount,
          entityType: 'account',
          entityId: account.id,
          reference: collection.reference,
          description: `تنفيذ المعلّق لصالح ${collection.companyName}`,
          performedBy: username,
        });
        if (dto.commission !== 0) {
          await manager.getRepository(LedgerEntry).save({
            category: LedgerCategory.COMMISSION,
            amount: dto.commission,
            entityType: 'account',
            entityId: account.id,
            reference: collection.reference,
            description:
              dto.commission < 0
                ? `خصم مكسب QR عند تنفيذ المعلّق لصالح ${collection.companyName}: ٤ جنيه لكل ألف`
                : `عمولة تنفيذ المعلّق لصالح ${collection.companyName}`,
            performedBy: username,
          });
        }
      }
      await applyHeldIncoming(manager, collection, dto, username, dailyNotices);
      return { collection, dailyNotices };
    });
    for (const wallet of outcome.dailyNotices) {
      await this.walletLimitNotices.notifyDailyThreshold(wallet);
    }
    return outcome.collection;
  }
}

function assertOneExecutionSource(accountId?: string, purchaseVisaId?: string) {
  if (accountId && purchaseVisaId) {
    throw new BadRequestException(
      msg({
        ar: 'اختار حساب تنفيذ أو فيزا مشتريات، مش الاتنين',
        en: 'Choose an execution account or a purchase visa, not both',
      }),
    );
  }
  if (!accountId && !purchaseVisaId) {
    throw new BadRequestException(
      msg({
        ar: 'الحساب المستخدم مطلوب للتنفيذ',
        en: 'An execution account is required',
      }),
    );
  }
}

async function preparePurchaseVisa(
  manager: EntityManager,
  visaId: string,
  amount: number,
  withService: boolean | undefined,
) {
  if (typeof withService !== 'boolean') {
    throw new BadRequestException(
      msg({
        ar: 'حدد لو سحب الفيزا بخدمة ولا من غير خدمة',
        en: 'Choose whether the visa withdrawal includes machine service',
      }),
    );
  }
  const visa = await manager.getRepository(PurchaseVisa).findOne({
    where: { id: visaId, active: true },
    lock: { mode: 'pessimistic_write' },
  });
  if (!visa) {
    throw new NotFoundException(
      msg({
        ar: 'فيزا المشتريات غير موجودة أو موقوفة',
        en: 'Purchase visa not found or inactive',
      }),
    );
  }
  if (Number(visa.balance) < amount) {
    throw new BadRequestException(
      msg({ ar: 'رصيد الفيزا غير كافٍ', en: 'Insufficient visa balance' }),
    );
  }
  return { visa, profit: purchaseVisaProfit(amount, withService) };
}

async function recordPurchaseVisaCollection(
  manager: EntityManager,
  args: {
    visa: PurchaseVisa;
    amount: number;
    profit: { grossProfit: number; serviceFee: number; netProfit: number };
    withService: boolean;
    reference: string;
    companyName: string;
    agentName: string;
    collectionId: string;
    username: string;
    pending: boolean;
  },
) {
  const ledger = manager.getRepository(LedgerEntry);
  const serviceText = args.withService
    ? `بخدمة ماكينة ${args.profit.serviceFee.toFixed(2)} ج.م، وصافي المكسب ${args.profit.netProfit.toFixed(2)} ج.م`
    : `من غير خدمة، والمكسب ${args.profit.netProfit.toFixed(2)} ج.م`;
  const verb = args.pending ? 'تنفيذ المعلّق' : 'تنفيذ فوري';
  await ledger.save({
    category: LedgerCategory.PURCHASE_VISA_USAGE,
    amount: -args.amount,
    entityType: 'purchase_visa',
    entityId: args.visa.id,
    sourceType: 'purchase_visa',
    sourceId: args.visa.id,
    reference: args.reference,
    description: `${verb} ${args.amount.toFixed(2)} ج.م من فيزا ${args.visa.name} لصالح ${args.companyName} للمندوب ${args.agentName}. ${serviceText}`,
    performedBy: args.username,
    metadata: {
      collectionId: args.collectionId,
      visaId: args.visa.id,
      principal: args.amount,
      withService: args.withService,
      grossProfit: args.profit.grossProfit,
      serviceFee: args.profit.serviceFee,
      netProfit: args.profit.netProfit,
    },
  });
  if (args.profit.netProfit <= 0) return;
  await ledger.save({
    category: LedgerCategory.PURCHASE_VISA_USAGE,
    amount: args.profit.netProfit,
    entityType: 'treasury',
    entityId: 'main',
    sourceType: 'purchase_visa',
    sourceId: args.visa.id,
    reference: args.reference,
    description: `مكسب فيزا ${args.visa.name} دخل الخزنة ${args.profit.netProfit.toFixed(2)} ج.م`,
    performedBy: args.username,
    metadata: {
      collectionId: args.collectionId,
      visaId: args.visa.id,
      netProfit: args.profit.netProfit,
      withService: args.withService,
    },
  });
  await ledger.save({
    category: LedgerCategory.COMMISSION,
    amount: args.profit.netProfit,
    entityType: 'purchase_visa',
    entityId: args.visa.id,
    reference: args.reference,
    description: args.withService
      ? `مكسب فيزا ${args.visa.name}: ١٣ جنيه لكل ألف بعد خصم خدمة الماكينة`
      : `مكسب فيزا ${args.visa.name}: ٢٠ جنيه لكل ألف`,
    performedBy: args.username,
    metadata: { collectionId: args.collectionId },
  });
}

function moneyCents(value: number): number {
  return Math.round(Number(value) * 100);
}

function resolveIncoming(dto: {
  amount: number;
  executionMode: ExecutionMode;
  cashAmount?: number | null;
  incomingParts?: Array<{ walletId: string; amount: number }>;
  useAgentCredit?: boolean;
}): {
  cashAmount: number;
  parts: Array<{ walletId: string; amount: number }>;
  totalReceived: number;
} {
  const parts = dto.incomingParts ?? [];
  const cashSpecified = dto.cashAmount !== undefined && dto.cashAmount !== null;
  if (parts.length === 0 && !cashSpecified) {
    if (dto.useAgentCredit) {
      throw new BadRequestException(
        msg({
          ar: 'اكتب المبلغ المستلم فعليًا لحساب آجل المندوب',
          en: 'Enter the amount actually received to calculate agent credit',
        }),
      );
    }
    const amount = moneyCents(dto.amount) / 100;
    return { cashAmount: amount, parts: [], totalReceived: amount };
  }
  if (dto.executionMode !== ExecutionMode.IMMEDIATE) {
    throw new BadRequestException(
      msg({
        ar: 'تقسيم الداخل وآجل المندوب متاحان مع التنفيذ الفوري فقط',
        en: 'Incoming splits and agent credit are only available for immediate execution',
      }),
    );
  }
  if (parts.length > 0 && !cashSpecified) {
    throw new BadRequestException(
      msg({
        ar: 'حدد مبلغ الكاش اللي يدخل الخزنة ومبلغ كل محفظة',
        en: 'Enter the treasury cash and each wallet amount',
      }),
    );
  }
  const ids = parts.map((part) => part.walletId);
  if (new Set(ids).size !== ids.length) {
    throw new BadRequestException(
      msg({
        ar: 'المحفظة متكررة. اجمع مبلغها في سطر واحد',
        en: 'The same wallet is listed twice. Combine its amount on one line',
      }),
    );
  }
  const normalized = parts.map((part) => ({
    walletId: part.walletId,
    amount: moneyCents(part.amount) / 100,
  }));
  const cashAmount = cashSpecified ? moneyCents(dto.cashAmount!) / 100 : 0;
  const combined =
    moneyCents(cashAmount) +
    normalized.reduce((sum, part) => sum + moneyCents(part.amount), 0);
  if (!dto.useAgentCredit && combined !== moneyCents(dto.amount)) {
    throw new BadRequestException(
      msg({
        ar: 'مجموع الكاش وأجزاء المحافظ لازم يساوي المبلغ الكلي',
        en: 'Cash plus wallet portions must equal the total amount',
      }),
    );
  }
  return {
    cashAmount,
    parts: normalized,
    totalReceived: combined / 100,
  };
}

async function agentCreditBalance(
  manager: EntityManager,
  agentName: string,
): Promise<number> {
  const creditResult = await manager
    .getRepository(Collection)
    .createQueryBuilder('collection')
    .select('COALESCE(SUM(collection.agentCreditChange), 0)', 'balance')
    .where('LOWER(TRIM(collection.agentName)) = LOWER(TRIM(:agentName))', {
      agentName,
    })
    .andWhere('collection.status <> :reversed', {
      reversed: CollectionStatus.REVERSED,
    })
    .getRawOne<{ balance: string }>();
  const paymentResult = await manager
    .getRepository(AgentCreditPayment)
    .createQueryBuilder('payment')
    .select('COALESCE(SUM(payment.amount), 0)', 'paid')
    .where('LOWER(TRIM(payment.agentName)) = LOWER(TRIM(:agentName))', {
      agentName,
    })
    .getRawOne<{ paid: string }>();
  return (
    moneyCents(
      Number(creditResult?.balance ?? 0) - Number(paymentResult?.paid ?? 0),
    ) / 100
  );
}

function lockAgentCredit(manager: EntityManager, agentName: string) {
  return manager.query(`SELECT pg_advisory_xact_lock(hashtext($1))`, [
    `hesba:agent-credit:${agentName.trim().toLowerCase()}`,
  ]);
}

function profitCollectionCommissionFor(
  amount: number,
  withService?: boolean,
): number {
  if (typeof withService === 'boolean') {
    return profitAccountServiceCommission(amount, withService);
  }
  return regularProfitCollectionCommission(amount);
}

async function applyHeldIncoming(
  manager: EntityManager,
  collection: Collection,
  dto: ExecuteHoldDto,
  username: string,
  dailyNotices: Wallet[],
) {
  const incoming = resolveIncoming({
    amount: Number(collection.amount),
    executionMode: ExecutionMode.IMMEDIATE,
    cashAmount: dto.cashAmount,
    incomingParts: dto.incomingParts,
    useAgentCredit: dto.useAgentCredit,
  });
  const booked = Number(collection.cashAmount ?? collection.amount);
  const treasuryDelta =
    (moneyCents(incoming.cashAmount) - moneyCents(booked)) / 100;
  const hasParts = incoming.parts.length > 0;
  if (!dto.useAgentCredit && !hasParts && treasuryDelta === 0) return;

  let agentCreditChange = Number(collection.agentCreditChange);
  if (dto.useAgentCredit) {
    await lockAgentCredit(manager, collection.agentName);
    agentCreditChange =
      (moneyCents(Number(collection.amount)) -
        moneyCents(incoming.totalReceived)) /
      100;
    if (agentCreditChange < 0) {
      const currentCredit = await agentCreditBalance(
        manager,
        collection.agentName,
      );
      if (-agentCreditChange > currentCredit) {
        throw new BadRequestException(
          msg({
            ar: `المبلغ الزيادة ${-agentCreditChange} أكبر من آجل المندوب الحالي ${currentCredit}`,
            en: `The extra payment ${-agentCreditChange} exceeds the agent's current credit ${currentCredit}`,
          }),
        );
      }
    }
  }

  const credited = new Map<string, CollectionIncomingSplit>();
  const orderedParts = [...incoming.parts].sort((left, right) =>
    left.walletId.localeCompare(right.walletId),
  );
  for (const part of orderedParts) {
    const wallet = await manager.getRepository(Wallet).findOne({
      where: { id: part.walletId, active: true },
      lock: { mode: 'pessimistic_write' },
    });
    if (!wallet) {
      throw new NotFoundException(
        msg({
          ar: 'المحفظة غير موجودة أو موقوفة',
          en: 'Wallet not found or inactive',
        }),
      );
    }
    const usage = recordWalletIncoming(wallet, part.amount);
    if (usage.crossedDailyNotice) dailyNotices.push(wallet);
    await manager.getRepository(Wallet).save(wallet);
    credited.set(wallet.id, {
      walletId: wallet.id,
      walletName: wallet.name,
      amount: part.amount,
    });
  }
  const splits = incoming.parts.map((part) => credited.get(part.walletId)!);

  const ledger = manager.getRepository(LedgerEntry);
  if (treasuryDelta !== 0) {
    const treasury = await manager.getRepository(Treasury).findOne({
      where: { id: 'main' },
      lock: { mode: 'pessimistic_write' },
    });
    if (!treasury) {
      throw new NotFoundException(
        msg({ ar: 'الخزنة غير مهيأة', en: 'Treasury is not initialized' }),
      );
    }
    const nextBalance = Number(
      (Number(treasury.balance) + treasuryDelta).toFixed(2),
    );
    if (nextBalance < 0) {
      throw new BadRequestException(
        msg({
          ar: 'رصيد الخزنة مش كفاية لتحويل جزء الكاش للمحافظ',
          en: 'Treasury balance is not enough to move cash into wallets',
        }),
      );
    }
    treasury.balance = nextBalance;
    await manager.save(treasury);
    await ledger.save({
      category: LedgerCategory.CASH_RECEIPT,
      amount: treasuryDelta,
      entityType: 'collection',
      entityId: collection.id,
      reference: collection.reference,
      description:
        treasuryDelta < 0
          ? `تحويل ${Math.abs(treasuryDelta).toFixed(2)} من كاش المعلّق ${collection.reference} إلى المحافظ`
          : `تعديل كاش تنفيذ المعلّق ${collection.reference}`,
      performedBy: username,
      metadata: {
        heldIncomingAdjustment: true,
        cashAmount: incoming.cashAmount,
        agentCreditChange,
      },
    });
  }
  for (const split of splits) {
    await ledger.save({
      category: LedgerCategory.TOP_UP,
      amount: split.amount,
      entityType: 'wallet',
      entityId: split.walletId,
      reference: collection.reference,
      description: `تنفيذ المعلّق ${collection.reference}: ${split.amount} على محفظة ${split.walletName}`,
      performedBy: username,
      metadata: {
        collectionReceipt: true,
        collectionId: collection.id,
        heldIncomingAdjustment: true,
      },
    });
  }

  collection.cashAmount = incoming.cashAmount;
  collection.incomingSplits = splits.length ? splits : null;
  collection.agentCreditChange = agentCreditChange;
  await manager.getRepository(Collection).save(collection);
}

function assertNoFawryOperationCommission(
  account: FinancialAccount,
  commission: number,
) {
  if (account.type === AccountType.FAWRY && commission > 0) {
    throw new BadRequestException(
      msg({
        ar: 'عمولة فوري لا تُسجل مع العملية. الأدمن يسجل النزلة في اليوم التالي',
        en: 'Fawry commission is not recorded on the operation. The admin records the next-day drop',
      }),
    );
  }
}

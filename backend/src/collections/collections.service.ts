import {
  BadRequestException,
  Injectable,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import { msg } from '../common/i18n/locale-context.js';
import { InjectRepository } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { DataSource, Repository } from 'typeorm';
import {
  Collection,
  CollectionIncomingSplit,
} from '../database/entities/collection.entity.js';
import { FinancialAccount } from '../database/entities/financial-account.entity.js';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { Treasury } from '../database/entities/treasury.entity.js';
import { Wallet } from '../database/entities/wallet.entity.js';
import {
  AccountType,
  CollectionStatus,
  ExecutionMode,
  LedgerCategory,
} from '../database/enums.js';
import { ExecuteHoldDto } from './dto/execute-hold.dto.js';
import { ReceiveCollectionDto } from './dto/receive-collection.dto.js';
import { shouldSeedDemoData } from '../config/demo-data.js';
import { recordWalletIncoming } from '../wallets/wallets.service.js';

@Injectable()
export class CollectionsService implements OnModuleInit {
  constructor(
    @InjectRepository(Collection)
    private readonly collections: Repository<Collection>,
    @InjectRepository(Treasury) private readonly treasury: Repository<Treasury>,
    private readonly dataSource: DataSource,
    private readonly config: ConfigService,
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
      relations: { account: true },
      order: { createdAt: 'DESC' },
    });
  }

  async findOne(id: string) {
    const collection = await this.collections.findOne({
      where: { id },
      relations: { account: true },
    });
    if (!collection) throw new NotFoundException(msg({ ar: 'التحصيل غير موجود', en: 'Collection not found' }));
    return collection;
  }

  async receive(dto: ReceiveCollectionDto, username: string) {
    if (dto.executionMode === ExecutionMode.IMMEDIATE && !dto.accountId) {
      throw new BadRequestException(msg({ ar: 'الحساب المستخدم مطلوب للتنفيذ الفوري', en: 'An account is required for immediate execution' }));
    }
    const incoming = resolveIncoming(dto);
    return this.dataSource.transaction(async (manager) => {
      // Reference generation must be serialized. count()+1 outside the
      // transaction allowed two simultaneous receipts to choose the same
      // unique reference and made one of them fail.
      await manager.query(
        `SELECT pg_advisory_xact_lock(hashtext('hesba:collection-reference'))`,
      );
      const referenceNumber =
        (await manager.getRepository(Collection).count()) + 1;
      const reference = `${dto.executionMode === ExecutionMode.HOLD ? 'HLD' : 'COL'}-${String(referenceNumber).padStart(3, '0')}`;

      const treasuryRepo = manager.getRepository(Treasury);
      const treasury = await treasuryRepo.findOne({
        where: { id: 'main' },
        lock: { mode: 'pessimistic_write' },
      });
      if (!treasury) throw new NotFoundException(msg({ ar: 'الخزنة غير مهيأة', en: 'Treasury is not initialized' }));

      let account: FinancialAccount | null = null;
      if (dto.executionMode === ExecutionMode.IMMEDIATE) {
        account = await manager.getRepository(FinancialAccount).findOne({
          where: { id: dto.accountId, active: true },
          lock: { mode: 'pessimistic_write' },
        });
        if (!account)
          throw new NotFoundException(msg({ ar: 'الحساب المستخدم غير موجود أو موقوف', en: 'Selected account not found or inactive' }));
        if (Number(account.balance) < Number(dto.amount))
          throw new BadRequestException(msg({ ar: 'رصيد الحساب غير كافٍ', en: 'Insufficient account balance' }));
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
        recordWalletIncoming(wallet, part.amount);
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
        await treasuryRepo.save(treasury);
      }

      if (account) {
        account.balance = Number(
          (Number(account.balance) - Number(dto.amount)).toFixed(2),
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
        executionMode: dto.executionMode,
        status:
          dto.executionMode === ExecutionMode.IMMEDIATE
            ? CollectionStatus.DONE
            : CollectionStatus.PENDING,
        receivedAt: dto.receivedAt ? new Date(dto.receivedAt) : new Date(),
        executedAt:
          dto.executionMode === ExecutionMode.IMMEDIATE ? new Date() : null,
        account,
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
            ? { collectionSplit: true, totalAmount: dto.amount }
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
        if (dto.commission > 0) {
          await ledger.save({
            category: LedgerCategory.COMMISSION,
            amount: dto.commission,
            entityType: 'account',
            entityId: account.id,
            reference,
            description: `عمولة تنفيذ لصالح ${dto.companyName}`,
            performedBy: username,
          });
        }
      }
      return collection;
    });
  }

  async execute(id: string, dto: ExecuteHoldDto, username: string) {
    return this.dataSource.transaction(async (manager) => {
      const collectionRepo = manager.getRepository(Collection);
      const collection = await collectionRepo.findOne({
        where: { id },
        lock: { mode: 'pessimistic_write' },
      });
      if (!collection) throw new NotFoundException(msg({ ar: 'المعلّق غير موجود', en: 'Pending item not found' }));
      if (collection.status !== CollectionStatus.PENDING)
        throw new BadRequestException(msg({ ar: 'العملية منفذة بالفعل', en: 'Operation already executed' }));
      const account = await manager.getRepository(FinancialAccount).findOne({
        where: { id: dto.accountId, active: true },
        lock: { mode: 'pessimistic_write' },
      });
      if (!account)
        throw new NotFoundException(msg({ ar: 'الحساب المستخدم غير موجود أو موقوف', en: 'Selected account not found or inactive' }));
      if (account.balance < collection.amount)
        throw new BadRequestException(msg({ ar: 'رصيد الحساب غير كافٍ', en: 'Insufficient account balance' }));
      assertNoFawryOperationCommission(account, dto.commission);
      account.balance -= collection.amount;
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
      if (dto.commission > 0) {
        await manager.getRepository(LedgerEntry).save({
          category: LedgerCategory.COMMISSION,
          amount: dto.commission,
          entityType: 'account',
          entityId: account.id,
          reference: collection.reference,
          description: `عمولة تنفيذ المعلّق لصالح ${collection.companyName}`,
          performedBy: username,
        });
      }
      return collection;
    });
  }
}

function moneyCents(value: number): number {
  return Math.round(Number(value) * 100);
}

function resolveIncoming(dto: ReceiveCollectionDto): {
  cashAmount: number;
  parts: Array<{ walletId: string; amount: number }>;
} {
  const parts = dto.incomingParts ?? [];
  const cashSpecified = dto.cashAmount !== undefined && dto.cashAmount !== null;
  if (parts.length === 0 && !cashSpecified) {
    return { cashAmount: moneyCents(dto.amount) / 100, parts: [] };
  }
  if (dto.executionMode !== ExecutionMode.IMMEDIATE) {
    throw new BadRequestException(
      msg({
        ar: 'تقسيم الداخل متاح مع التنفيذ الفوري فقط',
        en: 'Splitting the incoming amount is only available for immediate execution',
      }),
    );
  }
  if (parts.length === 0 || !cashSpecified) {
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
  const cashAmount = moneyCents(dto.cashAmount!) / 100;
  const combined =
    moneyCents(cashAmount) +
    normalized.reduce((sum, part) => sum + moneyCents(part.amount), 0);
  if (combined !== moneyCents(dto.amount)) {
    throw new BadRequestException(
      msg({
        ar: 'مجموع الكاش وأجزاء المحافظ لازم يساوي المبلغ الكلي',
        en: 'Cash plus wallet portions must equal the total amount',
      }),
    );
  }
  return { cashAmount, parts: normalized };
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

import {
  BadRequestException,
  Injectable,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import { msg } from '../common/i18n/locale-context.js';
import { InjectRepository } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { Brackets, DataSource, In, Repository } from 'typeorm';
import { FawryDailyDrop } from '../database/entities/fawry-daily-drop.entity.js';
import {
  FawryDeposit,
  type FawryCashCounts,
} from '../database/entities/fawry-deposit.entity.js';
import { FinancialAccount } from '../database/entities/financial-account.entity.js';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { Treasury } from '../database/entities/treasury.entity.js';
import { User } from '../database/entities/user.entity.js';
import { AccountType, LedgerCategory } from '../database/enums.js';
import { cairoParts } from './cairo-time.js';
import { CreateAccountDto } from './dto/create-account.dto.js';
import { RecordFawryDepositDto } from './dto/record-fawry-deposit.dto.js';
import { ProfitQrCashOutDto } from './dto/profit-qr-cash-out.dto.js';
import { TopUpAccountDto } from './dto/top-up-account.dto.js';
import { shouldSeedDemoData } from '../config/demo-data.js';
import { UsersService } from '../users/users.service.js';
import {
  REGULAR_PROFIT_LIMIT,
  profitQrCustomerCommission,
  profitQrIncomingFee,
  regularProfitDepositCommission,
} from './profit-commission.js';

export const FAWRY_MAX_BALANCE = 5_000_000;

@Injectable()
export class AccountsService implements OnModuleInit {
  constructor(
    @InjectRepository(FinancialAccount)
    private readonly accounts: Repository<FinancialAccount>,
    @InjectRepository(LedgerEntry)
    private readonly ledger: Repository<LedgerEntry>,
    @InjectRepository(FawryDailyDrop)
    private readonly drops: Repository<FawryDailyDrop>,
    @InjectRepository(FawryDeposit)
    private readonly deposits: Repository<FawryDeposit>,
    private readonly dataSource: DataSource,
    private readonly config: ConfigService,
    private readonly users: UsersService,
  ) {}

  async onModuleInit() {
    if (!shouldSeedDemoData(this.config)) return;
    if (await this.accounts.count()) return;
    await this.accounts.save([
      this.accounts.create({
        name: 'حساب فوري 01',
        type: AccountType.FAWRY,
        openingBalance: 82400,
        balance: 82400,
      }),
      this.accounts.create({
        name: 'حساب شركة 01',
        type: AccountType.COMPANY,
        openingBalance: 36500,
        balance: 36500,
      }),
    ]);
  }

  findAll(includeInactive = false) {
    return this.accounts.find({
      where: includeInactive ? {} : { active: true },
      order: { createdAt: 'ASC' },
    });
  }

  fawryDepositors() {
    return this.users.findActiveOptions();
  }

  findFawryDeposits(limit = 100) {
    return this.deposits.find({
      order: { createdAt: 'DESC' },
      take: Math.min(Math.max(limit, 1), 500),
    });
  }

  async create(dto: CreateAccountDto, username: string) {
    if (
      dto.type === AccountType.FAWRY &&
      dto.openingBalance > FAWRY_MAX_BALANCE
    ) {
      throw new BadRequestException(
        msg({
          ar: 'الرصيد الافتتاحي يتجاوز الحد الأقصى لحساب فوري',
          en: 'Opening balance exceeds the Fawry account maximum',
        }),
      );
    }
    if (
      dto.type === AccountType.PROFIT &&
      dto.openingBalance > REGULAR_PROFIT_LIMIT
    ) {
      throw new BadRequestException(
        msg({
          ar: 'الرصيد الافتتاحي يتجاوز الحد الأقصى لحساب المكسب العادي',
          en: 'Opening balance exceeds the regular profit account maximum',
        }),
      );
    }
    return this.dataSource.transaction(async (manager) => {
      const repo = manager.getRepository(FinancialAccount);
      const account = await repo.save(
        repo.create({
          name: dto.name,
          type: dto.type,
          openingBalance: dto.openingBalance,
          balance: dto.openingBalance,
        }),
      );
      if (dto.openingBalance > 0) {
        await manager.getRepository(LedgerEntry).save({
          category: LedgerCategory.OPENING_BALANCE,
          amount: dto.openingBalance,
          entityType: 'account',
          entityId: account.id,
          reference: null,
          description: `رصيد افتتاحي للحساب ${account.name}`,
          performedBy: username,
        });
      }
      return account;
    });
  }

  async topUp(id: string, dto: TopUpAccountDto, username: string) {
    return this.dataSource.transaction(async (manager) => {
      const repo = manager.getRepository(FinancialAccount);
      const account = await repo.findOne({
        where: { id, active: true },
        lock: { mode: 'pessimistic_write' },
      });
      if (!account)
        throw new NotFoundException(
          msg({
            ar: 'الحساب غير موجود أو موقوف',
            en: 'Account not found or inactive',
          }),
        );
      if (account.type === AccountType.PROFIT_QR) {
        throw new BadRequestException(
          msg({
            ar: 'حساب مكسب QR لا يُشحن مباشرة؛ استخدم عملية سحب كاش لعميل',
            en: 'QR profit accounts cannot be topped up directly; use a customer cash-out operation',
          }),
        );
      }
      const nextBalance = Number(
        (Number(account.balance) + dto.amount).toFixed(2),
      );
      if (
        account.type === AccountType.FAWRY &&
        nextBalance > FAWRY_MAX_BALANCE
      ) {
        throw new BadRequestException({
          message: msg({
            ar: 'سيتم تجاوز الحد الأقصى لحساب فوري',
            en: 'This would exceed the Fawry account maximum',
          }),
          limit: FAWRY_MAX_BALANCE,
          available: Math.max(0, FAWRY_MAX_BALANCE - Number(account.balance)),
        });
      }
      if (
        account.type === AccountType.PROFIT &&
        nextBalance > REGULAR_PROFIT_LIMIT
      ) {
        throw new BadRequestException({
          message: msg({
            ar: 'سيتم تجاوز الحد الأقصى لحساب المكسب العادي',
            en: 'This would exceed the regular profit account maximum',
          }),
          limit: REGULAR_PROFIT_LIMIT,
          available: Math.max(
            0,
            Number((REGULAR_PROFIT_LIMIT - Number(account.balance)).toFixed(2)),
          ),
        });
      }
      const depositCommission =
        account.type === AccountType.PROFIT
          ? regularProfitDepositCommission(dto.amount)
          : 0;
      account.balance = Number((nextBalance + depositCommission).toFixed(2));
      account.todayTopUp = Number(
        (Number(account.todayTopUp) + dto.amount).toFixed(2),
      );
      await repo.save(account);
      const ledger = manager.getRepository(LedgerEntry);
      const topUpEntry = await ledger.save({
        category: LedgerCategory.TOP_UP,
        amount: dto.amount,
        entityType: 'account',
        entityId: account.id,
        reference: dto.reference ?? null,
        description: `شحن مباشر للحساب ${account.name}`,
        performedBy: username,
        metadata:
          depositCommission > 0
            ? {
                profitDepositCommission: depositCommission,
                profitDepositCreditedToBalance: true,
              }
            : null,
      });
      if (depositCommission > 0) {
        await ledger.save({
          category: LedgerCategory.COMMISSION,
          amount: depositCommission,
          entityType: 'account',
          entityId: account.id,
          reference: dto.reference ?? null,
          description: `عمولة شحن حساب المكسب ${account.name}: ٥ جنيه لكل ألف`,
          performedBy: username,
          metadata: {
            profitSourceEntryId: topUpEntry.id,
            profitCommissionKind: 'deposit',
            profitDepositCreditedToBalance: true,
          },
        });
      }
      return account;
    });
  }

  async profitQrCashOut(id: string, dto: ProfitQrCashOutDto, username: string) {
    return this.dataSource.transaction(async (manager) => {
      const treasury = await manager.getRepository(Treasury).findOne({
        where: { id: 'main' },
        lock: { mode: 'pessimistic_write' },
      });
      if (!treasury) {
        throw new NotFoundException(
          msg({ ar: 'الخزنة غير مهيأة', en: 'Treasury is not initialized' }),
        );
      }
      const accountRepo = manager.getRepository(FinancialAccount);
      const account = await accountRepo.findOne({
        where: { id, active: true },
        lock: { mode: 'pessimistic_write' },
      });
      if (!account) {
        throw new NotFoundException(
          msg({
            ar: 'الحساب غير موجود أو موقوف',
            en: 'Account not found or inactive',
          }),
        );
      }
      if (account.type !== AccountType.PROFIT_QR) {
        throw new BadRequestException(
          msg({
            ar: 'عملية سحب الكاش دي متاحة لحسابات مكسب QR فقط',
            en: 'This cash-out operation is only available for QR profit accounts',
          }),
        );
      }

      const cashAmount = Number(dto.cashAmount);
      const customerCommission = profitQrCustomerCommission(cashAmount);
      const providerFee = profitQrIncomingFee(cashAmount);
      const customerTransferAmount = cashAmount;
      const treasuryDebit = Number(
        (cashAmount - customerCommission).toFixed(2),
      );
      if (dto.commissionMethod !== 'cash' && treasuryDebit < 0) {
        throw new BadRequestException(
          'المبلغ أقل من العمولة؛ حصّل العمولة نقدًا من العميل',
        );
      }
      const customerCashPaid =
        dto.commissionMethod === 'cash' ? cashAmount : treasuryDebit;
      const creditedAmount = Number(
        (customerTransferAmount - providerFee).toFixed(2),
      );
      const netCommission = Number(
        (customerCommission - providerFee).toFixed(2),
      );
      if (Number(treasury.balance) < treasuryDebit) {
        throw new BadRequestException(
          msg({
            ar: 'رصيد الخزنة لا يكفي لتسليم الكاش للعميل',
            en: 'Insufficient treasury cash for the customer payout',
          }),
        );
      }

      treasury.balance = Number(
        (Number(treasury.balance) - treasuryDebit).toFixed(2),
      );
      account.balance = Number(
        (Number(account.balance) + creditedAmount).toFixed(2),
      );
      account.commissionBalance = Number(
        (Number(account.commissionBalance) - providerFee).toFixed(2),
      );
      await manager.getRepository(Treasury).save(treasury);
      await accountRepo.save(account);

      const ledger = manager.getRepository(LedgerEntry);
      const operation = await ledger.save({
        category: LedgerCategory.INTERNAL_TRANSFER,
        amount: cashAmount,
        entityType: 'internal_transfer',
        entityId: null,
        sourceType: 'treasury',
        sourceId: 'main',
        targetType: 'account',
        targetId: account.id,
        reference: dto.reference ?? null,
        description: `سحب كاش لعميل من حساب مكسب QR ${account.name}`,
        performedBy: username,
        metadata: {
          profitQrCashOut: true,
          customerCommissionToTreasury: true,
          commissionMethod: dto.commissionMethod ?? 'deduct',
          treasuryDebit,
          customerCashPaid,
          accountCommissionChange: -providerFee,
          customerTransferAmount,
          customerCommission,
          providerIncomingFee: providerFee,
          creditedAmount,
          netCommission,
        },
      });
      await ledger.save({
        category: LedgerCategory.COMMISSION,
        amount: customerCommission,
        entityType: 'treasury',
        entityId: 'main',
        reference: dto.reference ?? null,
        description: `عمولة عميل سحب كاش من مكسب QR ${account.name}: ${customerCommission.toFixed(2)} جنيه`,
        performedBy: username,
        metadata: { profitQrCashOutEntryId: operation.id },
      });
      await ledger.save({
        category: LedgerCategory.COMMISSION,
        amount: -providerFee,
        entityType: 'account',
        entityId: account.id,
        reference: dto.reference ?? null,
        description: `خصم استقبال مكسب QR ${account.name}: ٢ جنيه لكل ألف`,
        performedBy: username,
        metadata: { profitQrCashOutEntryId: operation.id },
      });

      return {
        account,
        treasuryBalance: treasury.balance,
        treasuryDebit,
        customerCashPaid,
        cashAmount,
        customerTransferAmount,
        customerCommission,
        providerFee,
        creditedAmount,
        netCommission,
        operationEntryId: operation.id,
      };
    });
  }

  async recordFawryDeposit(
    id: string,
    dto: RecordFawryDepositDto,
    username: string,
  ) {
    const cashCounts: FawryCashCounts = {
      count200: dto.cashCounts.count200,
      count100: dto.cashCounts.count100,
      count50: dto.cashCounts.count50,
      count20: dto.cashCounts.count20,
      count10: dto.cashCounts.count10,
      count5: dto.cashCounts.count5,
    };
    const amount = fawryCashTotal(cashCounts);
    if (amount <= 0) {
      throw new BadRequestException(
        msg({
          ar: 'أدخل عدد ورقة واحدة على الأقل',
          en: 'Enter at least one banknote',
        }),
      );
    }

    return this.dataSource.transaction(async (manager) => {
      const depositor =
        !dto.depositorName?.trim() && dto.depositorUserId
          ? await manager.getRepository(User).findOne({
              where: { id: dto.depositorUserId, active: true },
              lock: { mode: 'pessimistic_read' },
            })
          : null;
      const depositorName =
        dto.depositorName?.trim() ||
        depositor?.displayName ||
        depositor?.username;
      if (!depositorName) {
        throw new NotFoundException(
          msg({
            ar: 'اكتب اسم الشخص الذي قام بالإيداع',
            en: 'The depositor was not found or is inactive',
          }),
        );
      }

      const accounts = manager.getRepository(FinancialAccount);
      const account = await accounts.findOne({
        where: { id, active: true },
        lock: { mode: 'pessimistic_write' },
      });
      if (!account) {
        throw new NotFoundException(
          msg({
            ar: 'الحساب غير موجود أو موقوف',
            en: 'Account not found or inactive',
          }),
        );
      }
      if (account.type !== AccountType.FAWRY) {
        throw new BadRequestException(
          msg({
            ar: 'تسجيل الإيداع النقدي متاح لحسابات فوري فقط',
            en: 'Cash deposit recording is only available for Fawry accounts',
          }),
        );
      }
      if (Number(account.balance) + amount > FAWRY_MAX_BALANCE) {
        throw new BadRequestException({
          message: msg({
            ar: 'سيتم تجاوز الحد الأقصى لحساب فوري',
            en: 'This would exceed the Fawry account maximum',
          }),
          limit: FAWRY_MAX_BALANCE,
          available: Math.max(0, FAWRY_MAX_BALANCE - Number(account.balance)),
        });
      }

      account.balance = Number((Number(account.balance) + amount).toFixed(2));
      account.todayTopUp = Number(
        (Number(account.todayTopUp) + amount).toFixed(2),
      );
      await accounts.save(account);

      const reference = dto.reference?.trim() || null;
      const depositRepo = manager.getRepository(FawryDeposit);
      const deposit = await depositRepo.save(
        depositRepo.create({
          accountId: account.id,
          depositorUserId: depositor?.id ?? null,
          depositorName,
          cashCounts,
          amount,
          reference,
          performedBy: username,
          ledgerEntryId: null,
        }),
      );
      const breakdown = fawryCashDescription(cashCounts);
      const entry = await manager.getRepository(LedgerEntry).save({
        category: LedgerCategory.TOP_UP,
        amount,
        entityType: 'account',
        entityId: account.id,
        reference,
        description: `إيداع فوري بواسطة ${depositorName} لحساب ${account.name} (${breakdown})`,
        performedBy: username,
        metadata: {
          fawryDeposit: true,
          fawryDepositId: deposit.id,
          depositorUserId: depositor?.id ?? null,
          depositorName,
          cashCounts,
        },
      });
      deposit.ledgerEntryId = entry.id;
      await depositRepo.save(deposit);

      return { deposit, account };
    });
  }

  async todayFawryOperations(accountId?: string, now = new Date()) {
    const date = cairoParts(now).date;
    const accounts = await this.accounts.find({
      where: { type: AccountType.FAWRY },
      select: { id: true, name: true },
      order: { name: 'ASC' },
    });
    const listed = accounts.map((account) => ({
      id: account.id,
      name: account.name,
    }));
    if (accountId && !accounts.some((account) => account.id === accountId)) {
      throw new NotFoundException(
        msg({
          ar: 'حساب فوري غير موجود',
          en: 'Fawry account not found',
        }),
      );
    }
    const ids = accountId ? [accountId] : accounts.map((account) => account.id);
    if (!ids.length) {
      return {
        date,
        accountId: accountId ?? null,
        accounts: listed,
        count: 0,
        operations: [],
      };
    }
    const nameById = new Map(
      accounts.map((account) => [account.id, account.name]),
    );
    const entries = await this.ledger
      .createQueryBuilder('entry')
      .where(`(entry.created_at AT TIME ZONE 'Africa/Cairo')::date = :today`, {
        today: date,
      })
      .andWhere(
        new Brackets((query) => {
          query
            .where(
              `entry.entity_type = 'account' AND entry.entity_id IN (:...entityIds)`,
              { entityIds: ids },
            )
            .orWhere(
              `entry.source_type = 'account' AND entry.source_id IN (:...sourceIds)`,
              { sourceIds: ids },
            )
            .orWhere(
              `entry.target_type = 'account' AND entry.target_id IN (:...targetIds)`,
              { targetIds: ids },
            );
        }),
      )
      .orderBy('entry.created_at', 'DESC')
      .getMany();

    const reversedIds = new Set<string>();
    const entryIds = entries.map((entry) => entry.id);
    if (entryIds.length) {
      const reversals = await this.ledger.find({
        where: { reversesEntryId: In(entryIds) },
        select: { reversesEntryId: true },
      });
      for (const reversal of reversals) {
        if (reversal.reversesEntryId) reversedIds.add(reversal.reversesEntryId);
      }
    }

    const operations = entries.map((entry) => {
      const matchedAccountId = matchingFawryAccountId(entry, ids);
      return {
        id: entry.id,
        createdAt: entry.createdAt,
        description: entry.description,
        amount: Number(entry.amount),
        reference: entry.reference,
        accountId: matchedAccountId,
        accountName: matchedAccountId
          ? (nameById.get(matchedAccountId) ?? null)
          : null,
        category: entry.category,
        status: fawryOperationStatus(entry, reversedIds),
        performedBy: entry.performedBy,
      };
    });
    return {
      date,
      accountId: accountId ?? null,
      accounts: listed,
      count: operations.length,
      operations,
    };
  }

  async todayDrops(now = new Date()) {
    const date = cairoParts(now).date;
    const drops = await this.drops.find({
      where: { businessDate: date },
      order: { createdAt: 'ASC' },
    });
    return {
      date,
      drops: drops.map((drop) => ({
        accountId: drop.accountId,
        amount: Number(drop.amount),
      })),
    };
  }

  async recordDailyDrop(
    id: string,
    amount: number,
    username: string,
    now = new Date(),
  ) {
    const date = cairoParts(now).date;
    const normalized = Number(Number(amount).toFixed(2));
    return this.dataSource.transaction(async (manager) => {
      await manager.query(`SELECT pg_advisory_xact_lock(hashtext($1))`, [
        `hesba:fawry-drop:${id}:${date}`,
      ]);
      const accounts = manager.getRepository(FinancialAccount);
      const account = await accounts.findOne({
        where: { id, active: true },
        lock: { mode: 'pessimistic_write' },
      });
      if (!account) {
        throw new NotFoundException(
          msg({
            ar: 'الحساب غير موجود أو موقوف',
            en: 'Account not found or inactive',
          }),
        );
      }
      if (account.type !== AccountType.FAWRY) {
        throw new BadRequestException(
          msg({
            ar: 'نزلة العمولة اليومية تخص حسابات فوري فقط',
            en: 'The daily drop is only for Fawry accounts',
          }),
        );
      }
      const drops = manager.getRepository(FawryDailyDrop);
      const existing = await drops.findOne({
        where: { accountId: id, businessDate: date },
      });
      if (existing) {
        throw new BadRequestException(
          msg({
            ar: 'نزلة النهاردة متسجلة بالفعل على الحساب ده',
            en: 'Today’s drop is already recorded for this account',
          }),
        );
      }

      let ledgerEntryId: string | null = null;
      if (normalized > 0) {
        if (Number(account.balance) + normalized > FAWRY_MAX_BALANCE) {
          throw new BadRequestException({
            message: msg({
              ar: 'سيتم تجاوز الحد الأقصى لحساب فوري',
              en: 'This would exceed the Fawry account maximum',
            }),
            limit: FAWRY_MAX_BALANCE,
            available: Math.max(0, FAWRY_MAX_BALANCE - Number(account.balance)),
          });
        }
        account.balance = Number(
          (Number(account.balance) + normalized).toFixed(2),
        );
        account.commissionBalance = Number(
          (Number(account.commissionBalance) + normalized).toFixed(2),
        );
        await accounts.save(account);
        const entry = await manager.getRepository(LedgerEntry).save({
          category: LedgerCategory.COMMISSION,
          amount: normalized,
          entityType: 'account',
          entityId: account.id,
          reference: `FAWRY-DROP-${date}`,
          description: `نزلة عمولة فوري اليومية لحساب ${account.name}`,
          performedBy: username,
          metadata: {
            fawryDailyDrop: true,
            businessDate: date,
            appliedToBalance: true,
          },
        });
        ledgerEntryId = entry.id;
      }

      const drop = await drops.save(
        drops.create({
          accountId: account.id,
          businessDate: date,
          amount: normalized,
          performedBy: username,
          ledgerEntryId,
        }),
      );
      return { date, account, amount: normalized, id: drop.id };
    });
  }

  async setActive(id: string, active: boolean) {
    const account = await this.accounts.findOne({ where: { id } });
    if (!account)
      throw new NotFoundException(
        msg({ ar: 'الحساب غير موجود', en: 'Account not found' }),
      );
    account.active = active;
    return this.accounts.save(account);
  }

  async remove(id: string, username: string) {
    const account = await this.accounts.findOne({ where: { id } });
    if (!account)
      throw new NotFoundException(
        msg({ ar: 'الحساب غير موجود', en: 'Account not found' }),
      );

    const history = await this.ledger.count({
      where: { entityType: 'account', entityId: id },
    });

    if (
      account.balance !== 0 ||
      account.commissionBalance !== 0 ||
      history > 0
    ) {
      throw new BadRequestException(
        msg({
          ar: 'لا يمكن الحذف النهائي إلا إذا كان الرصيد والعمولة صفرًا ولا توجد أي حركات مرتبطة بالحساب',
          en: 'Permanent delete is only allowed when balance and commission are zero and the account has no related movements',
        }),
      );
    }

    const name = account.name;
    await this.accounts.remove(account);

    return {
      deleted: true,
      id,
      name,
      deletedBy: username,
      message: `تم الحذف النهائي للحساب «${name}» بنجاح`,
    };
  }
}

export function matchingFawryAccountId(
  entry: Pick<
    LedgerEntry,
    | 'entityType'
    | 'entityId'
    | 'sourceType'
    | 'sourceId'
    | 'targetType'
    | 'targetId'
  >,
  accountIds: string[],
): string | null {
  const ids = new Set(accountIds);
  if (
    entry.entityType === 'account' &&
    entry.entityId &&
    ids.has(entry.entityId)
  ) {
    return entry.entityId;
  }
  if (
    entry.sourceType === 'account' &&
    entry.sourceId &&
    ids.has(entry.sourceId)
  ) {
    return entry.sourceId;
  }
  if (
    entry.targetType === 'account' &&
    entry.targetId &&
    ids.has(entry.targetId)
  ) {
    return entry.targetId;
  }
  return null;
}

export function fawryOperationStatus(
  entry: Pick<LedgerEntry, 'id' | 'category' | 'reversesEntryId'>,
  reversedIds: Set<string>,
): 'done' | 'reversed' {
  if (
    entry.category === LedgerCategory.REVERSAL ||
    entry.reversesEntryId != null ||
    reversedIds.has(entry.id)
  ) {
    return 'reversed';
  }
  return 'done';
}

export function fawryCashTotal(counts: FawryCashCounts): number {
  return (
    counts.count200 * 200 +
    counts.count100 * 100 +
    counts.count50 * 50 +
    counts.count20 * 20 +
    counts.count10 * 10 +
    counts.count5 * 5
  );
}

function fawryCashDescription(counts: FawryCashCounts): string {
  const parts = [
    [200, counts.count200],
    [100, counts.count100],
    [50, counts.count50],
    [20, counts.count20],
    [10, counts.count10],
    [5, counts.count5],
  ]
    .filter(([, count]) => count > 0)
    .map(([value, count]) => `${value}×${count}`);
  return parts.join('، ');
}

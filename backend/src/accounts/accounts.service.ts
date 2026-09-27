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
import { FawryDailyDrop } from '../database/entities/fawry-daily-drop.entity.js';
import {
  FawryDeposit,
  type FawryCashCounts,
} from '../database/entities/fawry-deposit.entity.js';
import { FinancialAccount } from '../database/entities/financial-account.entity.js';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { User } from '../database/entities/user.entity.js';
import { AccountType, LedgerCategory } from '../database/enums.js';
import { cairoParts } from './cairo-time.js';
import { CreateAccountDto } from './dto/create-account.dto.js';
import { RecordFawryDepositDto } from './dto/record-fawry-deposit.dto.js';
import { TopUpAccountDto } from './dto/top-up-account.dto.js';
import { shouldSeedDemoData } from '../config/demo-data.js';
import { UsersService } from '../users/users.service.js';

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
      if (
        account.type === AccountType.FAWRY &&
        account.balance + dto.amount > FAWRY_MAX_BALANCE
      ) {
        throw new BadRequestException({
          message: msg({
            ar: 'سيتم تجاوز الحد الأقصى لحساب فوري',
            en: 'This would exceed the Fawry account maximum',
          }),
          limit: FAWRY_MAX_BALANCE,
          available: Math.max(0, FAWRY_MAX_BALANCE - account.balance),
        });
      }
      account.balance += dto.amount;
      account.todayTopUp += dto.amount;
      await repo.save(account);
      await manager.getRepository(LedgerEntry).save({
        category: LedgerCategory.TOP_UP,
        amount: dto.amount,
        entityType: 'account',
        entityId: account.id,
        reference: dto.reference ?? null,
        description: `شحن مباشر للحساب ${account.name}`,
        performedBy: username,
      });
      return account;
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
      const depositor = await manager.getRepository(User).findOne({
        where: { id: dto.depositorUserId, active: true },
        lock: { mode: 'pessimistic_read' },
      });
      if (!depositor) {
        throw new NotFoundException(
          msg({
            ar: 'الشخص الذي قام بالإيداع غير موجود أو غير نشط',
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

      const depositorName = depositor.displayName || depositor.username;
      const reference = dto.reference?.trim() || null;
      const depositRepo = manager.getRepository(FawryDeposit);
      const deposit = await depositRepo.save(
        depositRepo.create({
          accountId: account.id,
          depositorUserId: depositor.id,
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
          depositorUserId: depositor.id,
          depositorName,
          cashCounts,
        },
      });
      deposit.ledgerEntryId = entry.id;
      await depositRepo.save(deposit);

      return { deposit, account };
    });
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

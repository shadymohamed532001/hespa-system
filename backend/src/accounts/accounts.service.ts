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
import { FinancialAccount } from '../database/entities/financial-account.entity.js';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { AccountType, LedgerCategory } from '../database/enums.js';
import { cairoParts } from './cairo-time.js';
import { CreateAccountDto } from './dto/create-account.dto.js';
import { TopUpAccountDto } from './dto/top-up-account.dto.js';
import { shouldSeedDemoData } from '../config/demo-data.js';

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
    private readonly dataSource: DataSource,
    private readonly config: ConfigService,
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

  async create(dto: CreateAccountDto, username: string) {
    if (
      dto.type === AccountType.FAWRY &&
      dto.openingBalance > FAWRY_MAX_BALANCE
    ) {
      throw new BadRequestException(
        msg({ ar: 'الرصيد الافتتاحي يتجاوز الحد الأقصى لحساب فوري', en: 'Opening balance exceeds the Fawry account maximum' }),
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
      if (!account) throw new NotFoundException(msg({ ar: 'الحساب غير موجود أو موقوف', en: 'Account not found or inactive' }));
      if (
        account.type === AccountType.FAWRY &&
        account.balance + dto.amount > FAWRY_MAX_BALANCE
      ) {
        throw new BadRequestException({
          message: msg({ ar: 'سيتم تجاوز الحد الأقصى لحساب فوري', en: 'This would exceed the Fawry account maximum' }),
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
          msg({ ar: 'الحساب غير موجود أو موقوف', en: 'Account not found or inactive' }),
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
          metadata: { fawryDailyDrop: true, businessDate: date },
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
    if (!account) throw new NotFoundException(msg({ ar: 'الحساب غير موجود', en: 'Account not found' }));
    account.active = active;
    return this.accounts.save(account);
  }

  async remove(id: string, username: string) {
    const account = await this.accounts.findOne({ where: { id } });
    if (!account) throw new NotFoundException(msg({ ar: 'الحساب غير موجود', en: 'Account not found' }));

    const history = await this.ledger.count({
      where: { entityType: 'account', entityId: id },
    });

    if (
      account.balance !== 0 ||
      account.commissionBalance !== 0 ||
      history > 0
    ) {
      throw new BadRequestException(
        msg({ ar: 'لا يمكن الحذف النهائي إلا إذا كان الرصيد والعمولة صفرًا ولا توجد أي حركات مرتبطة بالحساب', en: 'Permanent delete is only allowed when balance and commission are zero and the account has no related movements' }),
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

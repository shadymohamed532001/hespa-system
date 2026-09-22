import { BadRequestException, Injectable, NotFoundException, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { FinancialAccount } from '../database/entities/financial-account.entity.js';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { AccountType, LedgerCategory } from '../database/enums.js';
import { CreateAccountDto } from './dto/create-account.dto.js';
import { TopUpAccountDto } from './dto/top-up-account.dto.js';

export const FAWRY_MAX_BALANCE = 5_000_000;

@Injectable()
export class AccountsService implements OnModuleInit {
  constructor(
    @InjectRepository(FinancialAccount) private readonly accounts: Repository<FinancialAccount>,
    @InjectRepository(LedgerEntry) private readonly ledger: Repository<LedgerEntry>,
    private readonly dataSource: DataSource,
  ) {}

  async onModuleInit() {
    if (await this.accounts.count()) return;
    await this.accounts.save([
      this.accounts.create({ name: 'حساب فوري 01', type: AccountType.FAWRY, openingBalance: 82400, balance: 82400 }),
      this.accounts.create({ name: 'حساب شركة 01', type: AccountType.COMPANY, openingBalance: 36500, balance: 36500 }),
    ]);
  }

  findAll(includeInactive = false) {
    return this.accounts.find({
      where: includeInactive ? {} : { active: true },
      order: { createdAt: 'ASC' },
    });
  }

  async create(dto: CreateAccountDto, username: string) {
    if (dto.type === AccountType.FAWRY && dto.openingBalance > FAWRY_MAX_BALANCE) {
      throw new BadRequestException('الرصيد الافتتاحي يتجاوز الحد الأقصى لحساب فوري');
    }
    return this.dataSource.transaction(async (manager) => {
      const repo = manager.getRepository(FinancialAccount);
      const account = await repo.save(repo.create({
        name: dto.name,
        type: dto.type,
        openingBalance: dto.openingBalance,
        balance: dto.openingBalance,
      }));
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
      const account = await repo.findOne({ where: { id, active: true }, lock: { mode: 'pessimistic_write' } });
      if (!account) throw new NotFoundException('الحساب غير موجود أو موقوف');
      if (account.type === AccountType.FAWRY && account.balance + dto.amount > FAWRY_MAX_BALANCE) {
        throw new BadRequestException({
          message: 'سيتم تجاوز الحد الأقصى لحساب فوري',
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

  async setActive(id: string, active: boolean) {
    const account = await this.accounts.findOne({ where: { id } });
    if (!account) throw new NotFoundException('الحساب غير موجود');
    account.active = active;
    return this.accounts.save(account);
  }

  async remove(id: string, username: string) {
    const account = await this.accounts.findOne({ where: { id } });
    if (!account) throw new NotFoundException('الحساب غير موجود');

    const history = await this.ledger.count({
      where: { entityType: 'account', entityId: id },
    });

    if (account.balance !== 0 || account.commissionBalance !== 0 || history > 0) {
      throw new BadRequestException(
        'لا يمكن الحذف النهائي إلا إذا كان الرصيد والعمولة صفرًا ولا توجد أي حركات مرتبطة بالحساب',
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


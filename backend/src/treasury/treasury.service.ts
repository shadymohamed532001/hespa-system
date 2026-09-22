import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, EntityManager, Repository } from 'typeorm';
import { Collection } from '../database/entities/collection.entity.js';
import { FinancialAccount } from '../database/entities/financial-account.entity.js';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { Machine } from '../database/entities/machine.entity.js';
import { Treasury } from '../database/entities/treasury.entity.js';
import { Wallet } from '../database/entities/wallet.entity.js';
import { CollectionStatus, LedgerCategory } from '../database/enums.js';
import { InternalTransferDto } from './dto/internal-transfer.dto.js';

type TransferAsset = {
  key: string;
  name: string;
  balance: number;
  setBalance: (value: number) => Promise<void>;
};

@Injectable()
export class TreasuryService {
  constructor(
    @InjectRepository(Treasury) private readonly treasury: Repository<Treasury>,
    @InjectRepository(Collection)
    private readonly collections: Repository<Collection>,
    private readonly dataSource: DataSource,
  ) {}

  async summary() {
    const treasury = await this.treasury.findOne({ where: { id: 'main' } });
    if (!treasury) throw new NotFoundException('الخزنة غير مهيأة');
    const result = await this.collections
      .createQueryBuilder('collection')
      .select('COALESCE(SUM(collection.amount), 0)', 'total')
      .where('collection.status = :status', {
        status: CollectionStatus.PENDING,
      })
      .getRawOne<{ total: string }>();
    const pending = Number(result?.total ?? 0);
    return {
      actualBalance: treasury.balance,
      pendingAmount: pending,
      availableBalance: treasury.balance - pending,
    };
  }

  private async asset(
    manager: EntityManager,
    type: string,
    id?: string,
  ): Promise<TransferAsset> {
    if (type === 'treasury') {
      const item = await manager
        .getRepository(Treasury)
        .findOne({
          where: { id: 'main' },
          lock: { mode: 'pessimistic_write' },
        });
      if (!item) throw new NotFoundException('الخزنة غير موجودة');
      return {
        key: 'treasury:main',
        name: 'الخزنة المركزية',
        balance: item.balance,
        setBalance: async (value) => {
          item.balance = value;
          await manager.save(item);
        },
      };
    }
    if (!id) throw new BadRequestException('معرّف الأصل مطلوب');
    if (type === 'account') {
      const item = await manager
        .getRepository(FinancialAccount)
        .findOne({
          where: { id, active: true },
          lock: { mode: 'pessimistic_write' },
        });
      if (!item) throw new NotFoundException('الحساب غير موجود أو موقوف');
      return {
        key: `account:${id}`,
        name: item.name,
        balance: item.balance,
        setBalance: async (value) => {
          item.balance = value;
          await manager.save(item);
        },
      };
    }
    if (type === 'wallet') {
      const item = await manager
        .getRepository(Wallet)
        .findOne({
          where: { id, active: true },
          lock: { mode: 'pessimistic_write' },
        });
      if (!item) throw new NotFoundException('المحفظة غير موجودة أو موقوفة');
      return {
        key: `wallet:${id}`,
        name: item.name,
        balance: item.balance,
        setBalance: async (value) => {
          item.balance = value;
          await manager.save(item);
        },
      };
    }
    if (type === 'machine') {
      const item = await manager
        .getRepository(Machine)
        .findOne({
          where: { id, active: true },
          lock: { mode: 'pessimistic_write' },
        });
      if (!item) throw new NotFoundException('الماكينة غير موجودة أو موقوفة');
      const balance = item.loadedBalance - item.usedBalance;
      return {
        key: `machine:${id}`,
        name: item.name,
        balance,
        setBalance: async (value) => {
          item.loadedBalance = item.usedBalance + value;
          await manager.save(item);
        },
      };
    }
    throw new BadRequestException('نوع الأصل غير مدعوم');
  }

  async transfer(dto: InternalTransferDto, username: string) {
    return this.dataSource.transaction('SERIALIZABLE', async (manager) => {
      const source = await this.asset(manager, dto.fromType, dto.fromId);
      const target = await this.asset(manager, dto.toType, dto.toId);
      if (source.key === target.key)
        throw new BadRequestException('المصدر والوجهة يجب أن يكونا مختلفين');
      if (source.balance < dto.amount)
        throw new BadRequestException('رصيد المصدر غير كافٍ');
      await source.setBalance(source.balance - dto.amount);
      await target.setBalance(target.balance + dto.amount);
      await manager.getRepository(LedgerEntry).save({
        category: LedgerCategory.INTERNAL_TRANSFER,
        amount: dto.amount,
        entityType: 'internal_transfer',
        entityId: null,
        sourceType: dto.fromType,
        sourceId: dto.fromType === 'treasury' ? 'main' : (dto.fromId ?? null),
        targetType: dto.toType,
        targetId: dto.toType === 'treasury' ? 'main' : (dto.toId ?? null),
        reference: dto.reference ?? null,
        description: `تحويل داخلي من ${source.name} إلى ${target.name} — ليس مصروفًا`,
        performedBy: username,
      });
      return { from: source.name, to: target.name, amount: dto.amount };
    });
  }

  async rollover(username: string) {
    return this.dataSource.transaction(async (manager) => {
      const accounts = await manager.getRepository(FinancialAccount).find();
      const wallets = await manager.getRepository(Wallet).find();
      for (const account of accounts) {
        account.openingBalance = account.balance;
        account.todayTopUp = 0;
      }
      for (const wallet of wallets) {
        wallet.openingBalance = wallet.balance;
        wallet.todayTopUp = 0;
        wallet.dailyTopUp = 0;
        wallet.counterDay = null;
      }
      await manager.getRepository(FinancialAccount).save(accounts);
      await manager.getRepository(Wallet).save(wallets);
      await manager.getRepository(LedgerEntry).save({
        category: LedgerCategory.DAILY_ROLLOVER,
        amount: 0,
        entityType: 'system',
        entityId: null,
        reference: null,
        description:
          'ترحيل أرصدة نهاية اليوم إلى اليوم التالي وتصفير العدادات اليومية',
        performedBy: username,
      });
      return {
        rolledOver: true,
        accounts: accounts.length,
        wallets: wallets.length,
      };
    });
  }
}

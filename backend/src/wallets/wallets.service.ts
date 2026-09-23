import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  OnModuleInit,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { ConfigService } from '@nestjs/config';
import { DataSource, Repository } from 'typeorm';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { Wallet } from '../database/entities/wallet.entity.js';
import { LedgerCategory } from '../database/enums.js';
import { CreateWalletDto } from './dto/create-wallet.dto.js';
import { TopUpWalletDto } from './dto/top-up-wallet.dto.js';
import { UseWalletDto } from './dto/use-wallet.dto.js';
import { shouldSeedDemoData } from '../config/demo-data.js';

export const WALLET_DAILY_TOP_UP_LIMIT = 60_000;
export const WALLET_MONTHLY_TOP_UP_LIMIT = 200_000;

function cairoPeriod() {
  const day = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Africa/Cairo',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
  return { day, month: day.slice(0, 7) };
}

@Injectable()
export class WalletsService implements OnModuleInit {
  constructor(
    @InjectRepository(Wallet) private readonly wallets: Repository<Wallet>,
    private readonly dataSource: DataSource,
    private readonly config: ConfigService,
  ) {}

  async onModuleInit() {
    if (!shouldSeedDemoData(this.config)) return;
    if (await this.wallets.count()) return;
    await this.wallets.save([
      this.wallets.create({
        name: 'محفظة 01',
        ownerName: 'مالك المحفظة التجريبية',
        type: 'vodafone_cash',
        openingBalance: 11250,
        balance: 11250,
      }),
      this.wallets.create({
        name: 'InstaPay 01',
        ownerName: 'مالك حساب InstaPay التجريبي',
        type: 'instapay',
        openingBalance: 16550,
        balance: 16550,
      }),
    ]);
  }

  findAll(includeInactive = false) {
    return this.wallets.find({
      where: includeInactive ? {} : { active: true },
      order: { createdAt: 'ASC' },
    });
  }

  async create(dto: CreateWalletDto, username: string) {
    const name = dto.name.trim();
    if (!name) throw new BadRequestException('اسم أو رقم المحفظة مطلوب');
    const ownerName = dto.ownerName?.trim() ?? '';
    if (await this.wallets.exists({ where: { name } })) {
      throw new ConflictException('توجد محفظة بنفس الاسم أو الرقم بالفعل');
    }
    return this.dataSource.transaction(async (manager) => {
      const wallet = await manager.getRepository(Wallet).save(
        manager.getRepository(Wallet).create({
          name,
          ownerName,
          type: dto.type,
          openingBalance: dto.openingBalance,
          balance: dto.openingBalance,
        }),
      );
      if (dto.openingBalance > 0) {
        await manager.getRepository(LedgerEntry).save({
          category: LedgerCategory.OPENING_BALANCE,
          amount: dto.openingBalance,
          entityType: 'wallet',
          entityId: wallet.id,
          reference: null,
          description: `رصيد افتتاحي للمحفظة ${wallet.name}${wallet.ownerName ? ` باسم ${wallet.ownerName}` : ''}`,
          performedBy: username,
        });
      }
      return wallet;
    });
  }

  async topUp(id: string, dto: TopUpWalletDto, username: string) {
    return this.dataSource.transaction(async (manager) => {
      const repo = manager.getRepository(Wallet);
      const wallet = await repo.findOne({
        where: { id, active: true },
        lock: { mode: 'pessimistic_write' },
      });
      if (!wallet) throw new NotFoundException('المحفظة غير موجودة أو موقوفة');
      const period = cairoPeriod();
      if (wallet.counterDay !== period.day) {
        wallet.counterDay = period.day;
        wallet.dailyTopUp = 0;
        wallet.todayTopUp = 0;
        wallet.openingBalance = wallet.balance;
      }
      if (wallet.counterMonth !== period.month) {
        wallet.counterMonth = period.month;
        wallet.monthlyTopUp = 0;
      }
      if (wallet.dailyTopUp + dto.amount > WALLET_DAILY_TOP_UP_LIMIT) {
        throw new BadRequestException({
          message: 'سيتم تجاوز حد شحن المحفظة اليومي',
          limit: WALLET_DAILY_TOP_UP_LIMIT,
          available: Math.max(0, WALLET_DAILY_TOP_UP_LIMIT - wallet.dailyTopUp),
        });
      }
      if (wallet.monthlyTopUp + dto.amount > WALLET_MONTHLY_TOP_UP_LIMIT) {
        throw new BadRequestException({
          message: 'سيتم تجاوز حد شحن المحفظة الشهري',
          limit: WALLET_MONTHLY_TOP_UP_LIMIT,
          available: Math.max(
            0,
            WALLET_MONTHLY_TOP_UP_LIMIT - wallet.monthlyTopUp,
          ),
        });
      }
      wallet.balance += dto.amount;
      wallet.todayTopUp += dto.amount;
      wallet.dailyTopUp += dto.amount;
      wallet.monthlyTopUp += dto.amount;
      await repo.save(wallet);
      await manager.getRepository(LedgerEntry).save({
        category: LedgerCategory.TOP_UP,
        amount: dto.amount,
        entityType: 'wallet',
        entityId: wallet.id,
        reference: dto.reference ?? null,
        description: `شحن ${wallet.name}${wallet.ownerName ? ` باسم ${wallet.ownerName}` : ''}`,
        performedBy: username,
      });
      return wallet;
    });
  }

  async use(id: string, dto: UseWalletDto, username: string) {
    return this.dataSource.transaction(async (manager) => {
      const repo = manager.getRepository(Wallet);
      const wallet = await repo.findOne({
        where: { id, active: true },
        lock: { mode: 'pessimistic_write' },
      });
      if (!wallet) throw new NotFoundException('المحفظة غير موجودة أو موقوفة');

      const amount = Number(dto.amount);
      const commission = Number(dto.commission);
      if (Number(wallet.balance) < amount) {
        throw new BadRequestException('رصيد المحفظة غير كافٍ');
      }

      wallet.balance = Number(wallet.balance) - amount;
      wallet.commissionBalance = Number(wallet.commissionBalance) + commission;
      await repo.save(wallet);

      const usageEntry = await manager.getRepository(LedgerEntry).save({
        category: LedgerCategory.WALLET_USAGE,
        amount,
        entityType: 'wallet',
        entityId: wallet.id,
        reference: dto.reference ?? null,
        description: `استخدام ${wallet.name}${wallet.ownerName ? ` باسم ${wallet.ownerName}` : ''}${dto.purpose ? ` — ${dto.purpose}` : ''} وعمولته ${commission}`,
        performedBy: username,
        metadata: {
          commission,
          walletName: wallet.name,
          ownerName: wallet.ownerName,
          walletType: wallet.type,
          purpose: dto.purpose ?? null,
          balanceAfter: wallet.balance,
          commissionBalance: wallet.commissionBalance,
        },
      });

      if (commission > 0) {
        await manager.getRepository(LedgerEntry).save({
          category: LedgerCategory.COMMISSION,
          amount: commission,
          entityType: 'wallet',
          entityId: wallet.id,
          reference: dto.reference ?? null,
          description: `عمولة استخدام ${wallet.name}`,
          performedBy: username,
          metadata: { walletUsageEntryId: usageEntry.id },
        });
      }

      return wallet;
    });
  }

  async setActive(id: string, active: boolean) {
    const wallet = await this.wallets.findOne({ where: { id } });
    if (!wallet) throw new NotFoundException('المحفظة غير موجودة');
    wallet.active = active;
    return this.wallets.save(wallet);
  }

  async remove(id: string, username: string) {
    const wallet = await this.wallets.findOne({ where: { id } });
    if (!wallet) throw new NotFoundException('المحفظة غير موجودة');

    const history = await this.dataSource
      .getRepository(LedgerEntry)
      .createQueryBuilder('entry')
      .where('(entry.entity_type = :type AND entry.entity_id = :id)', {
        type: 'wallet',
        id,
      })
      .orWhere('(entry.source_type = :type AND entry.source_id = :id)', {
        type: 'wallet',
        id,
      })
      .orWhere('(entry.target_type = :type AND entry.target_id = :id)', {
        type: 'wallet',
        id,
      })
      .getCount();

    if (wallet.balance !== 0 || wallet.commissionBalance !== 0 || history > 0) {
      throw new BadRequestException(
        'لا يمكن حذف المحفظة نهائيًا إلا إذا كان الرصيد والعمولة صفرًا ولا توجد حركات مرتبطة بها',
      );
    }

    const name = wallet.name;
    await this.wallets.remove(wallet);
    return {
      deleted: true,
      id,
      name,
      deletedBy: username,
      message: `تم حذف المحفظة «${name}» نهائيًا`,
    };
  }
}

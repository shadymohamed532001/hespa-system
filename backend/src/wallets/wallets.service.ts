import { BadRequestException, Injectable, NotFoundException, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { Wallet } from '../database/entities/wallet.entity.js';
import { LedgerCategory } from '../database/enums.js';
import { CreateWalletDto } from './dto/create-wallet.dto.js';
import { TopUpWalletDto } from './dto/top-up-wallet.dto.js';

export const WALLET_DAILY_TOP_UP_LIMIT = 60_000;
export const WALLET_MONTHLY_TOP_UP_LIMIT = 200_000;

function cairoPeriod() {
  const day = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Africa/Cairo', year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(new Date());
  return { day, month: day.slice(0, 7) };
}

@Injectable()
export class WalletsService implements OnModuleInit {
  constructor(
    @InjectRepository(Wallet) private readonly wallets: Repository<Wallet>,
    private readonly dataSource: DataSource,
  ) {}

  async onModuleInit() {
    if (await this.wallets.count()) return;
    await this.wallets.save([
      this.wallets.create({ name: 'محفظة 01', type: 'wallet', openingBalance: 11250, balance: 11250 }),
      this.wallets.create({ name: 'InstaPay 01', type: 'instapay', openingBalance: 16550, balance: 16550 }),
    ]);
  }

  findAll() {
    return this.wallets.find({ where: { active: true }, order: { createdAt: 'ASC' } });
  }

  async create(dto: CreateWalletDto) {
    return this.wallets.save(this.wallets.create({
      name: dto.name,
      type: dto.type,
      openingBalance: dto.openingBalance,
      balance: dto.openingBalance,
    }));
  }

  async topUp(id: string, dto: TopUpWalletDto, username: string) {
    return this.dataSource.transaction(async (manager) => {
      const repo = manager.getRepository(Wallet);
      const wallet = await repo.findOne({ where: { id, active: true }, lock: { mode: 'pessimistic_write' } });
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
          available: Math.max(0, WALLET_MONTHLY_TOP_UP_LIMIT - wallet.monthlyTopUp),
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
        description: `شحن ${wallet.name}`,
        performedBy: username,
      });
      return wallet;
    });
  }
}


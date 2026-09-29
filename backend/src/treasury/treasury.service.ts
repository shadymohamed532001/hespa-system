import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { msg } from '../common/i18n/locale-context.js';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, EntityManager, Repository } from 'typeorm';
import { Collection } from '../database/entities/collection.entity.js';
import { AgentCreditPayment } from '../database/entities/agent-credit-payment.entity.js';
import { FinancialAccount } from '../database/entities/financial-account.entity.js';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { Machine } from '../database/entities/machine.entity.js';
import { Treasury } from '../database/entities/treasury.entity.js';
import { Wallet } from '../database/entities/wallet.entity.js';
import { DailyClose } from '../database/entities/daily-close.entity.js';
import {
  AccountType,
  CollectionStatus,
  LedgerCategory,
} from '../database/enums.js';
import {
  REGULAR_PROFIT_LIMIT,
  profitQrOutgoingFee,
  regularProfitWithdrawCommission,
} from '../accounts/profit-commission.js';
import { InternalTransferDto } from './dto/internal-transfer.dto.js';
import { CloseDayDto, ReconcileDto } from './dto/reconcile.dto.js';

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
    @InjectRepository(AgentCreditPayment)
    private readonly agentCreditPayments: Repository<AgentCreditPayment>,
    @InjectRepository(DailyClose)
    private readonly closes: Repository<DailyClose>,
    private readonly dataSource: DataSource,
  ) {}

  async summary() {
    const treasury = await this.treasury.findOne({ where: { id: 'main' } });
    if (!treasury)
      throw new NotFoundException(
        msg({ ar: 'الخزنة غير مهيأة', en: 'Treasury is not initialized' }),
      );
    const result = await this.collections
      .createQueryBuilder('collection')
      .select('COALESCE(SUM(collection.amount), 0)', 'total')
      .where('collection.status = :status', {
        status: CollectionStatus.PENDING,
      })
      .getRawOne<{ total: string }>();
    const pending = Number(result?.total ?? 0);
    const creditResult = await this.collections
      .createQueryBuilder('collection')
      .select('COALESCE(SUM(collection.agentCreditChange), 0)', 'total')
      .where('collection.status <> :reversed', {
        reversed: CollectionStatus.REVERSED,
      })
      .getRawOne<{ total: string }>();
    const paymentResult = await this.agentCreditPayments
      .createQueryBuilder('payment')
      .select('COALESCE(SUM(payment.amount), 0)', 'total')
      .getRawOne<{ total: string }>();
    const agentCreditBalance = Number(
      (
        Number(creditResult?.total ?? 0) - Number(paymentResult?.total ?? 0)
      ).toFixed(2),
    );
    return {
      actualBalance: treasury.balance,
      pendingAmount: pending,
      availableBalance: treasury.balance - pending,
      agentCreditBalance,
    };
  }

  private assetKey(type: string, id?: string) {
    if (type === 'treasury') return 'treasury:main';
    if (!['account', 'wallet', 'machine'].includes(type)) {
      throw new BadRequestException(
        msg({ ar: 'نوع الأصل غير مدعوم', en: 'Unsupported asset type' }),
      );
    }
    if (!id)
      throw new BadRequestException(
        msg({ ar: 'معرّف الأصل مطلوب', en: 'Asset id is required' }),
      );
    return `${type}:${id}`;
  }

  private async asset(
    manager: EntityManager,
    type: string,
    id?: string,
  ): Promise<TransferAsset> {
    if (type === 'treasury') {
      const item = await manager.getRepository(Treasury).findOne({
        where: { id: 'main' },
        lock: { mode: 'pessimistic_write' },
      });
      if (!item)
        throw new NotFoundException(
          msg({ ar: 'الخزنة غير موجودة', en: 'Treasury not found' }),
        );
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
    if (!id)
      throw new BadRequestException(
        msg({ ar: 'معرّف الأصل مطلوب', en: 'Asset id is required' }),
      );
    if (type === 'account') {
      const item = await manager.getRepository(FinancialAccount).findOne({
        where: { id, active: true },
        lock: { mode: 'pessimistic_write' },
      });
      if (!item)
        throw new NotFoundException(
          msg({
            ar: 'الحساب غير موجود أو موقوف',
            en: 'Account not found or inactive',
          }),
        );
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
      const item = await manager.getRepository(Wallet).findOne({
        where: { id, active: true },
        lock: { mode: 'pessimistic_write' },
      });
      if (!item)
        throw new NotFoundException(
          msg({
            ar: 'المحفظة غير موجودة أو موقوفة',
            en: 'Wallet not found or inactive',
          }),
        );
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
      const item = await manager.getRepository(Machine).findOne({
        where: { id, active: true },
        lock: { mode: 'pessimistic_write' },
      });
      if (!item)
        throw new NotFoundException(
          msg({
            ar: 'الماكينة غير موجودة أو موقوفة',
            en: 'Machine not found or inactive',
          }),
        );
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
    throw new BadRequestException(
      msg({ ar: 'نوع الأصل غير مدعوم', en: 'Unsupported asset type' }),
    );
  }

  async transfer(dto: InternalTransferDto, username: string) {
    return this.dataSource.transaction(async (manager) => {
      const sourceKey = this.assetKey(dto.fromType, dto.fromId);
      const targetKey = this.assetKey(dto.toType, dto.toId);
      if (sourceKey === targetKey)
        throw new BadRequestException(
          msg({
            ar: 'المصدر والوجهة يجب أن يكونا مختلفين',
            en: 'Source and destination must be different',
          }),
        );

      // Always acquire row locks in the same order. Without this, two reverse
      // transfers (A -> B and B -> A) can deadlock by each holding one row.
      const requested = [
        { key: sourceKey, type: dto.fromType, id: dto.fromId },
        { key: targetKey, type: dto.toType, id: dto.toId },
      ].sort((left, right) => left.key.localeCompare(right.key));
      const locked = new Map<string, TransferAsset>();
      for (const item of requested) {
        locked.set(item.key, await this.asset(manager, item.type, item.id));
      }
      const source = locked.get(sourceKey)!;
      const target = locked.get(targetKey)!;
      let sourceAccountType: AccountType | null = null;
      if (dto.fromType === 'account' && dto.fromId) {
        const origin = await manager
          .getRepository(FinancialAccount)
          .findOne({ where: { id: dto.fromId } });
        sourceAccountType = origin?.type ?? null;
      }
      const profitQrFee =
        sourceAccountType === AccountType.PROFIT_QR
          ? profitQrOutgoingFee(dto.amount)
          : 0;
      const sourceDebit = Number((dto.amount + profitQrFee).toFixed(2));
      if (source.balance < sourceDebit)
        throw new BadRequestException(
          msg({
            ar: 'رصيد المصدر غير كافٍ',
            en: 'Insufficient source balance',
          }),
        );
      if (dto.toType === 'account' && dto.toId) {
        const destination = await manager
          .getRepository(FinancialAccount)
          .findOne({ where: { id: dto.toId } });
        if (destination?.type === AccountType.PROFIT_QR) {
          throw new BadRequestException(
            msg({
              ar: 'حساب مكسب QR يستقبل تحويلات العملاء من خلال عملية سحب الكاش فقط',
              en: 'QR profit accounts receive customer transfers through cash-out operations only',
            }),
          );
        }
        if (
          destination?.type === AccountType.PROFIT &&
          Number(target.balance) + dto.amount > REGULAR_PROFIT_LIMIT
        ) {
          throw new BadRequestException({
            message: msg({
              ar: 'سيتم تجاوز الحد الأقصى لحساب المكسب العادي',
              en: 'This would exceed the regular profit account maximum',
            }),
            limit: REGULAR_PROFIT_LIMIT,
            available: Math.max(
              0,
              Number(
                (REGULAR_PROFIT_LIMIT - Number(target.balance)).toFixed(2),
              ),
            ),
          });
        }
      }
      await source.setBalance(source.balance - sourceDebit);
      await target.setBalance(target.balance + dto.amount);
      const transfer = await manager.getRepository(LedgerEntry).save({
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
        metadata:
          profitQrFee > 0
            ? { profitQrProviderFee: profitQrFee, sourceDebit }
            : null,
      });
      if (dto.fromType === 'account' && dto.fromId) {
        const origin = await manager.getRepository(FinancialAccount).findOne({
          where: { id: dto.fromId },
        });
        const withdrawCommission =
          origin?.type === AccountType.PROFIT
            ? regularProfitWithdrawCommission(dto.amount)
            : origin?.type === AccountType.PROFIT_QR
              ? -profitQrFee
              : 0;
        if (origin && withdrawCommission > 0) {
          origin.commissionBalance = Number(
            (Number(origin.commissionBalance) - withdrawCommission).toFixed(2),
          );
          await manager.getRepository(FinancialAccount).save(origin);
          await manager.getRepository(LedgerEntry).save({
            category: LedgerCategory.COMMISSION,
            amount: -withdrawCommission,
            entityType: 'account',
            entityId: origin.id,
            reference: dto.reference ?? null,
            description: `خصم عمولة تحويل من حساب المكسب ${origin.name}: ٤ جنيه لكل ألف`,
            performedBy: username,
            metadata: {
              profitSourceEntryId: transfer.id,
              profitCommissionKind: 'withdraw',
            },
          });
        } else if (origin && withdrawCommission < 0) {
          origin.commissionBalance = Number(
            (Number(origin.commissionBalance) + withdrawCommission).toFixed(2),
          );
          await manager.getRepository(FinancialAccount).save(origin);
          await manager.getRepository(LedgerEntry).save({
            category: LedgerCategory.COMMISSION,
            amount: withdrawCommission,
            entityType: 'account',
            entityId: origin.id,
            reference: dto.reference ?? null,
            description: `خصم تحويل من حساب مكسب QR ${origin.name}: ٤ جنيه لكل ألف`,
            performedBy: username,
            metadata: {
              profitSourceEntryId: transfer.id,
              profitCommissionKind: 'qr_outgoing',
            },
          });
        }
      }
      return { from: source.name, to: target.name, amount: dto.amount };
    });
  }

  async reconcile(dto: ReconcileDto, username: string) {
    return this.dataSource.transaction(async (manager) => {
      const item = await this.asset(manager, dto.assetType, dto.assetId);
      const expectedBalance = item.balance;
      const difference = Number(
        (dto.countedBalance - expectedBalance).toFixed(2),
      );
      await item.setBalance(dto.countedBalance);
      const entry = await manager.getRepository(LedgerEntry).save({
        category: LedgerCategory.RECONCILIATION,
        amount: difference,
        entityType: dto.assetType,
        entityId: dto.assetType === 'treasury' ? 'main' : (dto.assetId ?? null),
        reference: null,
        description: `تسوية رصيد ${item.name}: من ${expectedBalance.toFixed(2)} إلى ${dto.countedBalance.toFixed(2)}`,
        performedBy: username,
        metadata: {
          expectedBalance,
          countedBalance: dto.countedBalance,
          note: dto.note ?? null,
        },
      });
      return {
        id: entry.id,
        asset: item.name,
        expectedBalance,
        countedBalance: dto.countedBalance,
        difference,
      };
    });
  }

  dailyCloses() {
    return this.closes.find({ order: { businessDate: 'DESC' }, take: 90 });
  }

  private cairoDay() {
    const parts = new Intl.DateTimeFormat('en-US', {
      timeZone: 'Africa/Cairo',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).formatToParts(new Date());
    const value = Object.fromEntries(
      parts.map((part) => [part.type, part.value]),
    );
    return `${value.year}-${value.month}-${value.day}`;
  }

  async closeDay(dto: CloseDayDto, username: string) {
    return this.dataSource.transaction('SERIALIZABLE', async (manager) => {
      const day = this.cairoDay();
      await manager.query(`SELECT pg_advisory_xact_lock(hashtext($1))`, [
        `hesba:daily-close:${day}`,
      ]);
      const reference = `ROLLOVER-${day}`;
      const existing = await manager.getRepository(DailyClose).findOne({
        where: { businessDate: day },
      });
      if (existing) {
        return { closed: false, alreadyClosed: true, close: existing };
      }

      const treasury = await manager.getRepository(Treasury).findOne({
        where: { id: 'main' },
        lock: { mode: 'pessimistic_write' },
      });
      if (!treasury)
        throw new NotFoundException(
          msg({ ar: 'الخزنة غير مهيأة', en: 'Treasury is not initialized' }),
        );
      const accounts = await manager
        .getRepository(FinancialAccount)
        .createQueryBuilder('account')
        .setLock('pessimistic_write')
        .getMany();
      const wallets = await manager
        .getRepository(Wallet)
        .createQueryBuilder('wallet')
        .setLock('pessimistic_write')
        .getMany();
      const machines = await manager
        .getRepository(Machine)
        .createQueryBuilder('machine')
        .setLock('pessimistic_write')
        .getMany();
      const pendingResult = await manager
        .getRepository(Collection)
        .createQueryBuilder('collection')
        .select('COALESCE(SUM(collection.amount), 0)', 'total')
        .where('collection.status = :status', {
          status: CollectionStatus.PENDING,
        })
        .getRawOne<{ total: string }>();
      const pendingCollections = Number(pendingResult?.total ?? 0);
      const agentCreditResult = await manager
        .getRepository(Collection)
        .createQueryBuilder('collection')
        .select('COALESCE(SUM(collection.agentCreditChange), 0)', 'total')
        .where('collection.status <> :reversed', {
          reversed: CollectionStatus.REVERSED,
        })
        .getRawOne<{ total: string }>();
      const agentCreditBalance = Number(agentCreditResult?.total ?? 0);
      const agentCreditPaymentResult = await manager
        .getRepository(AgentCreditPayment)
        .createQueryBuilder('payment')
        .select('COALESCE(SUM(payment.amount), 0)', 'total')
        .getRawOne<{ total: string }>();
      const outstandingAgentCredit = Number(
        (
          agentCreditBalance - Number(agentCreditPaymentResult?.total ?? 0)
        ).toFixed(2),
      );
      const snapshot = {
        treasury: { id: treasury.id, balance: treasury.balance },
        accounts: accounts.map((item) => ({
          id: item.id,
          name: item.name,
          balance: item.balance,
          commissionBalance: item.commissionBalance,
        })),
        wallets: wallets.map((item) => ({
          id: item.id,
          name: item.name,
          balance: item.balance,
          commissionBalance: item.commissionBalance,
        })),
        machines: machines.map((item) => ({
          id: item.id,
          name: item.name,
          loadedBalance: item.loadedBalance,
          usedBalance: item.usedBalance,
          remainingBalance: item.loadedBalance - item.usedBalance,
          commissionBalance: item.commissionBalance,
        })),
        agentCreditBalance: outstandingAgentCredit,
      };
      const totalAssets = Number(
        (
          treasury.balance +
          accounts.reduce((sum, item) => sum + item.balance, 0) +
          wallets.reduce((sum, item) => sum + item.balance, 0) +
          machines.reduce(
            (sum, item) => sum + item.loadedBalance - item.usedBalance,
            0,
          ) +
          outstandingAgentCredit
        ).toFixed(2),
      );
      const close = await manager.getRepository(DailyClose).save({
        businessDate: day,
        snapshot,
        totalAssets,
        pendingCollections,
        closedBy: username,
        note: dto.note ?? null,
      });
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
        reference,
        description: msg({
          ar: 'ترحيل أرصدة نهاية اليوم إلى اليوم التالي وتصفير العدادات اليومية',
          en: 'Roll end-of-day balances to the next day and reset daily counters',
        }),
        performedBy: username,
        metadata: {
          dailyCloseId: close.id,
          totalAssets,
          pendingCollections,
          agentCreditBalance: outstandingAgentCredit,
        },
      });
      return {
        closed: true,
        close,
        accounts: accounts.length,
        wallets: wallets.length,
        machines: machines.length,
      };
    });
  }

  rollover(username: string) {
    return this.closeDay({}, username);
  }
}

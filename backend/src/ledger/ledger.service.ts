import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { msg } from '../common/i18n/locale-context.js';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, EntityManager, Repository } from 'typeorm';
import { ReversalDto } from '../common/dto/reversal.dto.js';
import { FinancialAccount } from '../database/entities/financial-account.entity.js';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import { Machine } from '../database/entities/machine.entity.js';
import { Treasury } from '../database/entities/treasury.entity.js';
import { Wallet } from '../database/entities/wallet.entity.js';
import { LedgerCategory } from '../database/enums.js';

type Asset = {
  balance: number;
  save: (balance: number) => Promise<void>;
};

@Injectable()
export class LedgerService {
  constructor(
    @InjectRepository(LedgerEntry)
    private readonly ledger: Repository<LedgerEntry>,
    private readonly dataSource: DataSource,
  ) {}

  findAll(limit = 100) {
    return this.ledger.find({
      order: { createdAt: 'DESC' },
      take: Math.min(Math.max(limit, 1), 500),
    });
  }

  private async asset(
    manager: EntityManager,
    type: string | null,
    id: string | null,
  ): Promise<Asset> {
    if (type === 'treasury') {
      const item = await manager.getRepository(Treasury).findOne({
        where: { id: 'main' },
        lock: { mode: 'pessimistic_write' },
      });
      if (!item) throw new NotFoundException(msg({ ar: 'الخزنة غير موجودة', en: 'Treasury not found' }));
      return {
        balance: item.balance,
        save: async (balance) => {
          item.balance = balance;
          await manager.save(item);
        },
      };
    }
    if (!id) throw new BadRequestException(msg({ ar: 'بيانات الأصل غير مكتملة', en: 'Asset data is incomplete' }));
    if (type === 'account') {
      const item = await manager.getRepository(FinancialAccount).findOne({
        where: { id },
        lock: { mode: 'pessimistic_write' },
      });
      if (!item) throw new NotFoundException(msg({ ar: 'الحساب غير موجود', en: 'Account not found' }));
      return {
        balance: item.balance,
        save: async (balance) => {
          item.balance = balance;
          await manager.save(item);
        },
      };
    }
    if (type === 'wallet') {
      const item = await manager.getRepository(Wallet).findOne({
        where: { id },
        lock: { mode: 'pessimistic_write' },
      });
      if (!item) throw new NotFoundException(msg({ ar: 'المحفظة غير موجودة', en: 'Wallet not found' }));
      return {
        balance: item.balance,
        save: async (balance) => {
          item.balance = balance;
          await manager.save(item);
        },
      };
    }
    if (type === 'machine') {
      const item = await manager.getRepository(Machine).findOne({
        where: { id },
        lock: { mode: 'pessimistic_write' },
      });
      if (!item) throw new NotFoundException(msg({ ar: 'الماكينة غير موجودة', en: 'Machine not found' }));
      return {
        balance: item.loadedBalance - item.usedBalance,
        save: async (balance) => {
          item.loadedBalance = item.usedBalance + balance;
          await manager.save(item);
        },
      };
    }
    throw new BadRequestException(msg({ ar: 'نوع الأصل غير مدعوم', en: 'Unsupported asset type' }));
  }

  private async reverseTopUp(manager: EntityManager, entry: LedgerEntry) {
    if (!entry.entityId) throw new BadRequestException(msg({ ar: 'بيانات الشحن ناقصة', en: 'Top-up data is incomplete' }));
    if (entry.entityType === 'account') {
      const account = await manager.getRepository(FinancialAccount).findOne({
        where: { id: entry.entityId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!account) throw new NotFoundException(msg({ ar: 'الحساب غير موجود', en: 'Account not found' }));
      if (account.balance < entry.amount || account.todayTopUp < entry.amount) {
        throw new BadRequestException(
          msg({ ar: 'لا يمكن عكس الشحن بعد استخدام الرصيد أو بعد إقفال يومه', en: 'Cannot reverse top-up after balance was used or its day was closed' }),
        );
      }
      account.balance -= entry.amount;
      account.todayTopUp -= entry.amount;
      await manager.save(account);
      return;
    }
    if (entry.entityType === 'wallet') {
      const wallet = await manager.getRepository(Wallet).findOne({
        where: { id: entry.entityId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!wallet) throw new NotFoundException(msg({ ar: 'المحفظة غير موجودة', en: 'Wallet not found' }));
      if (
        wallet.balance < entry.amount ||
        wallet.todayTopUp < entry.amount ||
        wallet.dailyTopUp < entry.amount ||
        wallet.monthlyTopUp < entry.amount
      ) {
        throw new BadRequestException(
          msg({ ar: 'لا يمكن عكس الشحن بعد استخدام الرصيد أو تغيير عدادات الفترة', en: 'Cannot reverse top-up after balance was used or period counters changed' }),
        );
      }
      wallet.balance -= entry.amount;
      wallet.todayTopUp -= entry.amount;
      wallet.dailyTopUp -= entry.amount;
      wallet.monthlyTopUp -= entry.amount;
      await manager.save(wallet);
      return;
    }
    if (entry.entityType === 'machine') {
      const machine = await manager.getRepository(Machine).findOne({
        where: { id: entry.entityId },
        lock: { mode: 'pessimistic_write' },
      });
      if (!machine) throw new NotFoundException(msg({ ar: 'الماكينة غير موجودة', en: 'Machine not found' }));
      if (machine.loadedBalance - machine.usedBalance < entry.amount) {
        throw new BadRequestException(
          msg({ ar: 'الرصيد المشحون تم استخدامه ولا يمكن عكسه', en: 'Topped-up balance was used and cannot be reversed' }),
        );
      }
      machine.loadedBalance -= entry.amount;
      await manager.save(machine);
      return;
    }
    throw new BadRequestException(msg({ ar: 'نوع الشحن غير قابل للعكس', en: 'This top-up type cannot be reversed' }));
  }

  private async reverseTransfer(manager: EntityManager, entry: LedgerEntry) {
    const sourceKey = `${entry.sourceType}:${entry.sourceId}`;
    const targetKey = `${entry.targetType}:${entry.targetId}`;
    const definitions = [
      { key: sourceKey, type: entry.sourceType, id: entry.sourceId },
      { key: targetKey, type: entry.targetType, id: entry.targetId },
    ].sort((left, right) => left.key.localeCompare(right.key));
    const assets = new Map<string, Asset>();
    for (const definition of definitions) {
      assets.set(
        definition.key,
        await this.asset(manager, definition.type, definition.id),
      );
    }
    const source = assets.get(sourceKey)!;
    const target = assets.get(targetKey)!;
    if (target.balance < entry.amount) {
      throw new BadRequestException(msg({ ar: 'رصيد وجهة التحويل لا يكفي لعكسه', en: 'Destination balance is insufficient to reverse the transfer' }));
    }
    await target.save(target.balance - entry.amount);
    await source.save(source.balance + entry.amount);
  }

  private async reverseMachineUsage(
    manager: EntityManager,
    entry: LedgerEntry,
  ) {
    if (!entry.entityId) throw new BadRequestException(msg({ ar: 'بيانات العملية ناقصة', en: 'Operation data is incomplete' }));
    const machine = await manager.getRepository(Machine).findOne({
      where: { id: entry.entityId },
      lock: { mode: 'pessimistic_write' },
    });
    if (!machine) throw new NotFoundException(msg({ ar: 'الماكينة غير موجودة', en: 'Machine not found' }));
    if (!Object.hasOwn(entry.metadata ?? {}, 'commission')) {
      throw new BadRequestException(
        msg({ ar: 'هذه حركة قديمة بلا تفاصيل عمولة؛ استخدم تسوية رصيد موثقة بدل عكسها آليًا', en: 'This is a legacy entry without commission details; use a documented balance reconciliation instead of automatic reversal' }),
      );
    }
    const commission = Number(entry.metadata?.commission ?? 0);
    if (
      machine.usedBalance < entry.amount ||
      machine.commissionBalance < commission
    ) {
      throw new BadRequestException(msg({ ar: 'أرصدة الماكينة الحالية لا تسمح بالعكس', en: 'Current machine balances do not allow reversal' }));
    }
    machine.usedBalance -= entry.amount;
    machine.commissionBalance -= commission;
    await manager.save(machine);
  }

  private async reverseWalletUsage(manager: EntityManager, entry: LedgerEntry) {
    if (!entry.entityId) throw new BadRequestException(msg({ ar: 'بيانات العملية ناقصة', en: 'Operation data is incomplete' }));
    const wallet = await manager.getRepository(Wallet).findOne({
      where: { id: entry.entityId },
      lock: { mode: 'pessimistic_write' },
    });
    if (!wallet) throw new NotFoundException(msg({ ar: 'المحفظة غير موجودة', en: 'Wallet not found' }));
    if (!Object.hasOwn(entry.metadata ?? {}, 'commission')) {
      throw new BadRequestException(msg({ ar: 'بيانات عمولة العملية غير مكتملة', en: 'Operation commission data is incomplete' }));
    }
    const commission = Number(entry.metadata?.commission ?? 0);
    if (wallet.commissionBalance < commission) {
      throw new BadRequestException(msg({ ar: 'رصيد العمولات الحالي لا يسمح بالعكس', en: 'Current commission balance does not allow reversal' }));
    }
    wallet.balance = Number(wallet.balance) + Number(entry.amount);
    wallet.commissionBalance = Number(wallet.commissionBalance) - commission;
    await manager.save(wallet);
  }

  private async reverseReconciliation(
    manager: EntityManager,
    entry: LedgerEntry,
  ) {
    const expected = Number(entry.metadata?.expectedBalance);
    const counted = Number(entry.metadata?.countedBalance);
    if (!Number.isFinite(expected) || !Number.isFinite(counted)) {
      throw new BadRequestException(msg({ ar: 'بيانات التسوية غير مكتملة', en: 'Reconciliation data is incomplete' }));
    }
    const item = await this.asset(manager, entry.entityType, entry.entityId);
    if (Math.abs(item.balance - counted) > 0.001) {
      throw new BadRequestException(
        msg({ ar: 'تغير الرصيد بعد التسوية؛ اعمل تسوية جديدة بدل عكس السجل القديم', en: 'Balance changed after reconciliation; create a new reconciliation instead of reversing the old record' }),
      );
    }
    await item.save(expected);
  }

  async reverse(id: string, dto: ReversalDto, username: string) {
    return this.dataSource.transaction(async (manager) => {
      const repo = manager.getRepository(LedgerEntry);
      const entry = await repo.findOne({
        where: { id },
        lock: { mode: 'pessimistic_write' },
      });
      if (!entry) throw new NotFoundException(msg({ ar: 'الحركة غير موجودة', en: 'Ledger entry not found' }));
      if (entry.category === LedgerCategory.REVERSAL) {
        throw new BadRequestException(msg({ ar: 'لا يمكن عكس حركة عكسية', en: 'Cannot reverse a reversal entry' }));
      }
      if (await repo.exists({ where: { reversesEntryId: entry.id } })) {
        throw new BadRequestException(msg({ ar: 'تم عكس الحركة بالفعل', en: 'Entry already reversed' }));
      }

      if (entry.category === LedgerCategory.TOP_UP) {
        await this.reverseTopUp(manager, entry);
      } else if (entry.category === LedgerCategory.INTERNAL_TRANSFER) {
        await this.reverseTransfer(manager, entry);
      } else if (entry.category === LedgerCategory.MACHINE_USAGE) {
        await this.reverseMachineUsage(manager, entry);
      } else if (entry.category === LedgerCategory.WALLET_USAGE) {
        await this.reverseWalletUsage(manager, entry);
      } else if (entry.category === LedgerCategory.RECONCILIATION) {
        await this.reverseReconciliation(manager, entry);
      } else {
        throw new BadRequestException(
          msg({ ar: 'هذه الحركة تُعكس من شاشة العملية الأصلية حفاظًا على ترابط القيود', en: 'Reverse this entry from the original operation screen to keep ledger links intact' }),
        );
      }

      const reversal = await repo.save({
        category: LedgerCategory.REVERSAL,
        amount: -entry.amount,
        entityType: entry.entityType,
        entityId: entry.entityId,
        reference: entry.reference,
        description: `عكس: ${entry.description} — السبب: ${dto.reason}`,
        performedBy: username,
        sourceType: entry.targetType,
        sourceId: entry.targetId,
        targetType: entry.sourceType,
        targetId: entry.sourceId,
        reversesEntryId: entry.id,
        metadata: { reason: dto.reason, originalCategory: entry.category },
      });

      if (
        entry.category === LedgerCategory.MACHINE_USAGE ||
        entry.category === LedgerCategory.WALLET_USAGE
      ) {
        const relationKey =
          entry.category === LedgerCategory.MACHINE_USAGE
            ? 'machineUsageEntryId'
            : 'walletUsageEntryId';
        const commission = await repo
          .createQueryBuilder('entry')
          .where('entry.category = :category', {
            category: LedgerCategory.COMMISSION,
          })
          .andWhere(`entry.metadata @> :metadata::jsonb`, {
            metadata: JSON.stringify({ [relationKey]: entry.id }),
          })
          .getOne();
        if (
          commission &&
          !(await repo.exists({ where: { reversesEntryId: commission.id } }))
        ) {
          await repo.save({
            category: LedgerCategory.REVERSAL,
            amount: -commission.amount,
            entityType: commission.entityType,
            entityId: commission.entityId,
            reference: commission.reference,
            description: `عكس: ${commission.description} — السبب: ${dto.reason}`,
            performedBy: username,
            reversesEntryId: commission.id,
            metadata: {
              reason: dto.reason,
              [relationKey]: entry.id,
              originalCategory: commission.category,
            },
          });
        }
      }
      return { reversed: true, originalEntryId: entry.id, reversal };
    });
  }
}

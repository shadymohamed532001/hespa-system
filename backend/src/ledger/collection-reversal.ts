import { agentCreditBalance } from '../collections/collections.service.js';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { EntityManager } from 'typeorm';
import { Collection } from '../database/entities/collection.entity.js';
import { FinancialAccount } from '../database/entities/financial-account.entity.js';
import { PurchaseVisa } from '../database/entities/purchase-visa.entity.js';
import { Treasury } from '../database/entities/treasury.entity.js';
import { Wallet } from '../database/entities/wallet.entity.js';
import { LedgerEntry } from '../database/entities/ledger-entry.entity.js';
import {
  AccountType,
  CollectionStatus,
  LedgerCategory,
} from '../database/enums.js';
import { cairoPeriod } from '../wallets/wallets.service.js';

const money = (n: number) => Number(n.toFixed(2));

/** Cancel the entire receipt, including execution, incoming splits and credit. */
export async function reverseCollection(
  manager: EntityManager,
  id: string,
  reason: string,
  username: string,
) {
  const repo = manager.getRepository(Collection);
  const receipt = await repo.findOne({
    where: { id },
    lock: { mode: 'pessimistic_write' },
  });
  if (!receipt) throw new NotFoundException('العملية غير موجودة');
  if (receipt.status === CollectionStatus.REVERSED)
    throw new BadRequestException('العملية ملغية بالفعل');
  await manager.query('SELECT pg_advisory_xact_lock(hashtext($1))', [
    `hesba:agent-credit:${receipt.agentName.trim().toLowerCase()}`,
  ]);
  const treasury = await manager
    .getRepository(Treasury)
    .findOne({ where: { id: 'main' }, lock: { mode: 'pessimistic_write' } });
  if (!treasury) throw new NotFoundException('الخزنة غير موجودة');
  // Restore the execution first, including the case where the source also received a split.
  if (receipt.status === CollectionStatus.DONE && receipt.accountId) {
    const account = await manager
      .getRepository(FinancialAccount)
      .findOne({
        where: { id: receipt.accountId },
        lock: { mode: 'pessimistic_write' },
      });
    if (!account) throw new NotFoundException('الحساب غير موجود');
    const fee = [AccountType.PROFIT, AccountType.PROFIT_QR].includes(
      account.type,
    )
      ? Math.abs(Number(receipt.commission))
      : 0;
    account.balance = money(
      Number(account.balance) + Number(receipt.amount) + fee,
    );
    account.commissionBalance = money(
      Number(account.commissionBalance) - Number(receipt.commission),
    );
    if (account.commissionBalance < 0 && Number(receipt.commission) > 0)
      throw new BadRequestException('رصيد العمولة لا يكفي لإلغاء العملية');
    await manager.save(account);
  }
  if (receipt.status === CollectionStatus.DONE && receipt.purchaseVisaId) {
    const visa = await manager
      .getRepository(PurchaseVisa)
      .findOne({
        where: { id: receipt.purchaseVisaId },
        lock: { mode: 'pessimistic_write' },
      });
    if (!visa) throw new NotFoundException('الفيزا غير موجودة');
    visa.balance = money(Number(visa.balance) + Number(receipt.amount));
    visa.commissionBalance = money(
      Number(visa.commissionBalance) - Number(receipt.commission),
    );
    treasury.balance = money(
      Number(treasury.balance) - Number(receipt.commission),
    );
    if (visa.commissionBalance < 0)
      throw new BadRequestException('رصيد مكسب الفيزا لا يكفي للإلغاء');
    await manager.save(visa);
  }
  for (const split of receipt.incomingSplits ?? []) {
    if (split.accountId) {
      const account = await manager
        .getRepository(FinancialAccount)
        .findOne({
          where: { id: split.accountId },
          lock: { mode: 'pessimistic_write' },
        });
      if (!account || Number(account.balance) < Number(split.amount))
        throw new BadRequestException('رصيد حساب الاستلام لا يكفي للإلغاء');
      account.balance = money(Number(account.balance) - Number(split.amount));
      // A closed day must not have its counters silently changed.
      const day = new Intl.DateTimeFormat('en-CA', {
        timeZone: 'Africa/Cairo',
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
      }).format(receipt.executedAt ?? receipt.receivedAt);
      if (
        day !== cairoPeriod().day ||
        Number(account.todayTopUp) < Number(split.amount)
      )
        throw new BadRequestException(
          'تم تغيير عدادات يوم العملية؛ لا يمكن إلغاء جزء الاستلام آليًا',
        );
      account.todayTopUp = money(
        Number(account.todayTopUp) - Number(split.amount),
      );
      await manager.save(account);
    } else if (split.walletId) {
      const wallet = await manager
        .getRepository(Wallet)
        .findOne({
          where: { id: split.walletId },
          lock: { mode: 'pessimistic_write' },
        });
      const period = cairoPeriod();
      if (
        !wallet ||
        Number(wallet.balance) < Number(split.amount) ||
        wallet.counterDay !== period.day ||
        wallet.counterMonth !== period.month ||
        Number(wallet.todayTopUp) < Number(split.amount) ||
        Number(wallet.dailyTopUp) < Number(split.amount) ||
        Number(wallet.monthlyTopUp) < Number(split.amount)
      )
        throw new BadRequestException(
          'رصيد المحفظة أو عدادات الفترة لا تسمح بإلغاء الاستلام',
        );
      wallet.balance = money(Number(wallet.balance) - Number(split.amount));
      wallet.todayTopUp = money(
        Number(wallet.todayTopUp) - Number(split.amount),
      );
      wallet.dailyTopUp = money(
        Number(wallet.dailyTopUp) - Number(split.amount),
      );
      wallet.monthlyTopUp = money(
        Number(wallet.monthlyTopUp) - Number(split.amount),
      );
      await manager.save(wallet);
    }
  }
  treasury.balance = money(
    Number(treasury.balance) - Number(receipt.cashAmount ?? receipt.amount),
  );
  if (treasury.balance < 0)
    throw new BadRequestException('رصيد الخزنة لا يكفي لإلغاء الاستلام');
  await manager.save(treasury);
  const ledger = manager.getRepository(LedgerEntry);
  const entries = await ledger.find({
    where: { reference: receipt.reference },
  });
  const parentKeys = [
    'profitSourceEntryId',
    'customerWalletTransferEntryId',
    'profitQrCashOutEntryId',
    'machineUsageEntryId',
    'walletUsageEntryId',
    'purchaseVisaUsageEntryId',
  ];
  const hasUnrelated = entries.some(
    (entry) =>
      entry.category !== LedgerCategory.REVERSAL &&
      !(
        (entry.entityType === 'collection' && entry.entityId === receipt.id) ||
        entry.metadata?.collectionId === receipt.id ||
        (entry.entityType === 'account' &&
          entry.entityId === receipt.accountId &&
          [
            LedgerCategory.COMPANY_EXECUTION,
            LedgerCategory.COMMISSION,
          ].includes(entry.category) &&
          !parentKeys.some((key) => entry.metadata?.[key]))
      ),
  );
  if (hasUnrelated)
    throw new BadRequestException(
      'مرجع الاستلام مستخدم في عملية أخرى؛ يلزم مراجعة الارتباط قبل الإلغاء',
    );
  for (const entry of entries.filter(
    (e) => e.category !== LedgerCategory.REVERSAL,
  )) {
    if (await ledger.exists({ where: { reversesEntryId: entry.id } }))
      throw new BadRequestException(
        'تم عكس جزء من العملية سابقًا؛ يلزم مراجعة ارتباطاتها',
      );
    await ledger.save({
      category: LedgerCategory.REVERSAL,
      amount: -Number(entry.amount),
      entityType: entry.entityType,
      entityId: entry.entityId,
      reference: entry.reference,
      performedBy: username,
      description: `إلغاء: ${entry.description} — ${reason}`,
      reversesEntryId: entry.id,
      metadata: {
        reason,
        collectionId: receipt.id,
        originalCategory: entry.category,
      },
    });
  }
  if (!entries.length)
    await ledger.save({
      category: LedgerCategory.REVERSAL,
      amount: 0,
      entityType: 'collection',
      entityId: receipt.id,
      reference: receipt.reference,
      description: `إلغاء استلام آجل: ${receipt.reference} — ${reason}`,
      performedBy: username,
      metadata: {
        reason,
        collectionId: receipt.id,
        originalCategory: LedgerCategory.CASH_RECEIPT,
      },
    });
  receipt.status = CollectionStatus.REVERSED;
  receipt.reversedAt = new Date();
  receipt.reversalReason = reason;
  await repo.save(receipt);
  if ((await agentCreditBalance(manager, receipt.agentName)) < 0)
    throw new BadRequestException(
      'تم استخدام آجل العملية في تسديد لاحق؛ الغِ الارتباط أولًا',
    );
  return receipt;
}

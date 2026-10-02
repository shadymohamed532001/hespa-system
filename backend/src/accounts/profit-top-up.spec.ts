import { describe, expect, it, vi } from 'vitest';
import { AccountsService } from './accounts.service.js';
import { LedgerService } from '../ledger/ledger.service.js';
import { FinancialAccount } from '../database/entities/financial-account.entity.js';
import { AccountType, LedgerCategory } from '../database/enums.js';

function fixture(balance = 100000) {
  const account = {
    id: 'account',
    type: AccountType.PROFIT,
    name: 'test',
    active: true,
    balance,
    commissionBalance: 0,
    todayTopUp: 0,
  };
  const entries: any[] = [];
  const accountRepo = {
    findOne: vi.fn(async () => account),
    save: vi.fn(async (a) => a),
  };
  const query: any = {
    where: () => query,
    andWhere: () => query,
    getOne: async () =>
      entries.find((e) => e.category === LedgerCategory.COMMISSION),
  };
  const ledgerRepo = {
    save: vi.fn(async (e) => {
      const entry = { id: String(entries.length), ...e };
      entries.push(entry);
      return entry;
    }),
    exists: async () => false,
    createQueryBuilder: () => query,
  };
  const manager: any = {
    getRepository: (entity) =>
      entity === FinancialAccount ? accountRepo : ledgerRepo,
    save: async (a) => a,
  };
  const dataSource: any = { transaction: async (fn) => fn(manager) };
  const service = new AccountsService(
    accountRepo as any,
    ledgerRepo as any,
    {} as any,
    {} as any,
    dataSource,
    {} as any,
    {} as any,
  );
  const ledger = new LedgerService(ledgerRepo as any, dataSource);
  return { account, entries, manager, service, ledger };
}

describe('Regular profit top-ups credited to spendable balance', () => {
  it('adds 200000 plus 1000 to an existing 100000 without increasing commission balance', async () => {
    const f = fixture();
    await f.service.topUp('account', { amount: 200000 }, 'test');
    expect(f.account.balance).toBe(301000);
    expect(f.account.commissionBalance).toBe(0);
    expect(f.account.todayTopUp).toBe(200000);
    expect(f.entries[0].metadata.profitDepositCommission).toBe(1000);
    expect(f.entries[1].metadata.profitDepositCreditedToBalance).toBe(true);
  });
  it('allows one million principal plus its 5000 bonus', async () => {
    const f = fixture(0);
    await f.service.topUp('account', { amount: 1000000 }, 'test');
    expect(f.account.balance).toBe(1005000);
    await expect(
      f.service.topUp('account', { amount: 1 }, 'test'),
    ).rejects.toThrow();
  });
  it('reverses both the principal and bonus without touching commissions', async () => {
    const f = fixture();
    await f.service.topUp('account', { amount: 200000 }, 'test');
    await (f.ledger as any).reverseTopUp(f.manager, f.entries[0]);
    await (f.ledger as any).reverseProfitCommission(
      f.manager,
      f.entries[0],
      'test',
      'test',
    );
    expect(f.account.balance).toBe(100000);
    expect(f.account.commissionBalance).toBe(0);
    expect(f.account.todayTopUp).toBe(0);
  });
  it('rejects reversal when the bonus has already been spent', async () => {
    const f = fixture(0);
    await f.service.topUp('account', { amount: 200000 }, 'test');
    f.account.balance = 200000;
    await expect(
      (f.ledger as any).reverseTopUp(f.manager, f.entries[0]),
    ).rejects.toThrow();
  });
  it('preserves reversal behavior for legacy commission-only deposits', async () => {
    const f = fixture(200000);
    f.account.todayTopUp = 200000;
    f.account.commissionBalance = 1000;
    f.entries.push({
      id: 'old',
      amount: 200000,
      entityId: 'account',
      entityType: 'account',
      category: LedgerCategory.TOP_UP,
    });
    f.entries.push({
      id: 'bonus',
      amount: 1000,
      entityId: 'account',
      category: LedgerCategory.COMMISSION,
    });
    await (f.ledger as any).reverseTopUp(f.manager, f.entries[0]);
    await (f.ledger as any).reverseProfitCommission(
      f.manager,
      f.entries[0],
      'test',
      'test',
    );
    expect(f.account.balance).toBe(0);
    expect(f.account.commissionBalance).toBe(0);
  });
});

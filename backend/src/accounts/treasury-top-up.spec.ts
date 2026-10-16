import { describe, expect, it, vi } from 'vitest';
import { LedgerService } from '../ledger/ledger.service.js';
import { AccountsService } from './accounts.service.js';
import { FinancialAccount } from '../database/entities/financial-account.entity.js';
import { Treasury } from '../database/entities/treasury.entity.js';
import { AccountType } from '../database/enums.js';

function setup(type: AccountType, balance = 2000) {
  const account = {
    id: 'account',
    name: 'test',
    type,
    balance: 0,
    todayTopUp: 0,
  };
  const treasury = { id: 'main', balance };
  const accountRepo = {
    findOne: vi.fn(async () => account),
    save: vi.fn(async (v) => v),
  };
  const treasuryRepo = {
    findOne: vi.fn(async () => treasury),
    save: vi.fn(async (v) => v),
  };
  const query = {
    where: () => query,
    andWhere: () => query,
    getOne: async () => null,
  };
  const ledger = {
    save: vi.fn(async (v) => ({ id: 'entry', ...v })),
    create: (value) => value,
    exists: async () => false,
    findOne: async () => ledger.save.mock.results[0]?.value,
    createQueryBuilder: () => query,
  };
  const manager = {
    getRepository: (entity) =>
      entity === FinancialAccount
        ? accountRepo
        : entity === Treasury
          ? treasuryRepo
          : ledger,
  };
  const service = new AccountsService(
    null!,
    null!,
    null!,
    null!,
    { transaction: async (fn) => fn(manager) } as any,
    null!,
    null!,
  );
  return {
    service,
    account,
    treasury,
    accountRepo,
    treasuryRepo,
    ledger,
    manager,
  };
}

describe('Account top-ups funded by treasury', () => {
  it.each([AccountType.FAWRY, AccountType.PROFIT])(
    'deducts principal for %s and preserves commission',
    async (type) => {
      const { service, account, treasury, ledger } = setup(type);
      await service.topUp('account', { amount: 1000 }, 'tester');
      expect(treasury.balance).toBe(1000);
      expect(account.balance).toBe(type === AccountType.PROFIT ? 1005 : 1000);
      expect(account.todayTopUp).toBe(1000);
      expect(ledger.save).toHaveBeenCalledWith(
        expect.objectContaining({
          sourceType: 'treasury',
          targetId: 'account',
          metadata: expect.objectContaining({ treasuryFundedTopUp: true }),
        }),
      );
    },
  );
  it('deducts the counted cash when recording a Fawry deposit', async () => {
    const f = setup(AccountType.FAWRY);
    await f.service.recordFawryDeposit(
      'account',
      {
        depositorName: 'test',
        cashCounts: {
          count200: 5,
          count100: 0,
          count50: 0,
          count20: 0,
          count10: 0,
          count5: 0,
        },
      },
      'tester',
    );
    expect(f.treasury.balance).toBe(1000);
    expect(f.account.balance).toBe(1000);
    expect(f.account.todayTopUp).toBe(1000);
  });
  it('returns the principal to treasury when reversing a funded top-up', async () => {
    const f = setup(AccountType.FAWRY);
    await f.service.topUp('account', { amount: 1000 }, 'tester');
    const manager = { ...f.manager, save: async (value) => value };
    const reversals = new LedgerService(
      f.ledger as any,
      { transaction: async (fn) => fn(manager) } as any,
    );
    await reversals.reverse('entry', { reason: 'test' }, 'tester');
    expect(f.account.balance).toBe(0);
    expect(f.treasury.balance).toBe(2000);
  });
  it('rejects insufficient cash before saving any balances or ledger entries', async () => {
    const { service, accountRepo, treasuryRepo, ledger } = setup(
      AccountType.FAWRY,
      999,
    );
    await expect(
      service.topUp('account', { amount: 1000 }, 'tester'),
    ).rejects.toThrow();
    expect(accountRepo.save).not.toHaveBeenCalled();
    expect(treasuryRepo.save).not.toHaveBeenCalled();
    expect(ledger.save).not.toHaveBeenCalled();
  });
});

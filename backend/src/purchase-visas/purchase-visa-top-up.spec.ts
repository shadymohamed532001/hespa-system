import { describe, expect, it, vi } from 'vitest';
import { LedgerCategory } from '../database/enums.js';
import { PurchaseVisa } from '../database/entities/purchase-visa.entity.js';
import { PurchaseVisasService } from './purchase-visas.service.js';

function fixture(balance = 1000, found = true) {
  const visa = {
    id: 'visa',
    name: 'shady mohaned',
    active: true,
    balance,
  };
  const entries: Array<Record<string, unknown>> = [];
  const visaRepo = {
    findOne: vi.fn(async () => (found ? visa : null)),
    save: vi.fn(async (item: typeof visa) => item),
  };
  const ledgerRepo = {
    save: vi.fn(async (entry: Record<string, unknown>) => {
      entries.push(entry);
      return entry;
    }),
  };
  const manager = {
    getRepository: (entity: unknown) =>
      entity === PurchaseVisa ? visaRepo : ledgerRepo,
    save: async (item: typeof visa) => item,
  };
  const dataSource = {
    transaction: async (fn: (m: typeof manager) => unknown) => fn(manager),
  };
  const service = new PurchaseVisasService({} as never, dataSource as never);
  return { visa, entries, service };
}

describe('purchase visa top-up', () => {
  it('adds the amount to the existing visa balance', async () => {
    const f = fixture(1000);
    const visa = await f.service.topUp('visa', { amount: 500 }, 'mahmoud');
    expect(visa.balance).toBe(1500);
    expect(f.entries).toEqual([
      expect.objectContaining({
        category: LedgerCategory.TOP_UP,
        amount: 500,
        entityType: 'purchase_visa',
        entityId: 'visa',
        description: 'شحن فيزا المشتريات shady mohaned',
        performedBy: 'mahmoud',
      }),
    ]);
  });

  it('rejects a missing visa', async () => {
    const f = fixture(1000, false);
    await expect(
      f.service.topUp('missing', { amount: 10 }, 'mahmoud'),
    ).rejects.toThrow();
  });
});

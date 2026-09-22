import { describe, expect, it, vi } from 'vitest';
import { LedgerCategory } from '../database/enums.js';
import { ReportsService } from './reports.service.js';

const start = new Date('2026-09-20T21:00:00.000Z');
const end = new Date('2026-09-21T21:00:00.000Z');
const at = new Date('2026-09-21T09:00:00.000Z');

function repository(findResult: unknown = [], findOneResult: unknown = null) {
  return {
    find: vi.fn().mockResolvedValue(findResult),
    findOne: vi.fn().mockResolvedValue(findOneResult),
  };
}

function createService() {
  const ledger = [
    {
      id: 'top-up',
      category: LedgerCategory.TOP_UP,
      amount: 100,
      entityType: 'account',
      entityId: 'account-1',
      reference: null,
      description: 'شحن حساب فوري',
      performedBy: 'admin',
      sourceType: null,
      sourceId: null,
      targetType: null,
      targetId: null,
      createdAt: at,
    },
    {
      id: 'execution',
      category: LedgerCategory.COMPANY_EXECUTION,
      amount: -40,
      entityType: 'account',
      entityId: 'account-1',
      reference: 'COL-1',
      description: 'تنفيذ شركة',
      performedBy: 'admin',
      sourceType: null,
      sourceId: null,
      targetType: null,
      targetId: null,
      createdAt: at,
    },
    {
      id: 'transfer',
      category: LedgerCategory.INTERNAL_TRANSFER,
      amount: 25,
      entityType: 'internal_transfer',
      entityId: null,
      reference: null,
      description: 'تحويل داخلي',
      performedBy: 'admin',
      sourceType: 'account',
      sourceId: 'account-1',
      targetType: 'wallet',
      targetId: 'wallet-1',
      createdAt: at,
    },
    {
      id: 'commission',
      category: LedgerCategory.COMMISSION,
      amount: 5,
      entityType: 'account',
      entityId: 'account-1',
      reference: 'COL-1',
      description: 'عمولة',
      performedBy: 'admin',
      sourceType: null,
      sourceId: null,
      targetType: null,
      targetId: null,
      createdAt: at,
    },
  ];
  const sales = [
    {
      id: 'sale-1',
      productId: 'product-1',
      product: { name: 'هاتف', category: 'mobile' },
      quantity: 2,
      unitPrice: 50,
      totalAmount: 100,
      note: null,
      performedBy: 'admin',
      createdAt: at,
    },
  ];
  const accounts = [
    {
      id: 'account-1',
      name: 'فوري 1',
      type: 'fawry',
      balance: 500,
      createdAt: at,
    },
  ];
  const wallets = [
    {
      id: 'wallet-1',
      name: 'محفظة 1',
      type: 'wallet',
      balance: 200,
      createdAt: at,
    },
  ];
  const products = [
    { id: 'product-1', stockQty: 3, defaultPrice: 50, createdAt: at },
  ];

  return new ReportsService(
    repository(ledger) as never,
    repository(sales) as never,
    repository(products) as never,
    repository([], { id: 'inventory', balance: 100 }) as never,
    repository([]) as never,
    repository(accounts) as never,
    repository(wallets) as never,
    repository([]) as never,
    repository([], { id: 'main', balance: 1000 }) as never,
  );
}

describe('ReportsService', () => {
  it('keeps internal transfers neutral in the whole-system totals', async () => {
    const report = await createService().summary({
      start,
      end,
      entityType: 'all',
    });

    expect(report.summary).toMatchObject({
      deposits: 200,
      withdrawals: 40,
      net: 160,
      commissions: 5,
      salesAmount: 100,
      salesCount: 1,
      soldUnits: 2,
      operationCount: 5,
    });
    expect(report.daily[0]).toMatchObject({
      deposits: 200,
      withdrawals: 40,
      net: 160,
      sales: 100,
      commissions: 5,
    });
  });

  it('counts a transfer as withdrawal when its source account is selected', async () => {
    const report = await createService().summary({
      start,
      end,
      entityType: 'account',
      entityId: 'account-1',
    });

    expect(report.summary).toMatchObject({
      deposits: 100,
      withdrawals: 65,
      net: 35,
      commissions: 5,
      salesAmount: 0,
    });
    expect(report.channels).toHaveLength(1);
    expect(report.channels[0]).toMatchObject({
      name: 'فوري 1',
      deposits: 100,
      withdrawals: 65,
      commissions: 5,
      net: 35,
    });
    expect(report.operations.find((row) => row.id === 'transfer')?.kind).toBe(
      'withdrawal',
    );
  });
});

import { describe, expect, it } from 'vitest';
import { LedgerCategory } from '../../database/enums.js';
import {
  redactProfitData,
  redactProfitText,
} from './profit-visibility.interceptor.js';

describe('profit visibility redaction', () => {
  it('removes profit fields recursively without changing operational values', () => {
    const result = redactProfitData({
      balance: 120,
      commissionBalance: 14,
      nested: {
        grossProfit: 30,
        costPrice: 90,
        defaultPrice: 120,
      },
    });

    expect(result).toEqual({
      balance: 120,
      nested: { defaultPrice: 120 },
    });
  });

  it('removes commission ledger entries and their reversals', () => {
    const result = redactProfitData([
      { id: 'usage', category: LedgerCategory.MACHINE_USAGE, amount: 20 },
      { id: 'profit', category: LedgerCategory.COMMISSION, amount: 2 },
      { id: 'cash-fee', category: LedgerCategory.WALLET_CASH_FEE, amount: 2 },
      {
        id: 'profit-reversal',
        category: LedgerCategory.REVERSAL,
        amount: -2,
        metadata: { originalCategory: LedgerCategory.COMMISSION },
      },
      {
        id: 'cash-fee-reversal',
        category: LedgerCategory.REVERSAL,
        amount: -2,
        metadata: { originalCategory: LedgerCategory.WALLET_CASH_FEE },
      },
    ]);

    expect(result).toEqual([
      { id: 'usage', category: LedgerCategory.MACHINE_USAGE, amount: 20 },
    ]);
    expect(
      redactProfitData({
        reversal: {
          category: LedgerCategory.REVERSAL,
          amount: -2,
          metadata: { originalCategory: LedgerCategory.COMMISSION },
        },
      }),
    ).toEqual({ reversal: undefined });
  });

  it('removes embedded commission amounts from operational descriptions', () => {
    expect(redactProfitText('استخدام محفظة وعمولته 5.50 ج.م')).toBe(
      'استخدام محفظة',
    );
    expect(
      redactProfitText(
        'Machine used, total commissions: EGP 17.50, last operation commission: EGP 2.50. Please top up.',
      ),
    ).toBe('Machine used. Please top up.');
  });
});

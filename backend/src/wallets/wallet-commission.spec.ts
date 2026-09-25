import { describe, expect, it } from 'vitest';
import { walletCommission } from './wallet-commission.js';

describe('customer wallet commissions', () => {
  it.each([
    [1, 5],
    [200, 5],
    [200.01, 10],
    [500, 10],
    [500.01, 20],
    [1000, 20],
    [1000.01, 25],
    [1200, 25],
    [1500, 30],
    [2000, 40],
  ])('charges %i EGP send as %i EGP', (amount, expected) => {
    expect(walletCommission('vodafone_cash', 'send', amount)).toBe(expected);
  });

  it.each([
    [1, 5],
    [200, 5],
    [200.01, 10],
    [1000, 10],
    [1000.01, 10],
    [2000, 10],
  ])('charges %i EGP receive as %i EGP', (amount, expected) => {
    expect(walletCommission('orange_cash', 'receive', amount)).toBe(expected);
  });

  it.each([['send' as const], ['receive' as const]])(
    'charges InstaPay for %s',
    (direction) => {
      expect(walletCommission('instapay', direction, 99.99)).toBe(10);
      expect(walletCommission('instapay', direction, 100)).toBe(5);
      expect(walletCommission('instapay', direction, 200)).toBe(5);
      expect(walletCommission('instapay', direction, 200.01)).toBe(10);
    },
  );
});

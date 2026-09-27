import { describe, expect, it } from 'vitest';
import {
  regularProfitDepositCommission,
  regularProfitWithdrawCommission,
} from './profit-commission.js';

describe('regular profit commission', () => {
  it('pays 5,000 EGP on a full million and 5 EGP on each thousand', () => {
    expect(regularProfitDepositCommission(1_000_000)).toBe(5000);
    expect(regularProfitDepositCommission(1000)).toBe(5);
    expect(regularProfitDepositCommission(2500)).toBe(12.5);
  });

  it('takes 4 EGP back on each thousand transferred out', () => {
    expect(regularProfitWithdrawCommission(1_000_000)).toBe(4000);
    expect(regularProfitWithdrawCommission(1000)).toBe(4);
    expect(regularProfitWithdrawCommission(2500)).toBe(10);
  });
});

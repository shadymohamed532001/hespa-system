import { describe, expect, it } from 'vitest';
import { Wallet } from '../database/entities/wallet.entity.js';
import {
  addWalletPeriodUsage,
  crossedDailyWalletNotice,
  recordWalletIncoming,
} from './wallets.service.js';

function walletWithUsage(dailyTopUp: number, monthlyTopUp: number) {
  const day = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Africa/Cairo',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(new Date());
  return Object.assign(new Wallet(), {
    name: 'test wallet',
    balance: 100,
    todayTopUp: dailyTopUp,
    dailyTopUp,
    monthlyTopUp,
    counterDay: day,
    counterMonth: day.slice(0, 7),
  });
}

describe('crossedDailyWalletNotice', () => {
  it('is true only when an operation crosses 50,000', () => {
    expect(crossedDailyWalletNotice(49_000, 50_000)).toBe(true);
    expect(crossedDailyWalletNotice(10_000, 49_999.99)).toBe(false);
    expect(crossedDailyWalletNotice(50_000, 55_000)).toBe(false);
    expect(crossedDailyWalletNotice(0, 60_000)).toBe(true);
  });
});

describe('wallet incoming limits', () => {
  it('rejects a customer transfer that would exceed the daily limit without changing counters', () => {
    const wallet = walletWithUsage(59_999, 59_999);
    expect(() => addWalletPeriodUsage(wallet, 1.01)).toThrow();
    expect(wallet.dailyTopUp).toBe(59_999);
    expect(wallet.monthlyTopUp).toBe(59_999);
  });

  it('rejects a customer transfer that would exceed the monthly limit', () => {
    const wallet = walletWithUsage(1_000, 199_999);
    expect(() => addWalletPeriodUsage(wallet, 1.01)).toThrow();
    expect(wallet.dailyTopUp).toBe(1_000);
    expect(wallet.monthlyTopUp).toBe(199_999);
  });

  it('accepts the exact daily limit and still records wallet top-ups', () => {
    const wallet = walletWithUsage(59_999, 199_999);
    expect(recordWalletIncoming(wallet, 1)).toEqual({
      crossedDailyNotice: false,
    });
    expect(wallet.dailyTopUp).toBe(60_000);
    expect(wallet.monthlyTopUp).toBe(200_000);
    expect(wallet.balance).toBe(101);
  });

  it('stores the incoming balance in cents', () => {
    const wallet = walletWithUsage(0, 0);
    wallet.balance = 0.1;
    wallet.todayTopUp = 0.1;
    recordWalletIncoming(wallet, 0.2);
    expect(wallet.balance).toBe(0.3);
    expect(wallet.todayTopUp).toBe(0.3);
  });
});

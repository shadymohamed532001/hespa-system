import { describe, expect, it } from 'vitest';
import {
  purchaseVisaProfit,
  profitQrCustomerCommission,
  profitQrIncomingFee,
  profitQrOutgoingFee,
  regularProfitCollectionCommission,
  regularProfitDepositCommission,
  regularProfitWithdrawCommission,
} from './profit-commission.js';

describe('regular profit commission', () => {
  it.each([
    [1, 5],
    [499.99, 5],
    [500, 5],
    [500.01, 10],
    [800, 10],
    [1000, 10],
    [1000.01, 10],
    [2000, 20],
  ])('QR customer fee for %s is %s', (amount, fee) => {
    expect(profitQrCustomerCommission(amount)).toBe(fee);
  });

  it('preserves piasters for deposits, transfers, collections and visa profit', () => {
    expect(regularProfitDepositCommission(1234.56)).toBe(6.17);
    expect(regularProfitWithdrawCommission(1234.56)).toBe(4.94);
    expect(regularProfitCollectionCommission(1234.56)).toBe(4.94);
    expect(regularProfitDepositCommission(1)).toBe(0.01);
    expect(profitQrIncomingFee(2.5)).toBe(0.01);
    expect(purchaseVisaProfit(1234.56, true)).toEqual({
      grossProfit: 24.69,
      serviceFee: 8.64,
      netProfit: 16.05,
    });
  });

  it('pays 5,000 EGP on a full million and 5 EGP on each thousand', () => {
    expect(regularProfitDepositCommission(1_000_000)).toBe(5000);
    expect(regularProfitDepositCommission(1000)).toBe(5);
    expect(regularProfitDepositCommission(2500)).toBe(12.5);
  });

  it('records 4 EGP per thousand on a profit collection', () => {
    expect(regularProfitCollectionCommission(1000)).toBe(4);
  });

  it('takes 4 EGP back on each thousand transferred out', () => {
    expect(regularProfitWithdrawCommission(1_000_000)).toBe(4000);
    expect(regularProfitWithdrawCommission(1000)).toBe(4);
    expect(regularProfitWithdrawCommission(2500)).toBe(10);
  });

  it('keeps 20 per thousand on a purchase visa, or 13 when a machine takes 7', () => {
    expect(purchaseVisaProfit(1000, false)).toEqual({
      grossProfit: 20,
      serviceFee: 0,
      netProfit: 20,
    });
    expect(purchaseVisaProfit(1000, true)).toEqual({
      grossProfit: 20,
      serviceFee: 7,
      netProfit: 13,
    });
    expect(purchaseVisaProfit(2500, true)).toEqual({
      grossProfit: 50,
      serviceFee: 17.5,
      netProfit: 32.5,
    });
  });

  it('calculates the QR customer and provider rates proportionally', () => {
    expect(profitQrCustomerCommission(1000)).toBe(10);
    expect(profitQrIncomingFee(1000)).toBe(2);
    expect(profitQrOutgoingFee(1000)).toBe(4);
    expect(profitQrCustomerCommission(1500)).toBe(15);
    expect(profitQrIncomingFee(1500)).toBe(3);
    expect(profitQrOutgoingFee(1500)).toBe(6);
    expect(profitQrCustomerCommission(1234.56)).toBe(12.35);
    expect(profitQrIncomingFee(1234.56)).toBe(2.47);
    expect(profitQrOutgoingFee(1234.56)).toBe(4.94);
  });
});

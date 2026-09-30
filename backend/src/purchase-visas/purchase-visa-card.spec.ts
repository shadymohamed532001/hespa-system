import { describe, expect, it } from 'vitest';
import { UserRole } from '../database/enums.js';
import {
  maskCardNumber,
  parsePurchaseVisaCard,
  redactCardNumbers,
  viewerCanSeePurchaseVisaNumber,
} from './purchase-visa-card.js';

describe('parsePurchaseVisaCard', () => {
  const now = new Date(2026, 8, 29);

  it('accepts a 16-digit number and an MM/YY expiry', () => {
    expect(parsePurchaseVisaCard('4111 1111 1111 1111', '09/28', now)).toEqual({
      ok: true,
      cardNumber: '4111111111111111',
      expiresOn: '2028-09-30',
    });
  });

  it('rejects a number that fails the check digit', () => {
    expect(parsePurchaseVisaCard('4111111111111112', '09/28', now)).toEqual({
      ok: false,
      error: 'card',
    });
  });

  it('rejects a short number and a bad expiry', () => {
    expect(parsePurchaseVisaCard('411111111111', '09/28', now).ok).toBe(false);
    expect(parsePurchaseVisaCard('4111111111111111', '13/28', now)).toEqual({
      ok: false,
      error: 'expiry',
    });
  });

  it('rejects a card that already expired', () => {
    expect(parsePurchaseVisaCard('4111111111111111', '08/26', now)).toEqual({
      ok: false,
      error: 'expired',
    });
  });

  it('keeps a card that expires during the current month', () => {
    expect(parsePurchaseVisaCard('4111111111111111', '09/26', now).ok).toBe(
      true,
    );
  });
});

describe('purchase visa card visibility', () => {
  it('shows only the last four digits to balance viewers', () => {
    expect(maskCardNumber('4111111111111111')).toBe('************1111');
    expect(
      viewerCanSeePurchaseVisaNumber(UserRole.EMPLOYEE, ['view_balances']),
    ).toBe(false);
    expect(
      redactCardNumbers(
        {
          name: 'فيزا المحل',
          cardNumber: '4111111111111111',
          purchaseVisa: { cardNumber: '4111111111111111', name: 'nested' },
        },
        false,
      ),
    ).toEqual({
      name: 'فيزا المحل',
      cardNumber: '************1111',
      purchaseVisa: { cardNumber: '************1111', name: 'nested' },
    });
  });

  it('keeps the full number for admins and visa operators', () => {
    const number = '4111111111111111';
    expect(viewerCanSeePurchaseVisaNumber(UserRole.ADMIN, [])).toBe(true);
    expect(
      viewerCanSeePurchaseVisaNumber(UserRole.EMPLOYEE, ['use_purchase_visas']),
    ).toBe(true);
    expect(
      viewerCanSeePurchaseVisaNumber(UserRole.EMPLOYEE, ['manage_assets']),
    ).toBe(true);
    expect(redactCardNumbers({ cardNumber: number }, true)).toEqual({
      cardNumber: number,
    });
  });
});

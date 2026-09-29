import { describe, expect, it } from 'vitest';
import { parsePurchaseVisaCard } from './purchase-visa-card.js';

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

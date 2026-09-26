import { describe, expect, it } from 'vitest';
import { normalizeRequestNumbers } from './normalize-digits.js';

describe('normalizeRequestNumbers', () => {
  it('accepts Arabic and Persian digits as numbers and leaves names as text', () => {
    expect(
      normalizeRequestNumbers({
        amount: '٥٠٠٠٠',
        cashAmount: '۴۰۰۰۰',
        wallet: '٠١٠٢٣١٢٥٠٣٧',
        note: 'مندوب ١٠',
        nested: [{ amount: '١٠.٥' }],
      }),
    ).toEqual({
      amount: 50000,
      cashAmount: 40000,
      wallet: '01023125037',
      note: 'مندوب 10',
      nested: [{ amount: 10.5 }],
    });
  });
});

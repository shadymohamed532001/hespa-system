import { describe, expect, it } from 'vitest';
import { sanitizeAuditValue } from './audit.interceptor.js';

describe('sanitizeAuditValue', () => {
  it('removes passwords and full card numbers from recorded requests', () => {
    expect(
      sanitizeAuditValue({
        password: 'demo',
        cardNumber: '4111111111111111',
        card_number: '4111111111111111',
        name: 'فيزا المحل',
      }),
    ).toEqual({
      password: '[redacted]',
      cardNumber: '[redacted]',
      card_number: '[redacted]',
      name: 'فيزا المحل',
    });
  });
});

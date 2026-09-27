import { describe, expect, it } from 'vitest';
import { fawryCashTotal } from './accounts.service.js';

describe('Fawry cash deposit', () => {
  it('calculates the total from the banknote counts', () => {
    expect(
      fawryCashTotal({
        count200: 10,
        count100: 5,
        count50: 2,
        count20: 3,
        count10: 4,
        count5: 6,
      }),
    ).toBe(2730);
  });
});

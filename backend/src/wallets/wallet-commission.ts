export type CustomerWalletDirection = 'send' | 'receive';

/** The customer amount is in pounds; all boundaries are inclusive. */
export function walletCommission(
  type: string,
  direction: CustomerWalletDirection,
  amount: number,
): number {
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new RangeError('The customer amount must be positive');
  }

  const cents = Math.round(amount * 100);
  if (Math.abs(amount * 100 - cents) > 0.000001) {
    throw new RangeError(
      'The customer amount must have at most two decimal places',
    );
  }

  if (type === 'instapay') {
    return cents >= 10_000 && cents <= 20_000 ? 5 : 10;
  }

  if (direction === 'receive') {
    if (cents <= 20_000) return 5;
    return 10;
  }

  const completeThousands = Math.floor((cents - 1) / 100_000);
  const remainder = cents - completeThousands * 100_000;
  const remainderCommission =
    remainder <= 20_000 ? 5 : remainder <= 50_000 ? 10 : 20;
  return completeThousands * 20 + remainderCommission;
}

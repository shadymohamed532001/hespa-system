/** Regular profit accounts: 5 EGP per 1,000 topped up, 4 EGP per 1,000 transferred out. */
export const REGULAR_PROFIT_LIMIT = 1_000_000;

export function regularProfitDepositCommission(amount: number): number {
  return commissionPerThousand(amount, 5);
}

export function regularProfitWithdrawCommission(amount: number): number {
  return commissionPerThousand(amount, 4);
}

function commissionPerThousand(amount: number, poundsPerThousand: number): number {
  const cents = Math.round(Number(amount) * 100);
  const feeCents = Math.round((cents * poundsPerThousand) / 1000);
  return feeCents / 100;
}

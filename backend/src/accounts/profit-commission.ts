/** Regular profit accounts: 5 EGP per 1,000 topped up, 4 EGP per 1,000 transferred out. */
export const REGULAR_PROFIT_LIMIT = 1_000_000;

export function regularProfitDepositCommission(amount: number): number {
  return commissionPerThousand(amount, 5);
}

export function regularProfitWithdrawCommission(amount: number): number {
  return commissionPerThousand(amount, 4);
}

/** Collection execution on a regular profit account records 4 EGP per 1,000. */
export function regularProfitCollectionCommission(amount: number): number {
  return commissionPerThousand(amount, 4);
}

/** QR cash-out: the customer pays 10 EGP per 1,000 of cash requested. */
export function profitQrCustomerCommission(amount: number): number {
  return commissionPerThousand(amount, 10);
}

/** QR cash-out: Maksab deducts 2 EGP per 1,000 of cash requested. */
export function profitQrIncomingFee(amount: number): number {
  return commissionPerThousand(amount, 2);
}

/** QR outgoing payments: Maksab deducts 4 EGP per 1,000 sent. */
export function profitQrOutgoingFee(amount: number): number {
  return commissionPerThousand(amount, 4);
}

function commissionPerThousand(
  amount: number,
  poundsPerThousand: number,
): number {
  const cents = Math.round(Number(amount) * 100);
  const feeCents = Math.round((cents * poundsPerThousand) / 1000);
  return feeCents / 100;
}

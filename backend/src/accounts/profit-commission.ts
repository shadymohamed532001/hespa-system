/** Regular profit accounts: 5 EGP per 1,000 topped up, 4 EGP per 1,000 transferred out. */
export const REGULAR_PROFIT_LIMIT = 1_000_000;

export function regularProfitDepositCommission(amount: number): number {
  return commissionPerThousand(amount, 5);
}

export function regularProfitWithdrawCommission(amount: number): number {
  return commissionPerThousand(amount, 4);
}

/** Collection execution on a regular profit account costs 4 EGP per 1,000. */
export function regularProfitCollectionCommission(amount: number): number {
  return commissionPerThousand(amount, 4);
}

/** QR customer fee: 5 up to 500, 10 up to 1,000, then 10 per thousand. */
export function profitQrCustomerCommission(amount: number): number {
  if (amount <= 0) return 0;
  if (amount <= 500) return 5;
  if (amount <= 1000) return 10;
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

/** Purchase visa: the shop keeps 20 EGP per 1,000, or 13 when a machine takes 7. */
export function purchaseVisaProfit(amount: number, withService: boolean) {
  const grossProfit = commissionPerThousand(amount, 20);
  const serviceFee = withService ? commissionPerThousand(amount, 7) : 0;
  return {
    grossProfit,
    serviceFee,
    netProfit: Number((grossProfit - serviceFee).toFixed(2)),
  };
}

function commissionPerThousand(
  amount: number,
  poundsPerThousand: number,
): number {
  const cents = Math.round(Number(amount) * 100);
  const feeCents = Math.round((cents * poundsPerThousand) / 1000);
  return feeCents / 100;
}

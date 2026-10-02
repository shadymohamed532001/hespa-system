class ProfitQrCashOutBreakdown {
  const ProfitQrCashOutBreakdown({
    required this.cashAmount,
    required this.customerCommission,
    required this.providerIncomingFee,
    required this.customerTransferAmount,
    required this.creditedAmount,
    required this.netCommissionBeforeSettlement,
    required this.providerOutgoingFee,
    required this.finalNetCommission,
  });

  final num cashAmount;
  final num customerCommission;
  final num providerIncomingFee;
  final num customerTransferAmount;
  final num creditedAmount;
  final num netCommissionBeforeSettlement;
  final num providerOutgoingFee;
  final num finalNetCommission;
}

ProfitQrCashOutBreakdown? profitQrCashOutBreakdown(
  num? cashAmount, {
  bool commissionInCash = false,
}) {
  if (cashAmount == null || cashAmount <= 0) return null;
  final customerCommission = cashAmount <= 500
      ? 5
      : cashAmount <= 1000
      ? 10
      : _perThousand(cashAmount, 10);
  final providerIncomingFee = _perThousand(cashAmount, 2);
  final providerOutgoingFee = _perThousand(cashAmount, 4);
  final customerTransferAmount = _money(cashAmount);
  final creditedAmount = _money(customerTransferAmount - providerIncomingFee);
  final netCommissionBeforeSettlement = _money(
    customerCommission - providerIncomingFee,
  );
  return ProfitQrCashOutBreakdown(
    cashAmount: _money(
      commissionInCash ? cashAmount : cashAmount - customerCommission,
    ),
    customerCommission: customerCommission,
    providerIncomingFee: providerIncomingFee,
    customerTransferAmount: customerTransferAmount,
    creditedAmount: creditedAmount,
    netCommissionBeforeSettlement: netCommissionBeforeSettlement,
    providerOutgoingFee: providerOutgoingFee,
    finalNetCommission: _money(
      netCommissionBeforeSettlement - providerOutgoingFee,
    ),
  );
}

num profitQrOutgoingFee(num amount) => _perThousand(amount, 4);

num _perThousand(num amount, num pounds) {
  final cents = (amount * 100).round();
  final feeCents = ((cents * pounds) / 1000).round();
  return feeCents / 100;
}

num _money(num amount) => (amount * 100).round() / 100;

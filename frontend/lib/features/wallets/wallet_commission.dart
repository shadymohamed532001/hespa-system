num? customerWalletCommission({
  required String type,
  required String direction,
  required num? amount,
}) {
  if (amount == null || amount <= 0) return null;
  final cents = (amount * 100).round();
  if ((amount * 100 - cents).abs() > 0.000001) return null;

  if (type == 'instapay') {
    if (cents < 100000) return 5;
    final commissionCents = (cents / 100).round();
    return commissionCents / 100;
  }
  if (direction == 'send') return _sendWalletCommission(cents);

  final completeThousands = (cents - 1) ~/ 100000;
  final remainder = cents - completeThousands * 100000;
  final remainderCommission = remainder <= 20000
      ? 5
      : remainder <= 50000
      ? 10
      : 20;
  return completeThousands * 20 + remainderCommission;
}

num _sendWalletCommission(int cents) {
  return (cents / 50000).ceil() * 5;
}

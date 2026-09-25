int? customerWalletCommission({
  required String type,
  required String direction,
  required num? amount,
}) {
  if (amount == null || amount <= 0) return null;
  final cents = (amount * 100).round();
  if ((amount * 100 - cents).abs() > 0.000001) return null;

  if (type == 'instapay') {
    return cents >= 10000 && cents <= 20000 ? 5 : 10;
  }
  if (direction == 'receive') return cents <= 20000 ? 5 : 10;

  final completeThousands = (cents - 1) ~/ 100000;
  final remainder = cents - completeThousands * 100000;
  final remainderCommission = remainder <= 20000
      ? 5
      : remainder <= 50000
      ? 10
      : 20;
  return completeThousands * 20 + remainderCommission;
}

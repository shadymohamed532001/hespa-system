/// Purchase visa profit: 20 EGP per 1,000, or 13 when a machine takes 7.
num purchaseVisaCollectionProfit(num amount, bool withService) {
  if (amount <= 0) return 0;
  final gross = _perThousand(amount, 20);
  final service = withService ? _perThousand(amount, 7) : 0;
  return ((gross - service) * 100).round() / 100;
}

num _perThousand(num amount, int rate) {
  final cents = (amount * 100).round();
  final feeCents = ((cents * rate) / 1000).round();
  return feeCents / 100;
}

/// 4 EGP per 1,000 of the collected amount, rounded to piasters.
num profitCollectionCommission(num amount) {
  if (amount <= 0) return 0;
  final cents = (amount * 100).round();
  final feeCents = ((cents * 4) / 1000).round();
  return feeCents / 100;
}

String formatProfitCollectionCommission(num amount) {
  final value = profitCollectionCommission(amount);
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  final text = value.toStringAsFixed(2);
  return text.endsWith('0') ? text.substring(0, text.length - 1) : text;
}

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../settings/hesba_l10n.dart';

final _money = NumberFormat('#,##0.##', 'en');

String money(dynamic value, {BuildContext? context}) {
  final amount = _money.format(num.tryParse('$value') ?? 0);
  final english =
      context != null && HesbaL10n.maybeOf(context)?.strings.isArabic == false;
  return english ? 'EGP $amount' : '$amount ج.م';
}

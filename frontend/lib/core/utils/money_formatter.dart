import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../settings/hesba_l10n.dart';
import 'digits.dart';

final _money = NumberFormat('#,##0.##', 'en');

String money(dynamic value, {BuildContext? context}) {
  final parsed = value is num ? value : parseNum('$value');
  final amount = _money.format(parsed ?? 0);
  final english =
      context != null && HesbaL10n.maybeOf(context)?.strings.isArabic == false;
  return english ? 'EGP $amount' : '$amount ج.م';
}

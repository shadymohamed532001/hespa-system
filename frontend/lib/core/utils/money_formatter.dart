import 'package:intl/intl.dart';

final _money = NumberFormat('#,##0.##', 'en');
String money(dynamic value) =>
    '${_money.format(num.tryParse('$value') ?? 0)} ج.م';

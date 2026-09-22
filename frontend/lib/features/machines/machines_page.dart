import 'package:flutter/material.dart';

import '../../core/utils/money_formatter.dart';
import '../auth/session_controller.dart';
import '../resources/simple_resource_page.dart';

class MachinesPage extends StatelessWidget {
  const MachinesPage({super.key, required this.session});
  final SessionController session;
  @override
  Widget build(BuildContext context) => SimpleResourcePage(
    session: session,
    title: 'ماكينات شحن الرصيد',
    subtitle: 'متابعة كل ماكينة بصورة مستقلة',
    endpoint: '/machines',
    columns: const [
      'الماكينة',
      'المبلغ المشحون',
      'المستخدم',
      'المتبقي',
      'العمولات',
      'الحالة',
    ],
    rowBuilder: (e) => [
      '${e['name']}',
      money(e['loadedBalance']),
      money(e['usedBalance']),
      money(e['remainingBalance']),
      money(e['commissionBalance']),
      e['active'] == true ? 'نشط' : 'موقوف',
    ],
    adminTopUpPath: (id) => '/machines/$id/load',
    topUpLabel: 'شحن ماكينة',
    topUpNote: 'يزيد الرصيد المتاح للماكينة',
  );
}

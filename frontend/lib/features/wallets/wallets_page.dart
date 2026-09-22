import 'package:flutter/material.dart';

import '../../core/network/api_endpoints.dart';
import '../../core/utils/money_formatter.dart';
import '../auth/session_controller.dart';
import '../resources/simple_resource_page.dart';

class WalletsPage extends StatelessWidget {
  const WalletsPage({super.key, required this.session});
  final SessionController session;
  @override
  Widget build(BuildContext context) => SimpleResourcePage(
    session: session,
    title: 'المحافظ وInstaPay',
    subtitle: 'الرصيد المتبقي يُرحّل، وحدود الشحن محسوبة تلقائيًا',
    endpoint: ApiEndpoints.wallets,
    columns: const [
      'المحفظة',
      'النوع',
      'مرحل من أمس',
      'شحن اليوم',
      'الرصيد',
      'الشحن اليومي',
      'الشحن الشهري',
      'العمولات',
    ],
    rowBuilder: (e) => [
      '${e['name']}',
      e['type'] == 'instapay' ? 'InstaPay' : 'محفظة',
      money(e['openingBalance']),
      money(e['todayTopUp']),
      money(e['balance']),
      '${money(e['dailyTopUp'])} / 60,000',
      '${money(e['monthlyTopUp'])} / 200,000',
      money(e['commissionBalance']),
    ],
    adminTopUpPath: ApiEndpoints.walletTopUp,
    topUpLabel: 'شحن محفظة',
    topUpNote: 'الحد اليومي 60,000 والشهري 200,000 ج.م',
  );
}

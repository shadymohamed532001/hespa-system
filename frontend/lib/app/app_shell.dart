import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../features/accounts/accounts_page.dart';
import '../features/admin/admin_page.dart';
import '../features/auth/session_controller.dart';
import '../features/collections/collections_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/ledger/ledger_page.dart';
import '../features/machines/machines_page.dart';
import '../features/treasury/treasury_page.dart';
import '../features/wallets/wallets_page.dart';
import '../core/theme/app_theme.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.session});
  final SessionController session;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selected = 0;

  late final items = <_NavItem>[
    _NavItem(
      'لوحة المتابعة',
      Icons.dashboard_outlined,
      () => DashboardPage(session: widget.session),
    ),
    _NavItem(
      'الخزنة المركزية',
      Icons.account_balance_outlined,
      () => TreasuryPage(session: widget.session),
    ),
    _NavItem(
      'فوري والشركات',
      Icons.credit_card_outlined,
      () => AccountsPage(session: widget.session),
    ),
    _NavItem(
      'المحافظ وInstaPay',
      Icons.wallet_outlined,
      () => WalletsPage(session: widget.session),
    ),
    _NavItem(
      'ماكينات شحن الرصيد',
      Icons.point_of_sale_outlined,
      () => MachinesPage(session: widget.session),
    ),
    _NavItem(
      'التحصيل والمعلّقات',
      Icons.pending_actions_outlined,
      () => CollectionsPage(session: widget.session),
    ),
    _NavItem(
      'سجل العمليات',
      Icons.receipt_long_outlined,
      () => LedgerPage(session: widget.session),
    ),
    if (widget.session.isAdmin)
      _NavItem(
        'الإدارة والصلاحيات',
        Icons.admin_panel_settings_outlined,
        () => AdminPage(session: widget.session),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: 260,
              child: ColoredBox(
                color: HesbaColors.navy,
                child: SafeArea(
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(24, 28, 24, 22),
                        child: Column(
                          children: [
                            Text(
                              'حِسبة',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'إدارة التحصيل والمدفوعات',
                              style: TextStyle(
                                color: Color(0xFFA8BBC5),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(
                        color: Color(0xFF2A4A59),
                        indent: 22,
                        endIndent: 22,
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final active = index == selected;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: ListTile(
                                selected: active,
                                selectedTileColor: HesbaColors.teal,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                leading: Icon(
                                  item.icon,
                                  color: active
                                      ? Colors.white
                                      : const Color(0xFFAFC0C9),
                                  size: 22,
                                ),
                                title: Text(
                                  item.label,
                                  style: TextStyle(
                                    color: active
                                        ? Colors.white
                                        : const Color(0xFFC4D0D6),
                                    fontWeight: active
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                onTap: () => setState(() => selected = index),
                              ),
                            );
                          },
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B4254),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: HesbaColors.teal,
                              foregroundColor: Colors.white,
                              child: Text(
                                widget.session.username![0].toUpperCase(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.session.username!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    widget.session.isAdmin
                                        ? 'مدير النظام'
                                        : 'مستخدم المحل',
                                    style: const TextStyle(
                                      color: Color(0xFFAFC0C9),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: widget.session.logout,
                              tooltip: 'تسجيل الخروج',
                              icon: const Icon(
                                Icons.logout_rounded,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 84,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Row(
                      children: [
                        const Text(
                          'الفرع الرئيسي  /  الإدارة المالية',
                          style: TextStyle(
                            color: HesbaColors.navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          DateFormat(
                            'EEEE، d MMMM yyyy',
                            'ar',
                          ).format(DateTime.now()),
                          style: const TextStyle(color: HesbaColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: KeyedSubtree(
                      key: ValueKey(selected),
                      child: items[selected].builder(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.builder);
  final String label;
  final IconData icon;
  final Widget Function() builder;
}

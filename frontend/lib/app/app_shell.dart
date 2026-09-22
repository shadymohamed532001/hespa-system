import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../core/theme/app_theme.dart';
import '../features/accounts/accounts_page.dart';
import '../features/admin/admin_page.dart';
import '../features/auth/session_controller.dart';
import '../features/collections/collections_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/ledger/ledger_page.dart';
import '../features/machines/machines_page.dart';
import '../features/top_up/top_up_page.dart';
import '../features/treasury/internal_transfer_page.dart';
import '../features/treasury/treasury_page.dart';
import '../features/wallets/wallets_page.dart';

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
      () => DashboardPage(
        session: widget.session,
        onOpenCollections: () => _selectLabel('تحصيلات المندوبين / Hold'),
        onOpenLedger: () => _selectLabel('سجل العمليات'),
      ),
    ),
    _NavItem(
      'الخزنة المركزية',
      () => TreasuryPage(
        session: widget.session,
        onOpenTransfer: () => _selectLabel('تحويل داخلي'),
      ),
    ),
    _NavItem('فوري والشركات', () => AccountsPage(session: widget.session)),
    if (widget.session.isAdmin)
      _NavItem('شحن حساب / محفظة', () => TopUpPage(session: widget.session)),
    _NavItem('المحافظ وInstaPay', () => WalletsPage(session: widget.session)),
    _NavItem('ماكينات شحن الرصيد', () => MachinesPage(session: widget.session)),
    _NavItem(
      'تحصيلات المندوبين / Hold',
      () => CollectionsPage(session: widget.session),
    ),
    if (widget.session.isAdmin)
      _NavItem(
        'تحويل داخلي',
        () => InternalTransferPage(session: widget.session),
      ),
    _NavItem(
      'توريد وتسوية شركة',
      () => CollectionsPage(session: widget.session),
    ),
    _NavItem('سجل العمليات', () => LedgerPage(session: widget.session)),
    if (widget.session.isAdmin)
      _NavItem(
        'المستخدمون والصلاحيات',
        () => AdminPage(session: widget.session),
      ),
  ];

  void _selectPage(int index) {
    if (index < 0 || index >= items.length) return;
    setState(() => selected = index);
  }

  void _selectLabel(String label) {
    final index = items.indexWhere((item) => item.label == label);
    _selectPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final sidebarWidth = constraints.maxWidth <= 1180 ? 245.0 : 300.0;

            return Row(
              children: [
                SizedBox(
                  width: sidebarWidth,
                  child: _Sidebar(
                    session: widget.session,
                    items: items,
                    selected: selected,
                    onSelected: _selectPage,
                  ),
                ),
                Expanded(
                  child: ColoredBox(
                    color: HesbaColors.soft,
                    child: Column(
                      children: [
                        _ContextBar(session: widget.session),
                        Expanded(
                          child: KeyedSubtree(
                            key: ValueKey(selected),
                            child: items[selected].builder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.session,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final SessionController session;
  final List<_NavItem> items;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: HesbaColors.navy,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 34, 22, 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 0, 8, 23),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('حِسبة', style: HesbaText.brand),
                    SizedBox(height: 5),
                    Text(
                      'إدارة التحصيل والمدفوعات',
                      style: HesbaText.brandSub,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0x1AFFFFFF)),
              const SizedBox(height: 21),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 5),
                  itemBuilder: (context, index) => _NavigationItem(
                    label: items[index].label,
                    active: index == selected,
                    onTap: () => onSelected(index),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _UserCard(session: session),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? HesbaColors.teal : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          height: 45,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                label,
                style: active ? HesbaText.navActive : HesbaText.nav,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.session});

  final SessionController session;

  @override
  Widget build(BuildContext context) {
    final role = session.isAdmin ? 'أدمن' : 'موظف محل';

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0x12FFFFFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('المستخدم الحالي', style: HesbaText.sideMeta),
          const SizedBox(height: 5),
          Text(
            '${session.username ?? '—'} — $role',
            style: HesbaText.sideUser,
          ),
          const SizedBox(height: 5),
          Text(
            session.isAdmin
                ? 'صلاحيات كاملة لإدارة النظام'
                : 'صلاحيات التشغيل اليومية',
            style: HesbaText.sideTiny,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: OutlinedButton(
              onPressed: session.logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xB8FFFFFF),
                side: const BorderSide(color: Color(0x29FFFFFF)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: HesbaText.button,
              ),
              child: const Text('تسجيل الخروج'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextBar extends StatelessWidget {
  const _ContextBar({required this.session});

  final SessionController session;

  @override
  Widget build(BuildContext context) {
    final role = session.isAdmin ? 'مدير النظام' : 'موظف المحل';

    return Container(
      height: 92,
      padding: const EdgeInsets.symmetric(horizontal: 42),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE9EEF2))),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'الفرع الرئيسي  /  الإدارة المالية',
              textAlign: TextAlign.right,
              style: HesbaText.contextStrong,
            ),
          ),
          Expanded(
            child: Text(
              DateFormat('EEEE، d MMMM y', 'ar').format(DateTime.now()),
              textAlign: TextAlign.center,
              style: HesbaText.bodyMuted,
            ),
          ),
          Expanded(
            child: Text(
              '${session.username ?? '—'}  ·  $role',
              textAlign: TextAlign.left,
              style: HesbaText.bodyMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.builder);

  final String label;
  final Widget Function() builder;
}

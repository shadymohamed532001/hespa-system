import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../core/settings/app_settings.dart';
import '../core/settings/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/header_icon_button.dart';
import '../core/widgets/notifications_bell.dart';
import '../features/accounts/accounts_page.dart';
import '../features/admin/admin_page.dart';
import '../features/auth/session_controller.dart';
import '../features/collections/collections_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/inventory/inventory_page.dart';
import '../features/ledger/ledger_page.dart';
import '../features/reports/reports_page.dart';
import '../features/top_up/top_up_page.dart';
import '../features/treasury/internal_transfer_page.dart';
import '../features/treasury/treasury_page.dart';
import '../features/wallets/wallets_page.dart';

/// Width at/under which the shell switches from persistent sidebar to drawer.
const double kHesbaMobileBreakpoint = 900;

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.session, required this.settings});

  final SessionController session;
  final AppSettings settings;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selected = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<_NavItem> _items(AppStrings t) => [
    _NavItem(
      t.dashboard,
      () => DashboardPage(
        session: widget.session,
        onOpenCollections: () => _selectLabel(t.collections),
        onOpenLedger: () => _selectLabel(t.ledger),
      ),
    ),
    _NavItem(
      t.treasury,
      () => TreasuryPage(
        session: widget.session,
        onOpenTransfer: () => _selectLabel(t.transfer),
      ),
    ),
    _NavItem(t.accounts, () => AccountsPage(session: widget.session)),
    if (widget.session.can(AppPermissions.topUpAssets))
      _NavItem(t.topUp, () => TopUpPage(session: widget.session)),
    _NavItem(
      t.wallets,
      () => WalletsPage(
        session: widget.session,
        onOpenLedger: () => _selectLabel(t.ledger),
      ),
    ),
    if (widget.session.can(AppPermissions.receiveCollections))
      _NavItem(t.collections, () => CollectionsPage(session: widget.session)),
    _NavItem(t.inventory, () => InventoryPage(session: widget.session)),
    if (widget.session.can(AppPermissions.internalTransfer))
      _NavItem(t.transfer, () => InternalTransferPage(session: widget.session)),
    if (widget.session.can(AppPermissions.receiveCollections))
      _NavItem(t.settlement, () => CollectionsPage(session: widget.session)),
    _NavItem(t.ledger, () => LedgerPage(session: widget.session)),
    if (widget.session.isAdmin)
      _NavItem(t.reports, () => ReportsPage(session: widget.session)),
    if (widget.session.can(AppPermissions.manageUsers))
      _NavItem(t.users, () => AdminPage(session: widget.session)),
  ];

  void _selectPage(int index, {bool closeDrawer = false}) {
    final items = _items(AppStrings.of(widget.settings.locale));
    if (index < 0 || index >= items.length) return;
    setState(() => selected = index);
    if (closeDrawer && _scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
    }
  }

  void _selectLabel(String label) {
    final items = _items(AppStrings.of(widget.settings.locale));
    final index = items.indexWhere((item) => item.label == label);
    _selectPage(index, closeDrawer: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(widget.settings.locale);
    final items = _items(t);
    final safeSelected = selected.clamp(0, items.length - 1);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final page = KeyedSubtree(
      key: ValueKey(
        '$safeSelected-${widget.settings.locale}-${isDark ? 'd' : 'l'}',
      ),
      child: items[safeSelected].builder(),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < kHesbaMobileBreakpoint;

        if (isMobile) {
          return Scaffold(
            key: _scaffoldKey,
            drawer: Drawer(
              backgroundColor: HesbaColors.navy,
              child: _Sidebar(
                session: widget.session,
                strings: t,
                items: items,
                selected: safeSelected,
                onSelected: (index) => _selectPage(index, closeDrawer: true),
              ),
            ),
            body: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                children: [
                  _ContextBar(
                    session: widget.session,
                    settings: widget.settings,
                    strings: t,
                    compact: true,
                    title: items[safeSelected].label,
                    onMenuPressed: () =>
                        _scaffoldKey.currentState?.openDrawer(),
                  ),
                  Expanded(child: page),
                ],
              ),
            ),
          );
        }

        final sidebarWidth = constraints.maxWidth <= 1180 ? 245.0 : 300.0;
        return Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: sidebarWidth,
                child: _Sidebar(
                  session: widget.session,
                  strings: t,
                  items: items,
                  selected: safeSelected,
                  onSelected: _selectPage,
                ),
              ),
              Expanded(
                child: ColoredBox(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Column(
                    children: [
                      _ContextBar(
                        session: widget.session,
                        settings: widget.settings,
                        strings: t,
                      ),
                      Expanded(child: page),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.session,
    required this.strings,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  final SessionController session;
  final AppStrings strings;
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
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 23),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(strings.brand, style: HesbaText.brand),
                    const SizedBox(height: 5),
                    Text(strings.brandSub, style: HesbaText.brandSub),
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
              _UserCard(session: session, strings: strings),
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
              alignment: AlignmentDirectional.centerStart,
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
  const _UserCard({required this.session, required this.strings});

  final SessionController session;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final role = session.isAdmin ? strings.adminRole : strings.staffRole;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0x12FFFFFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(strings.currentUser, style: HesbaText.sideMeta),
          const SizedBox(height: 5),
          Text('${session.username ?? '—'} — $role', style: HesbaText.sideUser),
          const SizedBox(height: 5),
          Text(
            session.isAdmin ? strings.adminHint : strings.staffHint,
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
              child: Text(strings.logout),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextBar extends StatelessWidget {
  const _ContextBar({
    required this.session,
    required this.settings,
    required this.strings,
    this.compact = false,
    this.title,
    this.onMenuPressed,
  });

  final SessionController session;
  final AppSettings settings;
  final AppStrings strings;
  final bool compact;
  final String? title;
  final VoidCallback? onMenuPressed;

  @override
  Widget build(BuildContext context) {
    final role = session.isAdmin ? strings.adminTitle : strings.staffTitle;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).colorScheme.surface;
    final muted = isDark ? const Color(0xFF9AADB8) : HesbaColors.muted;
    final ink = isDark ? const Color(0xFFE6EEF2) : HesbaColors.ink;
    final border = isDark ? const Color(0xFF2A4050) : const Color(0xFFE9EEF2);
    final dateLocale = settings.locale.languageCode;
    final topInset = MediaQuery.paddingOf(context).top;

    if (compact) {
      return Container(
        padding: EdgeInsets.fromLTRB(8, topInset + 6, 12, 10),
        decoration: BoxDecoration(
          color: surface,
          border: Border(bottom: BorderSide(color: border)),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
              onPressed: onMenuPressed,
              icon: Icon(Icons.menu_rounded, color: ink),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title ?? strings.brand,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HesbaText.contextStrong.copyWith(color: ink),
                  ),
                  Text(
                    strings.branchPath,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HesbaText.bodyMuted.copyWith(
                      color: muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            HeaderIconButton(
              tooltip: strings.languageTooltip,
              onPressed: settings.toggleLocale,
              child: Text(
                settings.isArabic ? 'EN' : 'ع',
                style: TextStyle(
                  color: ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFamily: HesbaText.family,
                ),
              ),
            ),
            const SizedBox(width: 4),
            HeaderIconButton(
              tooltip: settings.isDark
                  ? strings.themeTooltipLight
                  : strings.themeTooltip,
              onPressed: settings.toggleTheme,
              icon: settings.isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
            const SizedBox(width: 4),
            NotificationsBell(session: session, strings: strings),
          ],
        ),
      );
    }

    return Container(
      height: 92,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              strings.branchPath,
              textAlign: TextAlign.start,
              style: HesbaText.contextStrong.copyWith(color: ink),
            ),
          ),
          Expanded(
            child: Text(
              DateFormat('EEEE، d MMMM y', dateLocale).format(DateTime.now()),
              textAlign: TextAlign.center,
              style: HesbaText.bodyMuted.copyWith(color: muted),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    '${session.username ?? '—'}  ·  $role',
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: HesbaText.bodyMuted.copyWith(color: muted),
                  ),
                ),
                const SizedBox(width: 14),
                HeaderIconButton(
                  tooltip: strings.languageTooltip,
                  onPressed: settings.toggleLocale,
                  child: Text(
                    settings.isArabic ? 'EN' : 'ع',
                    style: TextStyle(
                      color: ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontFamily: HesbaText.family,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                HeaderIconButton(
                  tooltip: settings.isDark
                      ? strings.themeTooltipLight
                      : strings.themeTooltip,
                  onPressed: settings.toggleTheme,
                  icon: settings.isDark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
                const SizedBox(width: 8),
                NotificationsBell(session: session, strings: strings),
              ],
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

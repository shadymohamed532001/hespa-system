import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../core/settings/app_flavor.dart';
import '../core/settings/app_settings.dart';
import '../core/settings/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/flavor_badge.dart';
import '../core/widgets/header_icon_button.dart';
import '../core/widgets/notifications_bell.dart';
import '../features/accounts/accounts_page.dart';
import '../features/admin/admin_page.dart';
import '../features/auth/session_controller.dart';
import '../features/collections/collections_page.dart';
import '../features/collections/agent_credits_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/inventory/inventory_page.dart';
import '../features/ledger/ledger_page.dart';
import '../features/reports/reports_page.dart';
import '../features/top_up/top_up_page.dart';
import '../features/treasury/internal_transfer_page.dart';
import '../features/treasury/treasury_page.dart';
import '../features/purchase_visas/purchase_visas_page.dart';
import '../features/wallets/wallets_page.dart';

/// Width at/under which the top bar switches to its compact layout.
const double kHesbaCompactBreakpoint = 760;

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.session, required this.settings});

  final SessionController session;
  final AppSettings settings;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// `null` is the home launcher. A value opens that section full screen.
  int? selected;

  List<_NavItem> _items(AppStrings t) => [
    _NavItem(
      t.dashboard,
      Icons.dashboard_outlined,
      () => DashboardPage(
        session: widget.session,
        onOpenCollections: () => _selectLabel(t.collections),
        onOpenLedger: () => _selectLabel(t.ledger),
      ),
    ),
    _NavItem(
      t.treasury,
      Icons.account_balance_outlined,
      () => TreasuryPage(
        session: widget.session,
        onOpenTransfer: () => _selectLabel(t.transfer),
      ),
    ),
    _NavItem(
      t.fawryAccounts,
      Icons.payments_outlined,
      () => AccountsPage(session: widget.session, kind: 'fawry'),
    ),
    _NavItem(
      t.profitAccounts,
      Icons.trending_up,
      () => AccountsPage(session: widget.session, kind: 'profit'),
    ),
    _NavItem(
      t.profitQrAccounts,
      Icons.qr_code_2,
      () => AccountsPage(session: widget.session, kind: 'profit_qr'),
    ),
    if (widget.session.can(AppPermissions.topUpAssets))
      _NavItem(
        t.topUp,
        Icons.bolt_outlined,
        () => TopUpPage(session: widget.session),
      ),
    _NavItem(
      t.wallets,
      Icons.account_balance_wallet_outlined,
      () => WalletsPage(
        session: widget.session,
        onOpenLedger: () => _selectLabel(t.ledger),
      ),
    ),
    _NavItem(
      t.purchaseVisas,
      Icons.credit_card_outlined,
      () => PurchaseVisasPage(session: widget.session),
    ),
    if (widget.session.can(AppPermissions.receiveCollections))
      _NavItem(
        t.collections,
        Icons.receipt_long_outlined,
        () => CollectionsPage(session: widget.session),
      ),
    if (widget.session.can(AppPermissions.receiveCollections))
      _NavItem(
        t.agentCredits,
        Icons.schedule_outlined,
        () => AgentCreditsPage(session: widget.session),
      ),
    _NavItem(
      t.inventory,
      Icons.inventory_2_outlined,
      () => InventoryPage(session: widget.session),
    ),
    if (widget.session.can(AppPermissions.internalTransfer))
      _NavItem(
        t.transfer,
        Icons.swap_horiz,
        () => InternalTransferPage(session: widget.session),
      ),
    _NavItem(
      t.ledger,
      Icons.history,
      () => LedgerPage(session: widget.session),
    ),
    if (widget.session.can(AppPermissions.viewBalances))
      _NavItem(
        t.reports,
        Icons.bar_chart_outlined,
        () => ReportsPage(session: widget.session),
      ),
    if (widget.session.can(AppPermissions.manageUsers))
      _NavItem(
        t.users,
        Icons.people_outline,
        () => AdminPage(session: widget.session),
      ),
  ];

  void _openPage(int index) {
    final items = _items(AppStrings.of(widget.settings.locale));
    if (index < 0 || index >= items.length) return;
    setState(() => selected = index);
  }

  void _goHome() => setState(() => selected = null);

  void _selectLabel(String label) {
    final items = _items(AppStrings.of(widget.settings.locale));
    final index = items.indexWhere((item) => item.label == label);
    if (index >= 0) _openPage(index);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppStrings.of(widget.settings.locale);
    final items = _items(t);
    final safeSelected = selected != null && selected! < items.length
        ? selected
        : null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onHome = safeSelected == null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < kHesbaCompactBreakpoint;
        final page = onHome
            ? _HomeLauncher(
                session: widget.session,
                strings: t,
                items: items,
                onOpen: _openPage,
              )
            : KeyedSubtree(
                key: ValueKey(
                  '$safeSelected-${widget.settings.locale}-${isDark ? 'd' : 'l'}',
                ),
                child: items[safeSelected].builder(),
              );

        return Scaffold(
          body: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Column(
              children: [
                _ContextBar(
                  session: widget.session,
                  settings: widget.settings,
                  strings: t,
                  compact: compact,
                  title: onHome ? t.brand : items[safeSelected].label,
                  onBack: onHome ? null : _goHome,
                ),
                Expanded(child: page),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeLauncher extends StatelessWidget {
  const _HomeLauncher({
    required this.session,
    required this.strings,
    required this.items,
    required this.onOpen,
  });

  final SessionController session;
  final AppStrings strings;
  final List<_NavItem> items;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? const Color(0xFFE6EEF2) : HesbaColors.ink;
    final muted = isDark ? const Color(0xFF9AADB8) : HesbaColors.muted;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final pad = width < 600 ? 16.0 : 36.0;
        final columns = width >= 1280
            ? 5
            : width >= 980
            ? 4
            : width >= 680
            ? 3
            : 2;

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 32, pad, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.brand,
                      style: HesbaText.pageTitle.copyWith(
                        color: ink,
                        fontSize: width < 600 ? 32 : 38,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      strings.homeSubtitle,
                      style: HesbaText.bodyMuted.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 28, pad, 0),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _ModuleTile(
                    label: items[index].label,
                    icon: items[index].icon,
                    onTap: () => onOpen(index),
                  ),
                  childCount: items.length,
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 28, pad, 40),
              sliver: SliverToBoxAdapter(
                child: _HomeUserCard(session: session, strings: strings),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? const Color(0xFF152833) : Colors.white;
    final border = isDark ? const Color(0xFF2A4050) : HesbaColors.border;
    final ink = isDark ? const Color(0xFFE6EEF2) : HesbaColors.ink;
    final iconBg = isDark ? const Color(0xFF163E3A) : HesbaColors.tealLight;

    return Material(
      color: card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        hoverColor: HesbaColors.teal.withValues(alpha: 0.06),
        splashColor: HesbaColors.teal.withValues(alpha: 0.12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: HesbaColors.teal, size: 26),
                ),
                const SizedBox(height: 14),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: HesbaText.fieldLabel.copyWith(
                    color: ink,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeUserCard extends StatelessWidget {
  const _HomeUserCard({required this.session, required this.strings});

  final SessionController session;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? const Color(0xFF152833) : Colors.white;
    final border = isDark ? const Color(0xFF2A4050) : HesbaColors.border;
    final ink = isDark ? const Color(0xFFE6EEF2) : HesbaColors.ink;
    final muted = isDark ? const Color(0xFF9AADB8) : HesbaColors.muted;
    final role = session.isAdmin ? strings.adminRole : strings.staffRole;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.currentUser,
                  style: HesbaText.caption.copyWith(color: muted),
                ),
                const SizedBox(height: 4),
                Text(
                  '${session.username ?? '—'} — $role',
                  style: HesbaText.fieldLabel.copyWith(color: ink),
                ),
                const SizedBox(height: 2),
                Text(
                  session.isAdmin ? strings.adminHint : strings.staffHint,
                  style: HesbaText.help.copyWith(color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton(
            onPressed: session.logout,
            child: Text(strings.logout),
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
    this.onBack,
  });

  final SessionController session;
  final AppSettings settings;
  final AppStrings strings;
  final bool compact;
  final String? title;
  final VoidCallback? onBack;

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

    final backButton = onBack == null
        ? null
        : HeaderIconButton(
            tooltip: strings.backHome,
            onPressed: onBack!,
            icon: Icons.arrow_back,
          );
    final logoutButton = HeaderIconButton(
      tooltip: strings.logout,
      onPressed: session.logout,
      icon: Icons.logout_rounded,
    );

    if (compact) {
      return Container(
        padding: EdgeInsets.fromLTRB(12, topInset + 6, 12, 10),
        decoration: BoxDecoration(
          color: surface,
          border: Border(bottom: BorderSide(color: border)),
        ),
        child: Row(
          children: [
            if (backButton != null) ...[backButton, const SizedBox(width: 8)],
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
            const SizedBox(width: 4),
            logoutButton,
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
          if (backButton != null) ...[backButton, const SizedBox(width: 14)],
          Expanded(
            child: Text(
              strings.branchPath,
              textAlign: TextAlign.start,
              style: HesbaText.contextStrong.copyWith(color: ink),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!isProductionFlavor) ...[
                  const FlavorBadge(),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(
                    DateFormat(
                      'EEEE، d MMMM y',
                      dateLocale,
                    ).format(DateTime.now()),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: HesbaText.bodyMuted.copyWith(color: muted),
                  ),
                ),
              ],
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
                const SizedBox(width: 8),
                logoutButton,
              ],
            ),
          ),
        ],
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

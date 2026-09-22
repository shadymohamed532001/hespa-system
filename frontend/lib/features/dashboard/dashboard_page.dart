import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/widgets/error_box.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/metric_card.dart';
import '../../core/widgets/notifications_bell.dart';
import '../../core/widgets/page_frame.dart';
import '../auth/session_controller.dart';
import '../collections/receive_collection_dialog.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.session,
    required this.onOpenCollections,
    required this.onOpenLedger,
  });

  final SessionController session;
  final VoidCallback onOpenCollections;
  final VoidCallback onOpenLedger;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool loading = true;
  String? error;
  Map<String, dynamic> treasury = {};
  List<dynamic> accounts = [];
  List<dynamic> wallets = [];
  List<dynamic> machines = [];
  List<dynamic> collections = [];
  List<dynamic> ledger = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final values = await Future.wait([
        widget.session.api.getMap(ApiEndpoints.treasurySummary),
        widget.session.api.list(ApiEndpoints.accounts),
        widget.session.api.list(ApiEndpoints.wallets),
        widget.session.api.list(ApiEndpoints.machines),
        widget.session.api.list(ApiEndpoints.collections),
        widget.session.api.list(ApiEndpoints.ledgerList(limit: 6)),
      ]);

      treasury = values[0] as Map<String, dynamic>;
      accounts = values[1] as List<dynamic>;
      wallets = values[2] as List<dynamic>;
      machines = values[3] as List<dynamic>;
      collections = values[4] as List<dynamic>;
      ledger = values[5] as List<dynamic>;
    } catch (exception) {
      error = ApiClient.errorMessage(exception);
    }

    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'لوحة المتابعة',
      subtitle: 'ملخص الأرصدة والحركات الحالية',
      actions: [
        NotificationsBell(session: widget.session),
        FilledButton(onPressed: _receive, child: const Text('استلام من مندوب')),
      ],
      child: loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(80),
                child: CircularProgressIndicator(),
              ),
            )
          : error != null
          ? ErrorBox(message: error!, retry: load)
          : _DashboardContent(
              treasury: treasury,
              accounts: accounts,
              wallets: wallets,
              machines: machines,
              collections: collections,
              ledger: ledger,
              onOpenCollections: widget.onOpenCollections,
              onOpenLedger: widget.onOpenLedger,
            ),
    );
  }

  Future<void> _receive() async {
    final saved = await showReceiveCollectionDialog(
      context: context,
      session: widget.session,
    );
    if (saved) {
      await load();
      if (mounted) showAppSnack(context, 'تم تسجيل التحصيل');
    }
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.treasury,
    required this.accounts,
    required this.wallets,
    required this.machines,
    required this.collections,
    required this.ledger,
    required this.onOpenCollections,
    required this.onOpenLedger,
  });

  final Map<String, dynamic> treasury;
  final List<dynamic> accounts;
  final List<dynamic> wallets;
  final List<dynamic> machines;
  final List<dynamic> collections;
  final List<dynamic> ledger;
  final VoidCallback onOpenCollections;
  final VoidCallback onOpenLedger;

  @override
  Widget build(BuildContext context) {
    final pending = collections
        .where((entry) => entry['status'] == 'pending')
        .toList();
    final assets = _assets();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columnCount = constraints.maxWidth < 950 ? 2 : 4;

            return GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columnCount,
                mainAxisSpacing: 15,
                crossAxisSpacing: 15,
                mainAxisExtent: 150,
              ),
              children: [
                MetricCard(
                  label: 'رصيد الخزنة الفعلي',
                  value: money(treasury['actualBalance']),
                  note: 'الكاش الموجود حاليًا',
                ),
                MetricCard(
                  label: 'محجوز للمعلّقات',
                  value: money(treasury['pendingAmount']),
                  note: '${pending.length} عملية لم تُنفذ',
                  warning: true,
                ),
                MetricCard(
                  label: 'المتاح للتصرف',
                  value: money(treasury['availableBalance']),
                  note: 'بعد خصم الالتزامات المعلّقة',
                  accent: true,
                ),
                MetricCard(
                  label: 'إجمالي العمولات',
                  value: money(_commissionTotal()),
                  note: 'مسجلة منفصلة عن أصل المبالغ',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final ledgerPanel = _LedgerPanel(
              ledger: ledger,
              onOpenLedger: onOpenLedger,
            );
            final sidePanels = Column(
              children: [
                _AssetsPanel(assets: assets),
                const SizedBox(height: 16),
                _PendingPanel(
                  collection: pending.isEmpty
                      ? null
                      : pending.first as Map<String, dynamic>,
                  onOpenCollections: onOpenCollections,
                ),
              ],
            );

            if (constraints.maxWidth < 1080) {
              return Column(
                children: [ledgerPanel, const SizedBox(height: 16), sidePanels],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 145, child: ledgerPanel),
                const SizedBox(width: 16),
                Expanded(flex: 75, child: sidePanels),
              ],
            );
          },
        ),
      ],
    );
  }

  num _commissionTotal() {
    num total = 0;
    for (final item in [...accounts, ...wallets, ...machines]) {
      total += _number(item['commissionBalance']);
    }
    return total;
  }

  List<_Asset> _assets() {
    return [
      ...accounts
          .where((item) => item['active'] != false)
          .map(
            (item) => _Asset(
              name: '${item['name']}',
              kind: _accountType('${item['type']}'),
              balance: _number(item['balance']),
            ),
          ),
      ...wallets.map(
        (item) => _Asset(
          name: '${item['name']}',
          kind: item['type'] == 'instapay' ? 'InstaPay' : 'محفظة إلكترونية',
          balance: _number(item['balance']),
        ),
      ),
      ...machines
          .where((item) => item['active'] != false)
          .map(
            (item) => _Asset(
              name: '${item['name']}',
              kind: 'ماكينة شحن',
              balance: _number(item['remainingBalance']),
            ),
          ),
    ];
  }
}

class _LedgerPanel extends StatelessWidget {
  const _LedgerPanel({required this.ledger, required this.onOpenLedger});

  final List<dynamic> ledger;
  final VoidCallback onOpenLedger;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PanelHeader(
            title: 'آخر الحركات',
            subtitle: 'الحركة وتصنيف أثرها على الأموال',
            action: OutlinedButton(
              onPressed: onOpenLedger,
              child: const Text('عرض الكل'),
            ),
          ),
          if (ledger.isEmpty)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Text(
                'لا توجد حركات مسجلة بعد',
                textAlign: TextAlign.center,
                style: TextStyle(color: HesbaColors.muted),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      const Color(0xFFF2F5F8),
                    ),
                    headingRowHeight: 54,
                    dataRowMinHeight: 62,
                    dataRowMaxHeight: 62,
                    horizontalMargin: 20,
                    columnSpacing: 30,
                    columns: const [
                      DataColumn(label: Text('الوقت')),
                      DataColumn(label: Text('الحركة')),
                      DataColumn(label: Text('البيان')),
                      DataColumn(label: Text('المبلغ')),
                      DataColumn(label: Text('التصنيف')),
                      DataColumn(label: Text('الأثر')),
                    ],
                    rows: ledger
                        .take(5)
                        .map(
                          (entry) => _ledgerRow(entry as Map<String, dynamic>),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  DataRow _ledgerRow(Map<String, dynamic> entry) {
    final category = '${entry['category']}';
    final amount = _number(entry['amount']);
    final negative = _isNegative(category);
    final sign = negative ? '−' : '+';
    final amountColor = negative ? HesbaColors.red : HesbaColors.tealDark;

    return DataRow(
      cells: [
        DataCell(Text(_time(entry['createdAt']))),
        DataCell(
          Text(
            _categoryName(category),
            style: const TextStyle(
              color: HesbaColors.ink,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        DataCell(Text(entry['reference'] ?? entry['entityType'] ?? '—')),
        DataCell(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '$sign${money(amount.abs())}',
              style: TextStyle(color: amountColor, fontWeight: FontWeight.w400),
            ),
          ),
        ),
        DataCell(_CategoryBadge(category: category)),
        DataCell(Text(_categoryEffect(category))),
      ],
    );
  }
}

class _AssetsPanel extends StatelessWidget {
  const _AssetsPanel({required this.assets});

  final List<_Asset> assets;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeader(title: 'أرصدة التشغيل', subtitle: 'كل أصل مستقل'),
          if (assets.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'لا توجد أصول تشغيل',
                textAlign: TextAlign.center,
                style: TextStyle(color: HesbaColors.muted),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 5, 20, 11),
              child: Column(
                children: assets
                    .map(
                      (asset) => _AssetRow(
                        asset: asset,
                        showDivider: asset != assets.last,
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _AssetRow extends StatelessWidget {
  const _AssetRow({required this.asset, required this.showDivider});

  final _Asset asset;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: Color(0xFFEDF1F3)))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.name,
                  style: const TextStyle(
                    color: HesbaColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  asset.kind,
                  style: const TextStyle(
                    color: HesbaColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              money(asset.balance),
              style: const TextStyle(
                color: HesbaColors.ink,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingPanel extends StatelessWidget {
  const _PendingPanel({
    required this.collection,
    required this.onOpenCollections,
  });

  final Map<String, dynamic>? collection;
  final VoidCallback onOpenCollections;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _PanelHeader(
            title: 'معلّق يحتاج تنفيذ',
            subtitle: 'الكاش موجود لكن عليه التزام',
          ),
          if (collection == null)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'لا توجد معلّقات حالية',
                textAlign: TextAlign.center,
                style: TextStyle(color: HesbaColors.muted),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      money(collection!['amount']),
                      style: const TextStyle(
                        color: HesbaColors.ink,
                        fontSize: 24,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${collection!['agentName']} · ${collection!['companyName']} · ${_time(collection!['receivedAt'])}',
                    style: const TextStyle(
                      color: HesbaColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: onOpenCollections,
                    child: const Text('تنفيذ العملية'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HesbaColors.border),
      ),
      child: child,
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE9EEF2))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: HesbaText.sectionTitle,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: HesbaColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final hold = category == 'cash_receipt';
    final internal = category == 'internal_transfer' || category == 'top_up';

    final background = hold
        ? HesbaColors.warningLight
        : internal
        ? const Color(0xFFE9EEF6)
        : HesbaColors.tealLight;
    final foreground = hold
        ? HesbaColors.warning
        : internal
        ? const Color(0xFF50657D)
        : HesbaColors.tealSoft;

    return Container(
      constraints: const BoxConstraints(minWidth: 76),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        hold
            ? 'معلّق'
            : internal
            ? category == 'top_up'
                  ? 'شحن مباشر'
                  : 'تحويل داخلي'
            : 'تشغيل',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _Asset {
  const _Asset({required this.name, required this.kind, required this.balance});

  final String name;
  final String kind;
  final num balance;
}

num _number(dynamic value) => num.tryParse('$value') ?? 0;

String _accountType(String value) {
  return {'fawry': 'فوري', 'company': 'شركة', 'operating': 'تشغيلي'}[value] ??
      value;
}

bool _isNegative(String category) {
  return const {
    'internal_transfer',
    'company_execution',
    'machine_usage',
  }.contains(category);
}

String _categoryName(String category) {
  return {
        'opening_balance': 'رصيد افتتاحي',
        'top_up': 'شحن مباشر',
        'internal_transfer': 'تحويل داخلي',
        'cash_receipt': 'استلام كاش من مندوب',
        'company_execution': 'توريد وتسوية شركة',
        'commission': 'عمولة',
        'machine_usage': 'استخدام رصيد ماكينة',
        'daily_rollover': 'ترحيل يومي',
      }[category] ??
      category;
}

String _categoryEffect(String category) {
  return {
        'opening_balance': 'إثبات رصيد الأصل',
        'top_up': 'زيادة رصيد التشغيل',
        'internal_transfer': 'حركة بين الأصول',
        'cash_receipt': 'دخل الخزنة مع التزام',
        'company_execution': 'خفض رصيد حساب الشركة',
        'commission': 'إضافة عمولة مستقلة',
        'machine_usage': 'خفض رصيد الماكينة',
        'daily_rollover': 'ترحيل أرصدة اليوم',
      }[category] ??
      'حركة مالية';
}

String _time(dynamic value) {
  final parsed = DateTime.tryParse('$value')?.toLocal();
  return parsed == null ? '—' : DateFormat('hh:mm a', 'ar').format(parsed);
}

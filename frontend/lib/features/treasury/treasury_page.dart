import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/widgets/error_box.dart';
import '../../core/widgets/metric_card.dart';
import '../../core/widgets/page_frame.dart';
import '../auth/session_controller.dart';

class TreasuryPage extends StatefulWidget {
  const TreasuryPage({
    super.key,
    required this.session,
    required this.onOpenTransfer,
  });

  final SessionController session;
  final VoidCallback onOpenTransfer;

  @override
  State<TreasuryPage> createState() => _TreasuryPageState();
}

class _TreasuryPageState extends State<TreasuryPage> {
  Map<String, dynamic> summary = {};
  List<dynamic> ledger = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final values = await Future.wait([
        widget.session.api.getMap(ApiEndpoints.treasurySummary),
        widget.session.api.list(ApiEndpoints.ledgerList(limit: 200)),
      ]);
      summary = values[0] as Map<String, dynamic>;
      ledger = values[1] as List<dynamic>;
    } catch (exception) {
      error = ApiClient.errorMessage(exception);
    }

    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'الخزنة المركزية',
      subtitle: 'الرصيد الفعلي والمتاح والالتزامات',
      actions: widget.session.isAdmin
          ? [
              FilledButton(
                onPressed: widget.onOpenTransfer,
                child: const Text('تحويل داخلي'),
              ),
            ]
          : [],
      child: loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(80),
                child: CircularProgressIndicator(),
              ),
            )
          : error != null
          ? ErrorBox(message: error!, retry: load)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SummaryGrid(
                  summary: summary,
                  todayMovements: _todayLedger.length,
                ),
                const SizedBox(height: 20),
                const _AccountingRule(),
                const SizedBox(height: 20),
                _TreasuryMovements(entries: ledger.take(8).toList()),
              ],
            ),
    );
  }

  List<dynamic> get _todayLedger {
    final now = DateTime.now();
    return ledger.where((entry) {
      final value = DateTime.tryParse('${entry['createdAt']}')?.toLocal();
      return value != null &&
          value.year == now.year &&
          value.month == now.month &&
          value.day == now.day;
    }).toList();
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary, required this.todayMovements});

  final Map<String, dynamic> summary;
  final int todayMovements;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth < 700
            ? 1
            : constraints.maxWidth < 1050
            ? 2
            : 4;
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            mainAxisSpacing: 15,
            crossAxisSpacing: 15,
            mainAxisExtent: 150,
          ),
          children: [
            MetricCard(
              label: 'الرصيد الفعلي',
              value: money(summary['actualBalance']),
              note: 'النقد الموجود في الخزنة',
            ),
            MetricCard(
              label: 'التزامات معلّقة',
              value: money(summary['pendingAmount']),
              note: 'أموال ليست حرة للتصرف',
              warning: true,
            ),
            MetricCard(
              label: 'الرصيد المتاح',
              value: money(summary['availableBalance']),
              note: 'الفعلي ناقص المعلّقات',
              accent: true,
            ),
            MetricCard(
              label: 'عدد حركات اليوم',
              value: '$todayMovements',
              note: 'تشمل التحويلات الداخلية',
            ),
          ],
        );
      },
    );
  }
}

class _AccountingRule extends StatelessWidget {
  const _AccountingRule();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF4F7),
        borderRadius: BorderRadius.circular(11),
      ),
      child: const Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'قاعدة محاسبية: ',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text:
                  'نقل مبلغ من الخزنة إلى حساب فوري أو محفظة أو ماكينة هو تحويل بين أصول المحل، وليس مصروفًا أو خسارة.',
            ),
          ],
        ),
        style: TextStyle(color: Color(0xFF425C6B), fontSize: 13, height: 1.55),
      ),
    );
  }
}

class _TreasuryMovements extends StatelessWidget {
  const _TreasuryMovements({required this.entries});

  final List<dynamic> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: HesbaColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'حركات الخزنة',
                  style: TextStyle(
                    color: HesbaColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'مع توضيح نوع وأثر كل حركة',
                  style: TextStyle(color: HesbaColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(38),
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
                    dataRowMinHeight: 58,
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
                    rows: entries
                        .map((entry) => _row(entry as Map<String, dynamic>))
                        .toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  DataRow _row(Map<String, dynamic> entry) {
    final category = '${entry['category']}';
    final rawAmount = num.tryParse('${entry['amount']}') ?? 0;
    final negative = rawAmount < 0 || _isOutflow(entry);
    final sign = rawAmount == 0
        ? ''
        : negative
        ? '−'
        : '+';
    final color = rawAmount == 0
        ? HesbaColors.muted
        : negative
        ? HesbaColors.red
        : HesbaColors.tealDark;

    return DataRow(
      cells: [
        DataCell(Text(_time(entry['createdAt']))),
        DataCell(
          Text(
            _categoryName(category),
            style: const TextStyle(
              color: HesbaColors.ink,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        DataCell(Text(entry['reference'] ?? entry['description'] ?? '—')),
        DataCell(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '$sign${money(rawAmount.abs())}',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        DataCell(_MovementBadge(entry: entry)),
        DataCell(Text(_effect(entry))),
      ],
    );
  }

  bool _isOutflow(Map<String, dynamic> entry) {
    final category = '${entry['category']}';
    if (category == 'internal_transfer') {
      return '${entry['description']}'.contains('من الخزنة المركزية');
    }
    return category == 'company_execution' ||
        category == 'machine_usage' ||
        category == 'top_up';
  }

  String _time(dynamic value) {
    final date = DateTime.tryParse('$value')?.toLocal();
    return date == null ? '—' : DateFormat('hh:mm a', 'ar').format(date);
  }

  String _categoryName(String category) => switch (category) {
    'cash_receipt' => 'استلام كاش من مندوب',
    'internal_transfer' => 'تحويل داخلي',
    'top_up' => 'شحن رصيد',
    'machine_usage' => 'استخدام رصيد ماكينة',
    'company_execution' => 'توريد وتسوية شركة',
    'commission' => 'عمولة',
    'daily_rollover' => 'ترحيل يومي',
    'opening_balance' => 'رصيد افتتاحي',
    'reversal' => 'عكس حركة',
    _ => category,
  };

  String _effect(Map<String, dynamic> entry) {
    final category = '${entry['category']}';
    return switch (category) {
      'cash_receipt' =>
        '${entry['reference']}'.startsWith('HLD-')
            ? 'دخل الخزنة مع التزام معلّق'
            : 'دخل الكاش الخزنة',
      'internal_transfer' => 'حركة بين الأصول',
      'top_up' => 'زيادة رصيد أصل تشغيلي',
      'machine_usage' => 'خفض رصيد الماكينة',
      'company_execution' => 'خفض رصيد حساب الشركة',
      'commission' => 'إضافة عمولة مستقلة',
      'daily_rollover' => 'ترحيل أرصدة اليوم',
      'opening_balance' => 'إثبات رصيد افتتاحي',
      'reversal' => 'عكس أثر حركة سابقة',
      _ => '${entry['description'] ?? '—'}',
    };
  }
}

class _MovementBadge extends StatelessWidget {
  const _MovementBadge({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final category = '${entry['category']}';
    final hold =
        category == 'cash_receipt' &&
        '${entry['reference']}'.startsWith('HLD-');
    final internal = category == 'internal_transfer';
    final background = hold
        ? HesbaColors.warningLight
        : internal
        ? const Color(0xFFE9EEF6)
        : HesbaColors.tealLight;
    final foreground = hold
        ? HesbaColors.warning
        : internal
        ? const Color(0xFF50657D)
        : const Color(0xFF287E75);
    final label = hold
        ? 'معلّق'
        : internal
        ? 'تحويل داخلي'
        : 'تشغيل';

    return Container(
      constraints: const BoxConstraints(minWidth: 76),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

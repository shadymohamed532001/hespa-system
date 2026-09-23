import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/datetime_formatter.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/widgets/data_card.dart';
import '../../core/widgets/error_box.dart';
import '../../core/widgets/metric_card.dart';
import '../../core/widgets/page_frame.dart';
import '../auth/session_controller.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, required this.session});

  final SessionController session;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late DateTime from;
  late DateTime to;
  bool loading = true;
  String? error;
  Map<String, dynamic> report = {};
  List<Map<String, dynamic>> availableChannels = [];
  String selectedScope = 'all';

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    from = today.subtract(const Duration(days: 6));
    to = today;
    load();
  }

  Future<void> load({bool preserveChannels = true}) async {
    setState(() {
      loading = true;
      error = null;
    });

    final parts = selectedScope.split(':');
    final type = parts.first;
    final id = parts.length > 1 ? parts.sublist(1).join(':') : null;

    try {
      report = await widget.session.api.getMap(
        ApiEndpoints.reportsSummary(
          from: from,
          toExclusive: to.add(const Duration(days: 1)),
          entityType: type,
          entityId: id,
        ),
      );
      if (selectedScope == 'all' || !preserveChannels) {
        availableChannels = _maps(report['channels']);
      }
    } catch (exception) {
      error = ApiClient.errorMessage(exception);
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> _pickPeriod() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: from, end: to),
      helpText: 'اختر فترة التقرير',
      saveText: 'تطبيق',
      cancelText: 'إلغاء',
    );
    if (picked == null) return;
    from = DateUtils.dateOnly(picked.start);
    to = DateUtils.dateOnly(picked.end);
    await load();
  }

  Future<void> _quickPeriod(int days) async {
    final today = DateUtils.dateOnly(DateTime.now());
    to = today;
    from = today.subtract(Duration(days: days - 1));
    await load();
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'التقارير الشاملة',
      subtitle: 'تحليل السحب والإيداع والمبيعات والتحصيلات لكل جزء في النظام',
      actions: [
        IconButton.filledTonal(
          tooltip: 'تحديث التقرير',
          onPressed: loading ? null : load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FiltersCard(
            from: from,
            to: to,
            selectedScope: selectedScope,
            channels: availableChannels,
            onPickPeriod: _pickPeriod,
            onQuickPeriod: _quickPeriod,
            onScopeChanged: (value) async {
              if (value == null) return;
              setState(() => selectedScope = value);
              await load();
            },
          ),
          const SizedBox(height: 18),
          if (loading)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(72),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (error != null)
            ErrorBox(message: error!, retry: load)
          else
            _ReportContent(report: report),
        ],
      ),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({
    required this.from,
    required this.to,
    required this.selectedScope,
    required this.channels,
    required this.onPickPeriod,
    required this.onQuickPeriod,
    required this.onScopeChanged,
  });

  final DateTime from;
  final DateTime to;
  final String selectedScope;
  final List<Map<String, dynamic>> channels;
  final VoidCallback onPickPeriod;
  final ValueChanged<int> onQuickPeriod;
  final ValueChanged<String?> onScopeChanged;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd/MM/yyyy');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final dateFieldWidth = constraints.maxWidth < 300
                ? constraints.maxWidth
                : 300.0;
            final scopeFieldWidth = constraints.maxWidth < 270
                ? constraints.maxWidth
                : 270.0;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: dateFieldWidth,
                  child: OutlinedButton.icon(
                    onPressed: onPickPeriod,
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(
                      '${formatter.format(from)} — ${formatter.format(to)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                SizedBox(
                  width: scopeFieldWidth,
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedScope,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'القسم / الحساب',
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text(
                          'كل النظام',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...channels.map(
                        (channel) => DropdownMenuItem(
                          value:
                              '${channel['entityType']}:${channel['entityId']}',
                          child: Text(
                            '${channel['name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: onScopeChanged,
                  ),
                ),
                _QuickButton(label: 'اليوم', onTap: () => onQuickPeriod(1)),
                _QuickButton(label: '7 أيام', onTap: () => onQuickPeriod(7)),
                _QuickButton(label: '30 يوم', onTap: () => onQuickPeriod(30)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
    label: Text(label),
    onPressed: onTap,
    side: const BorderSide(color: HesbaColors.border),
    backgroundColor: Colors.white,
  );
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({required this.report});

  final Map<String, dynamic> report;

  @override
  Widget build(BuildContext context) {
    final summary = _map(report['summary']);
    final inventory = _map(report['inventory']);
    final channels = _maps(report['channels']);
    final daily = _maps(report['daily']);
    final operations = _maps(report['operations']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final count = constraints.maxWidth < 760
                ? 2
                : constraints.maxWidth < 1180
                ? 3
                : 4;
            return GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: count,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                mainAxisExtent: 145,
              ),
              children: [
                MetricCard(
                  label: 'إجمالي الإيداعات',
                  value: money(summary['deposits']),
                  note: 'كل الأموال الداخلة خلال الفترة',
                  accent: true,
                ),
                MetricCard(
                  label: 'إجمالي السحب والاستخدام',
                  value: money(summary['withdrawals']),
                  note: 'كل الأموال الخارجة خلال الفترة',
                  warning: true,
                ),
                MetricCard(
                  label: 'صافي الحركة',
                  value: money(summary['net']),
                  note: 'الإيداعات ناقص السحب',
                ),
                MetricCard(
                  label: 'العمولات',
                  value: money(summary['commissions']),
                  note: 'مسجلة منفصلة عن أصل المبالغ',
                ),
                MetricCard(
                  label: 'مبيعات المخزن',
                  value: money(summary['salesAmount']),
                  note:
                      '${summary['salesCount'] ?? 0} فاتورة · ${summary['soldUnits'] ?? 0} قطعة',
                ),
                MetricCard(
                  label: 'تحصيلات المندوبين',
                  value: money(summary['collectionsAmount']),
                  note:
                      '${summary['collectionsCount'] ?? 0} عملية · ${summary['pendingCollectionsCount'] ?? 0} معلّقة',
                ),
                MetricCard(
                  label: 'عدد الحركات',
                  value: '${summary['operationCount'] ?? 0}',
                  note: 'كل الحركات المسجلة في الفترة',
                ),
                MetricCard(
                  label: 'قيمة المخزون الحالية',
                  value: money(inventory['stockValue']),
                  note: '${inventory['stockUnits'] ?? 0} وحدة متاحة حاليًا',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        _SectionTitle(
          title: 'تفصيل كل حساب وقسم',
          subtitle: 'الرصيد الحالي وحركة الإيداع والسحب داخل الفترة المختارة',
        ),
        const SizedBox(height: 10),
        DataCard(
          columns: const [
            'القسم / الحساب',
            'النوع',
            'الرصيد الحالي',
            'إيداعات',
            'سحب / استخدام',
            'عمولات',
            'صافي الحركة',
            'الحركات',
          ],
          rows: channels
              .map(
                (row) => <Object>[
                  row['name'] ?? '—',
                  _channelKind('${row['kind']}'),
                  money(row['currentBalance']),
                  money(row['deposits']),
                  money(row['withdrawals']),
                  money(row['commissions']),
                  money(row['net']),
                  '${row['operationCount'] ?? 0}',
                ],
              )
              .toList(),
        ),
        const SizedBox(height: 22),
        _SectionTitle(
          title: 'الملخص اليومي',
          subtitle:
              'تجميع الحركة يومًا بيوم لمعرفة حجم السحب والإيداع والمبيعات',
        ),
        const SizedBox(height: 10),
        DataCard(
          columns: const [
            'اليوم',
            'الإيداعات',
            'السحب / الاستخدام',
            'صافي الحركة',
            'المبيعات',
            'العمولات',
            'عدد الحركات',
          ],
          rows: daily
              .map(
                (row) => <Object>[
                  _shortDate(row['date']),
                  money(row['deposits']),
                  money(row['withdrawals']),
                  money(row['net']),
                  money(row['sales']),
                  money(row['commissions']),
                  '${row['operationCount'] ?? 0}',
                ],
              )
              .toList(),
        ),
        const SizedBox(height: 22),
        _SectionTitle(
          title: 'تفاصيل الحركات',
          subtitle: report['truncated'] == true
              ? 'أحدث 500 حركة في الفترة — ضيّق الفترة لعرض باقي التفاصيل'
              : 'كل حركة مع مصدرها وتاريخها والمستخدم الذي سجلها',
        ),
        const SizedBox(height: 10),
        if (operations.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(38),
              child: Text(
                'لا توجد حركات في الفترة المختارة',
                textAlign: TextAlign.center,
                style: HesbaText.bodyMuted,
              ),
            ),
          )
        else
          DataCard(
            columns: const [
              'التاريخ والوقت',
              'الحركة',
              'القسم / الحساب',
              'البيان',
              'المبلغ',
              'المرجع',
              'المستخدم',
            ],
            rows: operations
                .map(
                  (row) => <Object>[
                    _dateTime(row['createdAt']),
                    _flowKind('${row['kind']}'),
                    row['entityName'] ?? '—',
                    row['description'] ?? '—',
                    money(row['amount']),
                    row['reference'] ?? '—',
                    row['performedBy'] ?? '—',
                  ],
                )
                .toList(),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: HesbaText.sectionTitle),
      const SizedBox(height: 3),
      Text(subtitle, style: HesbaText.panelSub),
    ],
  );
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _maps(dynamic value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
    : <Map<String, dynamic>>[];

String _dateTime(dynamic value) => formatDateTime(value);

String _shortDate(dynamic value) {
  final date = DateTime.tryParse('$value');
  return date == null ? '$value' : DateFormat('EEEE، dd/MM', 'ar').format(date);
}

String _channelKind(String value) =>
    {
      'cash': 'كاش',
      'fawry': 'فوري',
      'company': 'شركة',
      'operating': 'تشغيل',
      'wallet': 'محفظة',
      'vodafone_cash': 'Vodafone Cash',
      'orange_cash': 'Orange Cash',
      'etisalat_cash': 'e& cash',
      'we_pay': 'WE Pay',
      'other_wallet': 'محفظة أخرى',
      'instapay': 'InstaPay',
      'machine': 'ماكينة شحن',
      'inventory': 'مخزن',
    }[value] ??
    value;

String _flowKind(String value) =>
    {
      'deposit': 'إيداع',
      'withdrawal': 'سحب / استخدام',
      'commission': 'عمولة',
      'transfer': 'تحويل داخلي',
      'sale': 'بيع مخزن',
      'neutral': 'حركة إدارية',
    }[value] ??
    value;

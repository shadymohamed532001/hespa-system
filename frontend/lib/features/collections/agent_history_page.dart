import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/datetime_formatter.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/widgets/data_card.dart';
import '../../core/widgets/error_box.dart';
import '../../core/widgets/page_frame.dart';
import '../auth/session_controller.dart';
import 'agent_picker.dart';

/// Opens the full statement of one agent.
Future<void> openAgentHistory(
  BuildContext context,
  SessionController session,
  String agentName,
) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AgentHistoryPage(session: session, agentName: agentName),
    ),
  );
}

/// An agent's name that opens their statement when tapped.
class AgentNameLink extends StatelessWidget {
  const AgentNameLink({
    super.key,
    required this.session,
    required this.agentName,
    this.style,
  });

  final SessionController session;
  final String agentName;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? HesbaText.tableCell;
    return Tooltip(
      message: 'كشف حساب $agentName',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => openAgentHistory(context, session, agentName),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Text(
            agentName,
            style: base.copyWith(
              color: HesbaColors.tealDark,
              decoration: TextDecoration.underline,
              decorationColor: HesbaColors.tealDark.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}

class AgentHistoryPage extends StatefulWidget {
  const AgentHistoryPage({
    super.key,
    required this.session,
    required this.agentName,
  });

  final SessionController session;
  final String agentName;

  @override
  State<AgentHistoryPage> createState() => _AgentHistoryPageState();
}

class _AgentHistoryPageState extends State<AgentHistoryPage> {
  Map<String, dynamic>? _history;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _history = await widget.session.api.getMap(
        ApiEndpoints.agentCreditHistory(widget.agentName),
      );
      _error = null;
    } catch (exception) {
      _error = ApiClient.errorMessage(exception);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageFrame(
        onRefresh: _load,
        title: widget.agentName,
        subtitle: 'كشف حساب المندوب: كل تحصيلاته وآجله وفلوسه من الأول',
        actions: [
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('رجوع'),
          ),
        ],
        child: _loading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(80),
                  child: CircularProgressIndicator(),
                ),
              )
            : _error != null
            ? ErrorBox(message: _error!, retry: _load)
            : _content(),
      ),
    );
  }

  Widget _content() {
    final history = _history!;
    final balance = num.tryParse('${history['balance']}') ?? 0;
    final totals = Map<String, dynamic>.from(
      (history['totals'] as Map?) ?? const {},
    );
    final movements = ((history['movements'] as List?) ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final perRow = constraints.maxWidth >= 1100
                ? 4
                : constraints.maxWidth >= 600
                ? 2
                : 1;
            final width = (constraints.maxWidth - 16 * (perRow - 1)) / perRow;
            Widget card(String label, String value, String note, Color color) =>
                SizedBox(
                  width: width,
                  child: _HistoryMetric(
                    label: label,
                    value: value,
                    note: note,
                    color: color,
                  ),
                );
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                card(
                  'الرصيد الحالي',
                  agentBalanceLabel(balance),
                  balance > 0
                      ? 'آجل مستحق على المندوب'
                      : balance < 0
                      ? 'أمانة للمندوب معانا'
                      : 'مفيش عليه ولا ليه',
                  _balanceColor(balance),
                ),
                card(
                  'إجمالي الآجل',
                  money(totals['credit'] ?? 0),
                  'كل الآجل اللي اتسجل عليه',
                  HesbaColors.warning,
                ),
                card(
                  'إجمالي المستلم منه',
                  money(totals['paid'] ?? 0),
                  'سداد آجل وأمانات · مردود له ${money(totals['refunded'] ?? 0)}',
                  HesbaColors.tealDark,
                ),
                card(
                  'عدد التحصيلات',
                  '${totals['collections'] ?? 0}',
                  '${movements.length} حركة في الكشف',
                  HesbaColors.ink,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        if (movements.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: Text('مفيش حركات للمندوب ده')),
          )
        else
          DataCard(
            columns: const [
              'التاريخ والوقت',
              'النوع',
              'المرجع',
              'البيان',
              'مبلغ العملية',
              'المستلم فعليًا',
              'الحركة',
              'الرصيد بعدها',
            ],
            rows: [
              for (final row in movements)
                [
                  formatDateTime(row['date']),
                  _kindLabel(row),
                  row['reference'] ?? '—',
                  '${row['description'] ?? ''}',
                  row['operationAmount'] == null
                      ? '—'
                      : money(row['operationAmount']),
                  row['receivedAmount'] == null
                      ? '—'
                      : money(row['receivedAmount']),
                  _ChangeText(num.tryParse('${row['change']}') ?? 0),
                  Text(
                    agentBalanceLabel(
                      num.tryParse('${row['balanceAfter']}') ?? 0,
                    ),
                    style: HesbaText.tableCell.copyWith(
                      fontWeight: FontWeight.w600,
                      color: _balanceColor(
                        num.tryParse('${row['balanceAfter']}') ?? 0,
                      ),
                    ),
                  ),
                ],
            ],
          ),
      ],
    );
  }

  String _kindLabel(Map<String, dynamic> row) => switch ('${row['kind']}') {
    'collection' => row['status'] == 'pending' ? 'تحصيل معلّق' : 'تحصيل',
    'opening' => 'رصيد قديم',
    'payment' => 'استلام فلوس',
    'refund' => 'رد للمندوب',
    final other => other,
  };
}

Color _balanceColor(num balance) => balance > 0
    ? HesbaColors.warning
    : balance < 0
    ? HesbaColors.tealDark
    : HesbaColors.muted;

/// "+ عليه 2,000" when credit grows, "− 5,000" when it shrinks.
class _ChangeText extends StatelessWidget {
  const _ChangeText(this.change);

  final num change;

  @override
  Widget build(BuildContext context) {
    if (change == 0) {
      return Text('—', style: HesbaText.tableCell);
    }
    return Text(
      change > 0 ? '+ ${money(change)}' : '− ${money(-change)}',
      textDirection: TextDirection.rtl,
      style: HesbaText.tableCell.copyWith(
        fontWeight: FontWeight.w600,
        color: change > 0 ? HesbaColors.warning : HesbaColors.tealDark,
      ),
    );
  }
}

class _HistoryMetric extends StatelessWidget {
  const _HistoryMetric({
    required this.label,
    required this.value,
    required this.note,
    required this.color,
  });

  final String label;
  final String value;
  final String note;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(color: HesbaColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: HesbaText.bodyMuted),
          const SizedBox(height: 7),
          Text(
            value,
            style: HesbaText.pageTitle.copyWith(fontSize: 26, color: color),
          ),
          const SizedBox(height: 4),
          Text(note, style: HesbaText.caption),
        ],
      ),
    );
  }
}

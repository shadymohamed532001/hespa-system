import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/datetime_formatter.dart';
import '../../core/utils/digits.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/error_box.dart';
import '../../core/widgets/hesba_modal.dart';
import '../../core/widgets/page_frame.dart';
import '../auth/session_controller.dart';

class AgentCreditsPage extends StatefulWidget {
  const AgentCreditsPage({super.key, required this.session});

  final SessionController session;

  @override
  State<AgentCreditsPage> createState() => _AgentCreditsPageState();
}

class _AgentCreditsPageState extends State<AgentCreditsPage> {
  List<dynamic> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      _rows = await widget.session.api.list(ApiEndpoints.agentCredits);
      _error = null;
    } catch (exception) {
      _error = ApiClient.errorMessage(exception);
    }
    if (mounted) setState(() => _loading = false);
  }

  num get _total => _rows.fold<num>(
    0,
    (sum, row) => sum + (num.tryParse('${row['balance']}') ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'آجل المندوبين',
      subtitle: 'المبالغ المستحقة على المندوبين وتسجيل سدادها في الخزنة',
      child: _loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(80),
                child: CircularProgressIndicator(),
              ),
            )
          : _error != null
          ? ErrorBox(message: _error!, retry: _load)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth >= 700
                        ? (constraints.maxWidth - 16) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: width,
                          child: _CreditMetric(
                            label: 'إجمالي الآجل المستحق',
                            value: money(_total),
                            note: 'المبلغ اللي لسه هيدخل الخزنة',
                            warning: _rows.isNotEmpty,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _CreditMetric(
                            label: 'عدد المندوبين',
                            value: '${_rows.length}',
                            note: _rows.isEmpty
                                ? 'مفيش آجل حاليًا'
                                : 'اضغط على المندوب لتسجيل السداد',
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                if (_rows.isEmpty)
                  const _EmptyCredits()
                else
                  _CreditsTable(rows: _rows, onPay: _pay),
              ],
            ),
    );
  }

  Future<void> _pay(Map<String, dynamic> row) async {
    final balance = num.tryParse('${row['balance']}') ?? 0;
    final amount = await showHesbaModal<num>(
      context: context,
      maxWidth: 500,
      builder: (dialogContext) => _PayAgentCreditDialog(
        agentName: '${row['agentName']}',
        balance: balance,
      ),
    );
    if (amount == null || !mounted) return;
    try {
      final result = await widget.session.api.post(
        ApiEndpoints.agentCreditPayments,
        {'agentName': '${row['agentName']}', 'amount': amount},
      );
      await _load();
      if (!mounted) return;
      final remaining = num.tryParse('${result['remainingBalance']}') ?? 0;
      showAppSnack(
        context,
        remaining == 0
            ? 'تم سداد آجل ${row['agentName']} بالكامل وإضافة ${money(amount)} للخزنة'
            : 'تم إضافة ${money(amount)} للخزنة، والمتبقي ${money(remaining)}',
      );
    } catch (exception) {
      if (mounted) {
        showAppSnack(context, ApiClient.errorMessage(exception), error: true);
      }
    }
  }
}

class _PayAgentCreditDialog extends StatefulWidget {
  const _PayAgentCreditDialog({required this.agentName, required this.balance});

  final String agentName;
  final num balance;

  @override
  State<_PayAgentCreditDialog> createState() => _PayAgentCreditDialogState();
}

class _PayAgentCreditDialogState extends State<_PayAgentCreditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final balance = widget.balance;
    _controller = TextEditingController(
      text: balance == balance.roundToDouble()
          ? balance.toStringAsFixed(0)
          : balance.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HesbaModalCard(
      title: 'تسجيل سداد الآجل',
      subtitle: '${widget.agentName} · المتبقي ${money(widget.balance)}',
      actions: HesbaModalActions(
        primaryLabel: 'إضافة للخزنة وتسجيل السداد',
        onPrimary: () {
          if (!(_formKey.currentState?.validate() ?? false)) return;
          Navigator.of(context).pop(parseNum(_controller.text.trim()));
        },
        onCancel: () => Navigator.of(context).pop(),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HesbaModalField(
              label: 'المبلغ المدفوع *',
              child: TextFormField(
                controller: _controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: const [ArabicDigitsFormatter()],
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                validator: (value) {
                  final paid = parseNum(value?.trim() ?? '');
                  if (paid == null || paid <= 0) return 'أدخل مبلغًا صحيحًا';
                  if (paid > widget.balance) {
                    return 'أقصى مبلغ تسديد هو ${money(widget.balance)}';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 14),
            HesbaModalCallout(
              backgroundColor: HesbaColors.tealLight,
              child: Text(
                'المبلغ هيتضاف لرصيد الخزنة، وهيتخصم من آجل ${widget.agentName}.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditMetric extends StatelessWidget {
  const _CreditMetric({
    required this.label,
    required this.value,
    required this.note,
    this.warning = false,
  });

  final String label;
  final String value;
  final String note;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: warning ? const Color(0xFFEACF91) : HesbaColors.border,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: HesbaText.bodyMuted),
          const SizedBox(height: 7),
          Text(
            value,
            style: HesbaText.pageTitle.copyWith(
              fontSize: 28,
              color: warning ? HesbaColors.warning : HesbaColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(note, style: HesbaText.caption),
        ],
      ),
    );
  }
}

class _CreditsTable extends StatelessWidget {
  const _CreditsTable({required this.rows, required this.onPay});

  final List<dynamic> rows;
  final Future<void> Function(Map<String, dynamic> row) onPay;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: HesbaColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              showCheckboxColumn: false,
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF2F5F8)),
              horizontalMargin: 18,
              columnSpacing: 34,
              columns: const [
                DataColumn(label: Text('المندوب')),
                DataColumn(label: Text('المتبقي عليه')),
                DataColumn(label: Text('آخر حركة')),
                DataColumn(label: Text('عدد الحركات')),
                DataColumn(label: Text('السداد')),
              ],
              rows: [
                for (final item in rows)
                  DataRow(
                    onSelectChanged: (_) => onPay(item as Map<String, dynamic>),
                    cells: [
                      DataCell(
                        Text(
                          '${item['agentName']}',
                          style: HesbaText.tableCell.copyWith(
                            fontWeight: FontWeight.w600,
                            color: HesbaColors.ink,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          money(item['balance']),
                          style: HesbaText.tableCell.copyWith(
                            color: HesbaColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DataCell(Text(formatDateTime(item['lastActivityAt']))),
                      DataCell(Text('${item['movementsCount']}')),
                      DataCell(
                        FilledButton.icon(
                          onPressed: () => onPay(item as Map<String, dynamic>),
                          icon: const Icon(Icons.payments_outlined, size: 18),
                          label: const Text('تسديد'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCredits extends StatelessWidget {
  const _EmptyCredits();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: HesbaColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        children: [
          Icon(Icons.verified_outlined, size: 44, color: HesbaColors.teal),
          SizedBox(height: 12),
          Text('مفيش آجل على أي مندوب', style: HesbaText.sectionTitle),
          SizedBox(height: 5),
          Text('أي آجل جديد هيتسجل هنا تلقائيًا.', style: HesbaText.bodyMuted),
        ],
      ),
    );
  }
}

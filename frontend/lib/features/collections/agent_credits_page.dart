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
  DateTime? _from = DateUtils.dateOnly(DateTime.now());
  DateTime? _to = DateUtils.dateOnly(DateTime.now());
  String _agent = '';
  String _status = 'all';

  String _dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  List<dynamic> get _visible => _rows.where((row) {
    final date = '${row['date']}';
    if (_from != null && date.compareTo(_dayKey(_from!)) < 0) return false;
    if (_to != null && date.compareTo(_dayKey(_to!)) > 0) return false;
    if (_agent.isNotEmpty && row['agentName'] != _agent) return false;
    final closing = num.tryParse('${row['closingBalance']}') ?? 0;
    if (_status == 'outstanding' && closing <= 0) return false;
    if (_status == 'settled' && closing > 0) return false;
    return true;
  }).toList();

  num _sum(String field) => _visible.fold<num>(
    0,
    (sum, row) => sum + (num.tryParse('${row[field]}') ?? 0),
  );

  num get _currentTotal {
    final balances = <String, num>{};
    for (final row in _rows) {
      if (_agent.isNotEmpty && row['agentName'] != _agent) continue;
      balances['${row['agentName']}'.trim().toLowerCase()] =
          num.tryParse('${row['balance']}') ?? 0;
    }
    return balances.values.fold<num>(0, (sum, value) => sum + value);
  }

  Future<void> _pickDay() async {
    final day = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'اختار يوم الآجل',
    );
    if (day != null && mounted) {
      setState(() {
        _from = day;
        _to = day;
      });
    }
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _from != null && _to != null
          ? DateTimeRange(start: _from!, end: _to!)
          : null,
      helpText: 'اختار فترة مراجعة الآجل',
    );
    if (range != null && mounted) {
      setState(() {
        _from = range.start;
        _to = range.end;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (mounted && !silent) setState(() => _loading = true);
    try {
      _rows = await widget.session.api.list(
        '${ApiEndpoints.agentCredits}/days',
      );
      _error = null;
    } catch (exception) {
      _error = ApiClient.errorMessage(exception);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      onRefresh: () => _load(silent: true),
      title: 'آجل المندوبين',
      actions: [
        if (widget.session.can(AppPermissions.receiveCollections))
          FilledButton.icon(
            onPressed: _addOpening,
            icon: const Icon(Icons.add),
            label: const Text('إضافة آجل قديم'),
          ),
      ],
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
                _filters(),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth >= 700
                        ? (constraints.maxWidth - 32) / 3
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: width,
                          child: _CreditMetric(
                            label: 'إجمالي الآجل الحالي',
                            value: money(_currentTotal),
                            note:
                                'الرصيد الحالي للمندوب المحدد أو كل المندوبين، عبر كل الأيام',
                            warning: _currentTotal > 0,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _CreditMetric(
                            label: 'آجل جديد في الفترة',
                            value: money(_sum('credit')),
                            note: 'إجمالي الآجل المضاف في الأيام المعروضة',
                            warning: _sum('credit') > 0,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _CreditMetric(
                            label: 'المسدّد في الفترة',
                            value: money(_sum('paid')),
                            note:
                                '${_visible.map((row) => row['agentName']).toSet().length} مندوب · ${_visible.length} سجل يومي',
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                if (_visible.isEmpty)
                  const _EmptyCredits()
                else
                  _CreditsTable(
                    rows: _visible,
                    onPay: _pay,
                    canPay: widget.session.can(
                      AppPermissions.receiveCollections,
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _filters() {
    final agents = _rows.map((row) => '${row['agentName']}').toSet().toList()
      ..sort();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDay,
                  icon: const Icon(Icons.calendar_month),
                  label: Text(
                    _from != null && _from == _to
                        ? formatDate(_from!.toIso8601String())
                        : 'اختيار يوم',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range),
                  label: const Text('اختيار فترة'),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _from = DateUtils.dateOnly(DateTime.now());
                    _to = _from;
                  }),
                  child: const Text('النهارده'),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _from = null;
                    _to = null;
                  }),
                  child: const Text('كل الأيام'),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    key: ValueKey('agent-$_agent'),
                    initialValue: agents.contains(_agent) ? _agent : '',
                    decoration: const InputDecoration(labelText: 'المندوب'),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('كل المندوبين'),
                      ),
                      for (final name in agents)
                        DropdownMenuItem(value: name, child: Text(name)),
                    ],
                    onChanged: (value) => setState(() => _agent = value ?? ''),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _status,
                    decoration: const InputDecoration(
                      labelText: 'رصيد نهاية اليوم',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('كل الحالات')),
                      DropdownMenuItem(
                        value: 'outstanding',
                        child: Text('عليه آجل'),
                      ),
                      DropdownMenuItem(value: 'settled', child: Text('مسدد')),
                    ],
                    onChanged: (value) =>
                        setState(() => _status = value ?? 'all'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _from == null
                  ? 'عرض كل الأيام'
                  : 'من ${formatDate(_from!.toIso8601String())} إلى ${formatDate(_to!.toIso8601String())}',
              style: HesbaText.bodyMuted,
            ),
            const SizedBox(height: 4),
            const Text(
              'كل صف يمثل حركة مندوب في يوم. رصيد نهاية اليوم يشمل الآجل السابق، والسداد يتم من إجمالي الآجل الحالي للمندوب.',
              style: HesbaText.caption,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addOpening() async {
    final name = TextEditingController();
    final amount = TextEditingController();
    final note = TextEditingController();
    final form = GlobalKey<FormState>();
    var saving = false;
    String? error;
    final saved = await showHesbaModal<bool>(
      context: context,
      maxWidth: 520,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => HesbaModalCard(
          title: 'إضافة آجل قديم',
          subtitle:
              'سجّل المبلغ المستحق قبل استخدام السيستم. يدخل الخزنة عند سداده فقط. لو الاسم موجود هيتضاف المبلغ على الآجل الحالي.',
          actions: HesbaModalActions(
            primaryLabel: saving ? 'جارٍ الحفظ...' : 'حفظ الآجل',
            primaryEnabled: !saving,
            onCancel: () {
              if (!saving) Navigator.pop(ctx, false);
            },
            onPrimary: () async {
              if (saving || !form.currentState!.validate()) return;
              setLocal(() {
                saving = true;
                error = null;
              });
              try {
                await widget.session.api
                    .post('${ApiEndpoints.agentCredits}/opening', {
                      'agentName': name.text.trim(),
                      'amount': parseNum(amount.text),
                      if (note.text.trim().isNotEmpty) 'note': note.text.trim(),
                    });
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  setLocal(() {
                    saving = false;
                    error = ApiClient.errorMessage(e);
                  });
                }
              }
            },
          ),
          child: Form(
            key: form,
            child: Column(
              children: [
                TextFormField(
                  controller: name,
                  enabled: !saving,
                  maxLength: 150,
                  decoration: const InputDecoration(labelText: 'اسم المندوب *'),
                  validator: (v) =>
                      (v?.trim().length ?? 0) < 2 ? 'اكتب اسم المندوب' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amount,
                  enabled: !saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: const [MoneyInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'المبلغ المستحق *',
                  ),
                  validator: (v) => (parseNum(v) ?? 0) <= 0
                      ? 'اكتب مبلغًا أكبر من صفر'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: note,
                  enabled: !saving,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة (اختياري)',
                  ),
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ),
      ),
    );
    // Dispose after the dialog's closing animation finishes.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    name.dispose();
    amount.dispose();
    note.dispose();
    if (saved == true && mounted) {
      await _load();
      if (mounted) showAppSnack(context, 'تم تسجيل الآجل القديم');
    }
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
                inputFormatters: const [MoneyInputFormatter()],
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
  const _CreditsTable({
    required this.rows,
    required this.onPay,
    required this.canPay,
  });

  final bool canPay;

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
                DataColumn(label: Text('اليوم')),
                DataColumn(label: Text('المندوب')),
                DataColumn(label: Text('رصيد أول اليوم')),
                DataColumn(label: Text('آجل جديد')),
                DataColumn(label: Text('المسدّد')),
                DataColumn(label: Text('رصيد نهاية اليوم')),
                DataColumn(label: Text('الآجل الحالي')),
                DataColumn(label: Text('عدد الحركات')),
                DataColumn(label: Text('السداد')),
              ],
              rows: [
                for (final item in rows)
                  DataRow(
                    cells: [
                      DataCell(Text(formatDate(item['date']))),
                      DataCell(
                        Text(
                          '${item['agentName']}',
                          style: HesbaText.tableCell.copyWith(
                            fontWeight: FontWeight.w600,
                            color: HesbaColors.ink,
                          ),
                        ),
                      ),
                      DataCell(Text(money(item['openingBalance']))),
                      DataCell(Text(money(item['credit']))),
                      DataCell(Text(money(item['paid']))),
                      DataCell(Text(money(item['closingBalance']))),
                      DataCell(Text(money(item['balance']))),
                      DataCell(Text('${item['movementsCount']}')),
                      DataCell(
                        FilledButton.icon(
                          onPressed:
                              canPay &&
                                  (num.tryParse('${item['balance']}') ?? 0) > 0
                              ? () => onPay(item as Map<String, dynamic>)
                              : null,
                          icon: const Icon(Icons.payments_outlined, size: 18),
                          label: const Text('سداد من الإجمالي الحالي'),
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
          Text('مفيش حركات آجل بالفلترة دي', style: HesbaText.sectionTitle),
          SizedBox(height: 5),
          Text(
            'اختار يوم تاني من الكالندر أو اعرض كل الأيام.',
            style: HesbaText.bodyMuted,
          ),
        ],
      ),
    );
  }
}

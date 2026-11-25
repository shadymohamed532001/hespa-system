import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/datetime_formatter.dart';
import '../../core/utils/digits.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/data_card.dart';
import '../../core/widgets/error_box.dart';
import '../../core/widgets/hesba_modal.dart';
import '../../core/widgets/page_frame.dart';
import '../auth/session_controller.dart';
import 'agent_picker.dart';

/// The shop owner's notebook of money borrowed from people and paid back.
/// Record-only: it never changes the treasury or account balances.
class ShopDebtsSection extends StatefulWidget {
  const ShopDebtsSection({super.key, required this.session});

  final SessionController session;

  @override
  State<ShopDebtsSection> createState() => _ShopDebtsSectionState();
}

class _ShopDebtsSectionState extends State<ShopDebtsSection> {
  List<Map<String, dynamic>> _people = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _people = (await widget.session.api.list(
        ApiEndpoints.shopDebts,
      )).whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
      _error = null;
    } catch (exception) {
      _error = ApiClient.errorMessage(exception);
    }
    if (mounted) setState(() => _loading = false);
  }

  num _sum(String field) => _people.fold<num>(
    0,
    (sum, row) => sum + (num.tryParse('${row[field]}') ?? 0),
  );

  Future<void> _record({
    required String kind,
    Map<String, dynamic>? person,
  }) async {
    final saved = await showShopDebtDialog(
      context,
      widget.session,
      kind: kind,
      people: _people,
      personName: person == null ? null : '${person['personName']}',
      owed: person == null ? null : num.tryParse('${person['owed']}') ?? 0,
    );
    if (saved && mounted) {
      await _load();
      if (mounted) {
        showAppSnack(
          context,
          kind == 'borrow' ? 'تم تسجيل السلفة' : 'تم تسجيل السداد',
        );
      }
    }
  }

  Future<void> _openHistory(String name) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ShopDebtHistoryPage(session: widget.session, personName: name),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(80),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_error != null) return ErrorBox(message: _error!, retry: _load);
    final owing = _people
        .where((row) => (num.tryParse('${row['owed']}') ?? 0) > 0)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: () => _record(kind: 'borrow'),
              icon: const Icon(Icons.add),
              label: const Text('تسجيل سلفة جديدة'),
            ),
            const Text(
              'للتسجيل بس: الفلوس اللي صاحب المحل استلفها من ناس وسدادها، من غير ما تأثر على الخزنة أو الحسابات.',
              style: HesbaText.caption,
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final perRow = constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 600
                ? 2
                : 1;
            final width = (constraints.maxWidth - 16 * (perRow - 1)) / perRow;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: width,
                  child: _DebtMetric(
                    label: 'إجمالي اللي على المحل',
                    value: money(_sum('owed')),
                    note: '$owing شخص لسه ليهم فلوس',
                    color: HesbaColors.warning,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _DebtMetric(
                    label: 'إجمالي اللي اتسلف',
                    value: money(_sum('borrowed')),
                    note: 'كل السلف من الأول',
                    color: HesbaColors.ink,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _DebtMetric(
                    label: 'إجمالي اللي اتسدد',
                    value: money(_sum('repaid')),
                    note: '${_people.length} شخص في الدفتر',
                    color: HesbaColors.tealDark,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        if (_people.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Text('مفيش سلف متسجلة. دوس «تسجيل سلفة جديدة».'),
            ),
          )
        else
          DataCard(
            columns: const [
              'الشخص',
              'اتسلف منه',
              'اتسدد له',
              'الباقي له',
              'آخر حركة',
              'إجراء',
            ],
            rows: [
              for (final person in _people)
                [
                  InkWell(
                    onTap: () => _openHistory('${person['personName']}'),
                    child: Text(
                      '${person['personName']}',
                      style: HesbaText.tableCell.copyWith(
                        fontWeight: FontWeight.w600,
                        color: HesbaColors.tealDark,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  money(person['borrowed']),
                  money(person['repaid']),
                  _OwedText(num.tryParse('${person['owed']}') ?? 0),
                  formatDateTime(person['lastActivityAt']),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton.icon(
                        onPressed: (num.tryParse('${person['owed']}') ?? 0) > 0
                            ? () => _record(kind: 'repay', person: person)
                            : null,
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('سداد'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _record(kind: 'borrow', person: person),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('سلفة تانية'),
                      ),
                    ],
                  ),
                ],
            ],
          ),
      ],
    );
  }
}

/// Records a loan (kind borrow) or a repayment (kind repay). Returns true when
/// saved.
Future<bool> showShopDebtDialog(
  BuildContext context,
  SessionController session, {
  required String kind,
  required List<Map<String, dynamic>> people,
  String? personName,
  num? owed,
}) async {
  final saved = await showHesbaModal<bool>(
    context: context,
    maxWidth: 520,
    builder: (_) => _ShopDebtDialog(
      session: session,
      kind: kind,
      people: people,
      personName: personName,
      owed: owed,
    ),
  );
  return saved == true;
}

class _ShopDebtDialog extends StatefulWidget {
  const _ShopDebtDialog({
    required this.session,
    required this.kind,
    required this.people,
    this.personName,
    this.owed,
  });

  final SessionController session;
  final String kind;
  final List<Map<String, dynamic>> people;
  final String? personName;
  final num? owed;

  @override
  State<_ShopDebtDialog> createState() => _ShopDebtDialogState();
}

class _ShopDebtDialogState extends State<_ShopDebtDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;
  String? _error;

  bool get _repay => widget.kind == 'repay';

  /// The picker shows what the shop owes as money the person has with us.
  List<Map<String, dynamic>> get _pickerPeople => [
    for (final person in widget.people)
      {
        'agentName': person['personName'],
        'balance': -(num.tryParse('${person['owed']}') ?? 0),
      },
  ];

  num get _owed {
    if (widget.owed != null) return widget.owed!;
    final key = agentSearchKey(_name.text);
    for (final person in widget.people) {
      if (key.isNotEmpty && agentSearchKey('${person['personName']}') == key) {
        return num.tryParse('${person['owed']}') ?? 0;
      }
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    if (_repay && (widget.owed ?? 0) > 0) {
      final owed = widget.owed!;
      _amount.text = owed == owed.roundToDouble()
          ? owed.toStringAsFixed(0)
          : owed.toStringAsFixed(2);
    }
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.session.api.post(ApiEndpoints.shopDebts, {
        'personName': widget.personName ?? _name.text.trim(),
        'kind': widget.kind,
        'amount': parseNum(_amount.text.trim()),
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (exception) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = ApiClient.errorMessage(exception);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return HesbaModalCard(
      title: _repay ? 'سداد سلفة' : 'تسجيل سلفة',
      subtitle: widget.personName != null
          ? '${widget.personName} · الباقي له ${money(_owed)}'
          : 'سجّل الفلوس اللي صاحب المحل استلفها. للتسجيل بس، مش بتأثر على الخزنة.',
      actions: HesbaModalActions(
        primaryLabel: _saving
            ? 'جارٍ الحفظ...'
            : _repay
            ? 'تسجيل السداد'
            : 'تسجيل السلفة',
        primaryEnabled: !_saving,
        onPrimary: _save,
        onCancel: () {
          if (!_saving) Navigator.of(context).pop(false);
        },
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.personName == null) ...[
              AgentPicker(
                controller: _name,
                agents: _pickerPeople,
                enabled: !_saving,
                noun: 'شخص',
                label: 'الشخص *',
              ),
              const SizedBox(height: 8),
            ],
            HesbaModalField(
              label: _repay ? 'المبلغ اللي اتسدد *' : 'المبلغ اللي اتسلف *',
              child: TextFormField(
                key: const ValueKey('shop-debt-amount'),
                controller: _amount,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: const [MoneyInputFormatter()],
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                validator: (value) {
                  final amount = parseNum(value?.trim() ?? '');
                  if (amount == null || amount <= 0) {
                    return 'أدخل مبلغًا صحيحًا';
                  }
                  if (_repay && amount > _owed) {
                    return 'أقصى مبلغ سداد هو ${money(_owed)}';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 14),
            HesbaModalField(
              label: 'ملاحظة (اختياري)',
              child: TextFormField(
                controller: _note,
                enabled: !_saving,
                maxLength: 500,
              ),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: HesbaColors.red)),
          ],
        ),
      ),
    );
  }
}

/// Every loan and repayment of one person, with what was owed after each.
class ShopDebtHistoryPage extends StatefulWidget {
  const ShopDebtHistoryPage({
    super.key,
    required this.session,
    required this.personName,
  });

  final SessionController session;
  final String personName;

  @override
  State<ShopDebtHistoryPage> createState() => _ShopDebtHistoryPageState();
}

class _ShopDebtHistoryPageState extends State<ShopDebtHistoryPage> {
  Map<String, dynamic>? _history;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _history = await widget.session.api.getMap(
        ApiEndpoints.shopDebtHistory(widget.personName),
      );
      _error = null;
    } catch (exception) {
      _error = ApiClient.errorMessage(exception);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _record(String kind) async {
    final owed = num.tryParse('${_history?['owed']}') ?? 0;
    final saved = await showShopDebtDialog(
      context,
      widget.session,
      kind: kind,
      people: const [],
      personName: '${_history?['personName'] ?? widget.personName}',
      owed: owed,
    );
    if (saved) await _load();
  }

  Future<void> _cancel(Map<String, dynamic> movement) async {
    final reason = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء الحركة'),
        content: TextField(
          controller: reason,
          autofocus: true,
          maxLength: 300,
          decoration: const InputDecoration(labelText: 'سبب الإلغاء'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () {
              final text = reason.text.trim();
              if (text.length >= 3) Navigator.pop(context, text);
            },
            child: const Text('إلغاء الحركة'),
          ),
        ],
      ),
    );
    reason.dispose();
    if (value == null || !mounted) return;
    try {
      await widget.session.api.post(
        ApiEndpoints.cancelShopDebt('${movement['id']}'),
        {'reason': value},
      );
      await _load();
      if (mounted) showAppSnack(context, 'تم إلغاء الحركة');
    } catch (exception) {
      if (mounted) {
        showAppSnack(context, ApiClient.errorMessage(exception), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final owed = num.tryParse('${_history?['owed']}') ?? 0;
    return Scaffold(
      body: PageFrame(
        onRefresh: _load,
        title: '${_history?['personName'] ?? widget.personName}',
        subtitle: 'كشف السلف: كل اللي اتسلف من الشخص ده واللي اتسدد له',
        actions: [
          if (!_loading && _error == null) ...[
            FilledButton.icon(
              onPressed: owed > 0 ? () => _record('repay') : null,
              icon: const Icon(Icons.check),
              label: const Text('سداد'),
            ),
            OutlinedButton.icon(
              onPressed: () => _record('borrow'),
              icon: const Icon(Icons.add),
              label: const Text('سلفة تانية'),
            ),
          ],
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
    final movements = ((history['movements'] as List?) ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final perRow = constraints.maxWidth >= 900 ? 3 : 1;
            final width = (constraints.maxWidth - 16 * (perRow - 1)) / perRow;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: width,
                  child: _DebtMetric(
                    label: 'الباقي له',
                    value: money(history['owed'] ?? 0),
                    note: (num.tryParse('${history['owed']}') ?? 0) > 0
                        ? 'المحل لسه مديون له بالمبلغ ده'
                        : 'اتسدد كله',
                    color: HesbaColors.warning,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _DebtMetric(
                    label: 'اتسلف منه',
                    value: money(history['borrowed'] ?? 0),
                    note: 'كل السلف',
                    color: HesbaColors.ink,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: _DebtMetric(
                    label: 'اتسدد له',
                    value: money(history['repaid'] ?? 0),
                    note: 'كل السداد',
                    color: HesbaColors.tealDark,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        DataCard(
          columns: const [
            'التاريخ والوقت',
            'النوع',
            'المرجع',
            'المبلغ',
            'ملاحظة',
            'الباقي بعدها',
            'المستخدم',
            'إجراء',
          ],
          rows: [
            for (final row in movements)
              [
                formatDateTime(row['createdAt']),
                row['cancelled'] == true
                    ? 'ملغية'
                    : row['kind'] == 'borrow'
                    ? 'سلفة'
                    : 'سداد',
                '${row['reference']}',
                Text(
                  '${row['kind'] == 'borrow' ? '+' : '−'} ${money(row['amount'])}',
                  style: HesbaText.tableCell.copyWith(
                    fontWeight: FontWeight.w600,
                    color: row['cancelled'] == true
                        ? HesbaColors.muted
                        : row['kind'] == 'borrow'
                        ? HesbaColors.warning
                        : HesbaColors.tealDark,
                    decoration: row['cancelled'] == true
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                row['cancelled'] == true
                    ? 'ملغية: ${row['cancelReason'] ?? ''}'
                    : '${row['note'] ?? '—'}',
                money(row['owedAfter']),
                '${row['performedBy'] ?? '—'}',
                row['cancelled'] == true
                    ? const Text('—')
                    : TextButton(
                        onPressed: () => _cancel(row),
                        child: const Text('إلغاء'),
                      ),
              ],
          ],
        ),
      ],
    );
  }
}

class _OwedText extends StatelessWidget {
  const _OwedText(this.owed);

  final num owed;

  @override
  Widget build(BuildContext context) => Text(
    owed > 0 ? money(owed) : 'اتسدد',
    style: HesbaText.tableCell.copyWith(
      fontWeight: FontWeight.w600,
      color: owed > 0 ? HesbaColors.warning : HesbaColors.muted,
    ),
  );
}

class _DebtMetric extends StatelessWidget {
  const _DebtMetric({
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

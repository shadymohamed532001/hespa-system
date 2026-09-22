import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/error_box.dart';
import '../../core/widgets/page_frame.dart';
import '../auth/session_controller.dart';

class TopUpPage extends StatefulWidget {
  const TopUpPage({super.key, required this.session});

  final SessionController session;

  @override
  State<TopUpPage> createState() => _TopUpPageState();
}

class _TopUpPageState extends State<TopUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController(text: '10000');
  final _reference = TextEditingController();
  final _note = TextEditingController();
  final _date = TextEditingController(
    text: DateFormat('dd/MM/yyyy').format(DateTime.now()),
  );

  List<_TopUpTarget> _targets = [];
  String? _selected;
  String _additionType = 'direct';
  bool _loading = true;
  bool _saving = false;
  bool _rolling = false;
  String? _error;
  int _nextSequence = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _note.dispose();
    _date.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        widget.session.api.list(ApiEndpoints.accounts),
        widget.session.api.list(ApiEndpoints.wallets),
        widget.session.api.list(ApiEndpoints.ledgerList(limit: 200)),
      ]);
      final accounts = values[0];
      final wallets = values[1];
      final ledger = values[2];

      final targets = <_TopUpTarget>[
        ...accounts
            .where((item) => item['active'] != false)
            .map(
              (item) => _TopUpTarget(
                value: 'account:${item['id']}',
                kind: 'account',
                id: '${item['id']}',
                name: '${item['name']}',
                opening: num.tryParse('${item['openingBalance']}') ?? 0,
                balance: num.tryParse('${item['balance']}') ?? 0,
              ),
            ),
        ...wallets
            .where((item) => item['active'] != false)
            .map(
              (item) => _TopUpTarget(
                value: 'wallet:${item['id']}',
                kind: 'wallet',
                id: '${item['id']}',
                name: '${item['name']}',
                opening: num.tryParse('${item['openingBalance']}') ?? 0,
                balance: num.tryParse('${item['balance']}') ?? 0,
              ),
            ),
      ];

      _nextSequence =
          ledger.where((entry) => entry['category'] == 'top_up').length + 1;
      _targets = targets;
      _selected ??= targets.isEmpty ? null : targets.first.value;
      if (_selected != null &&
          targets.every((item) => item.value != _selected)) {
        _selected = targets.isEmpty ? null : targets.first.value;
      }
      if (_reference.text.trim().isEmpty) {
        _reference.text = _newReference();
      }
      _error = null;
    } catch (exception) {
      _error = ApiClient.errorMessage(exception);
    }
    if (mounted) setState(() => _loading = false);
  }

  String _newReference() {
    final sequence = _nextSequence.toString().padLeft(3, '0');
    return 'TOP-${DateTime.now().year}-$sequence';
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'شحن حساب أو محفظة',
      subtitle:
          'يُضاف الرصيد مع الإبقاء على المبلغ المرحّل من اليوم السابق دون تصفيره',
      actions: [
        OutlinedButton(
          onPressed: _rolling || _loading ? null : _simulateNewDay,
          child: _rolling
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('محاكاة بدء يوم جديد'),
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
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _RolloverNotice(),
                const SizedBox(height: 20),
                _TopUpFormCard(
                  formKey: _formKey,
                  targets: _targets,
                  selected: _selected,
                  amount: _amount,
                  additionType: _additionType,
                  date: _date,
                  reference: _reference,
                  note: _note,
                  saving: _saving,
                  onSelectedChanged: (value) =>
                      setState(() => _selected = value),
                  onAdditionTypeChanged: (value) =>
                      setState(() => _additionType = value ?? 'direct'),
                  onSubmit: _submit,
                ),
                const SizedBox(height: 20),
                const _DailyBalanceFormula(),
              ],
            ),
    );
  }

  Future<void> _simulateNewDay() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('محاكاة بدء يوم جديد'),
        content: const Text(
          'سيتم ترحيل الأرصدة الحالية كرصيد افتتاحي وتصفير عدّادات الشحن اليومية. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _rolling = true);
    try {
      await widget.session.api.post(ApiEndpoints.treasuryRollover);
      await _load();
      if (mounted) {
        showAppSnack(context, 'تم ترحيل الأرصدة وبدء يوم جديد');
      }
    } catch (exception) {
      if (mounted) {
        showAppSnack(context, ApiClient.errorMessage(exception), error: true);
      }
    }
    if (mounted) setState(() => _rolling = false);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selected == null) {
      showAppSnack(context, 'اختر حسابًا أو محفظة للشحن', error: true);
      return;
    }

    final target = _targets.firstWhere((item) => item.value == _selected);
    setState(() => _saving = true);
    try {
      final path = target.kind == 'account'
          ? ApiEndpoints.accountTopUp(target.id)
          : ApiEndpoints.walletTopUp(target.id);
      final reference = _reference.text.trim();
      final note = _note.text.trim();
      await widget.session.api.post(path, {
        'amount': num.parse(_amount.text.trim()),
        if (reference.isNotEmpty || note.isNotEmpty)
          'reference': note.isEmpty
              ? reference
              : reference.isEmpty
              ? note
              : '$reference — $note',
      });
      _nextSequence += 1;
      _amount.text = '10000';
      _note.clear();
      _reference.text = _newReference();
      await _load();
      if (mounted) showAppSnack(context, 'تم إضافة الرصيد بنجاح');
    } catch (exception) {
      if (mounted) {
        showAppSnack(context, ApiClient.errorMessage(exception), error: true);
      }
    }
    if (mounted) setState(() => _saving = false);
  }
}

class _TopUpTarget {
  const _TopUpTarget({
    required this.value,
    required this.kind,
    required this.id,
    required this.name,
    required this.opening,
    required this.balance,
  });

  final String value;
  final String kind;
  final String id;
  final String name;
  final num opening;
  final num balance;

  String get label =>
      '$name — مرحل ${money(opening)} — حالي ${money(balance)}';
}

class _RolloverNotice extends StatelessWidget {
  const _RolloverNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
      decoration: BoxDecoration(
        color: const Color(0xFFE9EEF6),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFD5DEEA)),
      ),
      child: const Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'منطق الترحيل: ',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text:
                  'الرصيد المتبقي من أمس لا يُصفَّر، بل يُرحَّل. عدّادات الشحن اليومية تُعاد مع بداية اليوم بينما يستمر العدّاد الشهري.',
            ),
          ],
        ),
        style: TextStyle(color: Color(0xFF50657D), fontSize: 13, height: 1.55),
      ),
    );
  }
}

class _TopUpFormCard extends StatelessWidget {
  const _TopUpFormCard({
    required this.formKey,
    required this.targets,
    required this.selected,
    required this.amount,
    required this.additionType,
    required this.date,
    required this.reference,
    required this.note,
    required this.saving,
    required this.onSelectedChanged,
    required this.onAdditionTypeChanged,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final List<_TopUpTarget> targets;
  final String? selected;
  final TextEditingController amount;
  final String additionType;
  final TextEditingController date;
  final TextEditingController reference;
  final TextEditingController note;
  final bool saving;
  final ValueChanged<String?> onSelectedChanged;
  final ValueChanged<String?> onAdditionTypeChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: HesbaColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22, vertical: 17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'بيانات الشحن',
                  style: TextStyle(
                    color: HesbaColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'اختر الحساب أو المحفظة وأضف الرصيد مباشرة',
                  style: TextStyle(color: HesbaColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE9EEF2)),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
            child: Form(
              key: formKey,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900 ? 3 : 1;
                  final fieldWidth = columns == 3
                      ? (constraints.maxWidth - 48) / 3
                      : constraints.maxWidth;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 24,
                        runSpacing: 18,
                        children: [
                          SizedBox(
                            width: fieldWidth,
                            child: _LabeledField(
                              label: 'الحساب أو المحفظة المطلوب شحنها *',
                              child: DropdownButtonFormField<String>(
                                initialValue: selected,
                                isExpanded: true,
                                decoration: const InputDecoration(),
                                items: [
                                  for (final target in targets)
                                    DropdownMenuItem(
                                      value: target.value,
                                      child: Text(
                                        target.label,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                                onChanged: saving ? null : onSelectedChanged,
                                validator: (value) => value == null
                                    ? 'اختر حسابًا أو محفظة'
                                    : null,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: _LabeledField(
                              label: 'مبلغ الشحن *',
                              child: TextFormField(
                                controller: amount,
                                enabled: !saving,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(),
                                validator: (value) {
                                  final parsed = num.tryParse(
                                    value?.trim() ?? '',
                                  );
                                  if (parsed == null || parsed <= 0) {
                                    return 'أدخل مبلغًا صحيحًا';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: _LabeledField(
                              label: 'نوع الإضافة *',
                              child: DropdownButtonFormField<String>(
                                initialValue: additionType,
                                decoration: const InputDecoration(),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'direct',
                                    child: Text(
                                      'شحن مباشر من خارج النظام',
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'settlement',
                                    child: Text('تسوية / توريد'),
                                  ),
                                ],
                                onChanged: saving
                                    ? null
                                    : onAdditionTypeChanged,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: _LabeledField(
                              label: 'التاريخ *',
                              child: TextFormField(
                                controller: date,
                                enabled: false,
                                decoration: const InputDecoration(
                                  suffixIcon: Icon(Icons.calendar_today_outlined),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: _LabeledField(
                              label: 'رقم المرجع',
                              child: TextFormField(
                                controller: reference,
                                enabled: !saving,
                                decoration: const InputDecoration(),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: _LabeledField(
                              label: 'ملاحظة',
                              child: TextFormField(
                                controller: note,
                                enabled: !saving,
                                decoration: const InputDecoration(
                                  hintText: 'اختياري — سبب الشحن أو تفاصيل إضافية',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FilledButton(
                          onPressed: saving || targets.isEmpty ? null : onSubmit,
                          child: saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('إضافة الرصيد'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyBalanceFormula extends StatelessWidget {
  const _DailyBalanceFormula();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: HesbaColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'معادلة الرصيد اليومية',
            style: TextStyle(
              color: HesbaColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE9EEF6),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Text(
              'الرصيد الحالي = الرصيد المرحّل من أمس + شحن اليوم − المبالغ المستخدمة أو المحوّلة',
              style: TextStyle(
                color: Color(0xFF50657D),
                fontSize: 13,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF5A6F7C),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

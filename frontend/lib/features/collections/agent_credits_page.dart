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
import 'agent_picker.dart';
import 'agent_history_page.dart';

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
    if (_status == 'deposit' && closing >= 0) return false;
    if (_status == 'settled' && closing != 0) return false;
    return true;
  }).toList();

  num _sum(String field) => _visible.fold<num>(
    0,
    (sum, row) => sum + (num.tryParse('${row[field]}') ?? 0),
  );

  /// Latest balance per agent: positive = the agent owes us, negative = we
  /// hold the agent's money (deposit).
  Iterable<num> get _currentBalances {
    final balances = <String, num>{};
    for (final row in _rows) {
      if (_agent.isNotEmpty && row['agentName'] != _agent) continue;
      balances['${row['agentName']}'.trim().toLowerCase()] =
          num.tryParse('${row['balance']}') ?? 0;
    }
    return balances.values;
  }

  num get _owedByAgents => _currentBalances
      .where((value) => value > 0)
      .fold<num>(0, (sum, value) => sum + value);

  num get _heldForAgents => _currentBalances
      .where((value) => value < 0)
      .fold<num>(0, (sum, value) => sum - value);

  /// Every agent on the page with their current balance, for the picker.
  List<Map<String, dynamic>> get _agentAccounts {
    final byKey = <String, Map<String, dynamic>>{};
    for (final row in _rows) {
      final key = '${row['agentName']}'.trim().toLowerCase();
      byKey.putIfAbsent(
        key,
        () => {'agentName': row['agentName'], 'balance': row['balance']},
      );
    }
    return byKey.values.toList()
      ..sort((a, b) => '${a['agentName']}'.compareTo('${b['agentName']}'));
  }

  List<String> get _agentNames =>
      _rows.map((row) => '${row['agentName']}').toSet().toList()..sort();

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
        if (widget.session.can(AppPermissions.receiveCollections)) ...[
          FilledButton.icon(
            onPressed: () => _moveCash(null, _CashDirection.receive),
            icon: const Icon(Icons.savings_outlined),
            label: const Text('استلام فلوس من مندوب'),
          ),
          OutlinedButton.icon(
            onPressed: _addOpening,
            icon: const Icon(Icons.add),
            label: const Text('إضافة رصيد قديم'),
          ),
        ],
      ],
      subtitle:
          'اللي على المندوبين من آجل، واللي ليهم من أمانات سابوها في الخزنة',
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
                    final perRow = constraints.maxWidth >= 1100
                        ? 4
                        : constraints.maxWidth >= 600
                        ? 2
                        : 1;
                    final width =
                        (constraints.maxWidth - 16 * (perRow - 1)) / perRow;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: width,
                          child: _CreditMetric(
                            label: 'إجمالي اللي على المندوبين',
                            value: money(_owedByAgents),
                            note: 'آجل حالي مستحق علينا نحصّله، عبر كل الأيام',
                            tone: _owedByAgents > 0
                                ? _MetricTone.warning
                                : _MetricTone.normal,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _CreditMetric(
                            label: 'إجمالي أمانات المندوبين',
                            value: money(_heldForAgents),
                            note: 'فلوس المندوبين اللي معانا ولازم تترد لهم',
                            tone: _heldForAgents > 0
                                ? _MetricTone.deposit
                                : _MetricTone.normal,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _CreditMetric(
                            label: 'آجل جديد في الفترة',
                            value: money(_sum('credit')),
                            note: 'إجمالي الآجل المضاف في الأيام المعروضة',
                            tone: _sum('credit') > 0
                                ? _MetricTone.warning
                                : _MetricTone.normal,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _CreditMetric(
                            label: 'المستلم في الفترة',
                            value: money(_sum('paid')),
                            note:
                                'مردود ${money(_sum('refunded'))} · ${_visible.map((row) => row['agentName']).toSet().length} مندوب · ${_visible.length} سجل يومي',
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
                    session: widget.session,
                    rows: _visible,
                    onReceive: (row) => _moveCash(row, _CashDirection.receive),
                    onRefund: (row) => _moveCash(row, _CashDirection.refund),
                    canPay: widget.session.can(
                      AppPermissions.receiveCollections,
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _filters() {
    final agents = _agentNames;
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
                      DropdownMenuItem(
                        value: 'deposit',
                        child: Text('ليه أمانة'),
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
              'كل صف يمثل حركة مندوب في يوم. «عليه» يعني آجل مستحق على المندوب، و«ليه» يعني أمانة للمندوب معانا. الاستلام بيسدد الآجل الأول والزيادة بتتسجل أمانة.',
              style: HesbaText.caption,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addOpening() async {
    final name = TextEditingController();
    final agents = _agentAccounts;
    final amount = TextEditingController();
    final note = TextEditingController();
    final form = GlobalKey<FormState>();
    var direction = 'owes';
    var saving = false;
    String? error;
    final saved = await showHesbaModal<bool>(
      context: context,
      maxWidth: 520,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => HesbaModalCard(
          title: 'إضافة رصيد قديم',
          subtitle:
              'سجّل رصيد المندوب قبل استخدام السيستم. مش بيأثر على الخزنة. لو الاسم موجود هيتقاص مع رصيده الحالي.',
          actions: HesbaModalActions(
            primaryLabel: saving ? 'جارٍ الحفظ...' : 'حفظ الرصيد',
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
                      'direction': direction,
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
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'owes', label: Text('عليه آجل')),
                    ButtonSegment(value: 'owed', label: Text('ليه أمانة')),
                  ],
                  selected: {direction},
                  onSelectionChanged: saving
                      ? null
                      : (value) => setLocal(() => direction = value.first),
                ),
                const SizedBox(height: 16),
                AgentPicker(controller: name, agents: agents, enabled: !saving),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amount,
                  enabled: !saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: const [MoneyInputFormatter()],
                  decoration: InputDecoration(
                    labelText: direction == 'owed'
                        ? 'مبلغ الأمانة *'
                        : 'المبلغ المستحق *',
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
      if (mounted) showAppSnack(context, 'تم تسجيل الرصيد القديم');
    }
  }

  Future<void> _moveCash(
    Map<String, dynamic>? row,
    _CashDirection direction,
  ) async {
    final destinations = direction == _CashDirection.receive
        ? await _loadDestinations()
        : const [_Destination.treasury];
    if (!mounted) return;
    final result =
        await showHesbaModal<
          ({String agentName, num amount, _Destination destination})
        >(
          context: context,
          maxWidth: 500,
          builder: (dialogContext) => _AgentCashDialog(
            direction: direction,
            agentName: row == null ? null : '${row['agentName']}',
            balance: row == null
                ? null
                : num.tryParse('${row['balance']}') ?? 0,
            agents: _agentAccounts,
            destinations: destinations,
          ),
        );
    if (result == null || !mounted) return;
    try {
      final response = await widget.session.api.post(
        direction == _CashDirection.receive
            ? ApiEndpoints.agentCreditPayments
            : ApiEndpoints.agentCreditRefunds,
        {
          'agentName': result.agentName,
          'amount': result.amount,
          ...result.destination.body,
        },
      );
      await _load();
      if (!mounted) return;
      final remaining = num.tryParse('${response['remainingBalance']}') ?? 0;
      final action = direction == _CashDirection.receive
          ? 'تم إضافة ${money(result.amount)} على ${result.destination.label}'
          : 'تم صرف ${money(result.amount)} من الخزنة لـ ${result.agentName}';
      showAppSnack(
        context,
        '$action، ورصيد ${result.agentName} دلوقتي ${_balanceLabel(remaining)}',
      );
    } catch (exception) {
      if (mounted) {
        showAppSnack(context, ApiClient.errorMessage(exception), error: true);
      }
    }
  }

  /// Where money received from an agent can land: the treasury, any wallet
  /// (including InstaPay) or a QR profit account. Falls back to the treasury
  /// alone if the lists cannot be loaded.
  Future<List<_Destination>> _loadDestinations() async {
    final destinations = [_Destination.treasury];
    try {
      final results = await Future.wait([
        widget.session.api.list(ApiEndpoints.wallets),
        widget.session.api.list(ApiEndpoints.accounts),
      ]);
      for (final wallet in results[0]) {
        if (wallet['active'] == false) continue;
        final type = _walletTypeLabel('${wallet['type']}');
        destinations.add(
          _Destination(
            label: type.isEmpty
                ? '${wallet['name']}'
                : '${wallet['name']} · $type',
            walletId: '${wallet['id']}',
          ),
        );
      }
      for (final account in results[1]) {
        if (account['active'] == false || account['type'] != 'profit_qr') {
          continue;
        }
        destinations.add(
          _Destination(
            label: 'حساب مكسب QR ${account['name']}',
            accountId: '${account['id']}',
          ),
        );
      }
    } catch (_) {
      // Keep the treasury so cash receipts still work.
    }
    return destinations;
  }
}

String _walletTypeLabel(String type) => switch (type) {
  'vodafone_cash' => 'Vodafone Cash',
  'orange_cash' => 'Orange Cash',
  'etisalat_cash' => 'e& cash',
  'we_pay' => 'WE Pay',
  'instapay' => 'InstaPay',
  'other_wallet' => 'محفظة أخرى',
  'wallet' => 'محفظة',
  _ => '',
};

class _Destination {
  const _Destination({required this.label, this.walletId, this.accountId});

  static const treasury = _Destination(label: 'الخزنة (كاش)');

  final String label;
  final String? walletId;
  final String? accountId;

  bool get isTreasury => walletId == null && accountId == null;

  Map<String, String> get body => {
    'walletId': ?walletId,
    'accountId': ?accountId,
  };
}

enum _CashDirection { receive, refund }

enum _MetricTone { normal, warning, deposit }

/// "عليه X" when the agent owes us, "ليه X" when we hold their money.
String _balanceLabel(num balance) => balance > 0
    ? 'عليه ${money(balance)}'
    : balance < 0
    ? 'ليه ${money(-balance)}'
    : money(0);

class _BalanceText extends StatelessWidget {
  const _BalanceText(this.value);

  final dynamic value;

  @override
  Widget build(BuildContext context) {
    final balance = num.tryParse('$value') ?? 0;
    return Text(
      _balanceLabel(balance),
      style: TextStyle(
        color: balance > 0
            ? HesbaColors.warning
            : balance < 0
            ? HesbaColors.tealDark
            : HesbaColors.muted,
        fontWeight: balance == 0 ? FontWeight.w400 : FontWeight.w600,
      ),
    );
  }
}

class _AgentCashDialog extends StatefulWidget {
  const _AgentCashDialog({
    required this.direction,
    required this.agentName,
    required this.balance,
    required this.agents,
    required this.destinations,
  });

  final _CashDirection direction;
  final List<_Destination> destinations;

  /// Null when the agent is typed in the dialog (e.g. a brand-new depositor).
  final String? agentName;
  final num? balance;
  final List<Map<String, dynamic>> agents;

  @override
  State<_AgentCashDialog> createState() => _AgentCashDialogState();
}

class _AgentCashDialogState extends State<_AgentCashDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  final _name = TextEditingController();
  late _Destination _destination = widget.destinations.first;

  bool get _refund => widget.direction == _CashDirection.refund;

  /// The row's balance, or the balance of the agent picked in the dialog
  /// (0 for a new agent).
  num get _balance {
    if (widget.balance != null) return widget.balance!;
    final key = agentSearchKey(_name.text);
    for (final agent in widget.agents) {
      if (key.isNotEmpty && agentSearchKey('${agent['agentName']}') == key) {
        return num.tryParse('${agent['balance']}') ?? 0;
      }
    }
    return 0;
  }

  /// The most that can be handed back: the deposit we hold for the agent.
  num get _maxRefund => _balance < 0 ? -_balance : 0;

  @override
  void initState() {
    super.initState();
    final suggested = _refund ? _maxRefund : (_balance > 0 ? _balance : 0);
    _amount = TextEditingController(
      text: suggested <= 0
          ? ''
          : suggested == suggested.roundToDouble()
          ? suggested.toStringAsFixed(0)
          : suggested.toStringAsFixed(2),
    );
    _amount.addListener(() => setState(() {}));
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amount.dispose();
    _name.dispose();
    super.dispose();
  }

  String get _agentName => widget.agentName ?? _name.text.trim();

  String get _where =>
      _destination.isTreasury ? 'رصيد الخزنة' : _destination.label;

  @override
  Widget build(BuildContext context) {
    final entered = parseNum(_amount.text.trim()) ?? 0;
    final extra = !_refund && _agentName.isNotEmpty
        ? entered - (_balance > 0 ? _balance : 0)
        : 0;
    return HesbaModalCard(
      title: _refund ? 'رد فلوس للمندوب' : 'استلام فلوس من مندوب',
      subtitle: widget.agentName == null
          ? 'لو المندوب عليه آجل هيتسدد الأول، والزيادة هتتسجل أمانة ليه.'
          : '${widget.agentName} · ${_balanceLabel(_balance)}',
      actions: HesbaModalActions(
        primaryLabel: _refund ? 'صرف من الخزنة' : 'تسجيل الاستلام',
        onPrimary: () {
          if (!(_formKey.currentState?.validate() ?? false)) return;
          Navigator.of(context).pop((
            agentName: _agentName,
            amount: parseNum(_amount.text.trim())!,
            destination: _destination,
          ));
        },
        onCancel: () => Navigator.of(context).pop(),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.agentName == null) ...[
              AgentPicker(controller: _name, agents: widget.agents),
              const SizedBox(height: 8),
            ],
            HesbaModalField(
              label: _refund ? 'المبلغ المردود *' : 'المبلغ المستلم *',
              child: TextFormField(
                controller: _amount,
                autofocus: widget.agentName != null,
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
                  if (_refund && amount > _maxRefund) {
                    return 'أقصى مبلغ رد هو ${money(_maxRefund)}';
                  }
                  return null;
                },
              ),
            ),
            if (!_refund) ...[
              const SizedBox(height: 14),
              HesbaModalField(
                label: 'الفلوس دخلت على *',
                child: DropdownButtonFormField<_Destination>(
                  isExpanded: true,
                  initialValue: _destination,
                  items: [
                    for (final destination in widget.destinations)
                      DropdownMenuItem(
                        value: destination,
                        child: Text(
                          destination.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(
                    () => _destination = value ?? _Destination.treasury,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            HesbaModalCallout(
              backgroundColor: _refund
                  ? HesbaColors.warningLight
                  : HesbaColors.tealLight,
              child: Text(
                _refund
                    ? 'المبلغ هيتخصم من رصيد الخزنة، وهيقل من أمانة ${widget.agentName}.'
                    : extra > 0
                    ? 'المبلغ هيتضاف على $_where. ${_balance > 0 ? 'هيتسدد الآجل بالكامل، و' : ''}الزيادة ${money(extra)} هتتسجل أمانة للمندوب.'
                    : widget.agentName == null
                    ? 'المبلغ هيتضاف على $_where.'
                    : 'المبلغ هيتضاف على $_where، وهيتخصم من آجل المندوب.',
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
    this.tone = _MetricTone.normal,
  });

  final String label;
  final String value;
  final String note;
  final _MetricTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: switch (tone) {
            _MetricTone.warning => const Color(0xFFEACF91),
            _MetricTone.deposit => HesbaColors.teal.withValues(alpha: 0.45),
            _MetricTone.normal => HesbaColors.border,
          },
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
              color: switch (tone) {
                _MetricTone.warning => HesbaColors.warning,
                _MetricTone.deposit => HesbaColors.tealDark,
                _MetricTone.normal => HesbaColors.ink,
              },
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
    required this.session,
    required this.rows,
    required this.onReceive,
    required this.onRefund,
    required this.canPay,
  });

  final bool canPay;
  final SessionController session;

  final List<dynamic> rows;
  final Future<void> Function(Map<String, dynamic> row) onReceive;
  final Future<void> Function(Map<String, dynamic> row) onRefund;

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
                DataColumn(label: Text('المستلم')),
                DataColumn(label: Text('مردود له')),
                DataColumn(label: Text('رصيد نهاية اليوم')),
                DataColumn(label: Text('الرصيد الحالي')),
                DataColumn(label: Text('عدد الحركات')),
                DataColumn(label: Text('الفلوس')),
              ],
              rows: [
                for (final item in rows)
                  DataRow(
                    cells: [
                      DataCell(Text(formatDate(item['date']))),
                      DataCell(
                        AgentNameLink(
                          session: session,
                          agentName: '${item['agentName']}',
                          style: HesbaText.tableCell.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DataCell(_BalanceText(item['openingBalance'])),
                      DataCell(Text(money(item['credit']))),
                      DataCell(Text(money(item['paid']))),
                      DataCell(Text(money(item['refunded'] ?? 0))),
                      DataCell(_BalanceText(item['closingBalance'])),
                      DataCell(_BalanceText(item['balance'])),
                      DataCell(Text('${item['movementsCount']}')),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FilledButton.icon(
                              onPressed: canPay
                                  ? () =>
                                        onReceive(item as Map<String, dynamic>)
                                  : null,
                              icon: const Icon(
                                Icons.payments_outlined,
                                size: 18,
                              ),
                              label: const Text('استلام'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed:
                                  canPay &&
                                      (num.tryParse('${item['balance']}') ??
                                              0) <
                                          0
                                  ? () => onRefund(item as Map<String, dynamic>)
                                  : null,
                              icon: const Icon(Icons.undo, size: 18),
                              label: const Text('رد للمندوب'),
                            ),
                          ],
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

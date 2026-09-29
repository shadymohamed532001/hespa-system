import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/digits.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/widgets/hesba_modal.dart';
import '../auth/session_controller.dart';
import '../../core/settings/tr.dart';
import 'profit_collection_commission.dart';

Future<bool> showExecuteHoldDialog({
  required BuildContext context,
  required SessionController session,
  required Map<String, dynamic> collection,
  required List<dynamic> accounts,
  required List<dynamic> visas,
}) async {
  return await showHesbaModal<bool>(
        context: context,
        maxWidth: 640,
        builder: (_) => _ExecuteHoldDialog(
          session: session,
          collection: collection,
          accounts: accounts,
          visas: visas,
        ),
      ) ??
      false;
}

class _WalletPart {
  String? walletId;
  final amount = TextEditingController();
}

class _ExecuteHoldDialog extends StatefulWidget {
  const _ExecuteHoldDialog({
    required this.session,
    required this.collection,
    required this.accounts,
    required this.visas,
  });

  final SessionController session;
  final Map<String, dynamic> collection;
  final List<dynamic> accounts;
  final List<dynamic> visas;

  @override
  State<_ExecuteHoldDialog> createState() => _ExecuteHoldDialogState();
}

class _ExecuteHoldDialogState extends State<_ExecuteHoldDialog> {
  final _formKey = GlobalKey<FormState>();
  final _commission = TextEditingController(text: '0');
  final _receivedAmount = TextEditingController();
  final List<_WalletPart> _parts = [];

  late String _accountId;
  List<dynamic> _wallets = [];
  List<dynamic> _agentCredits = [];
  bool _withService = false;
  bool _splitIncoming = false;
  bool _useAgentCredit = false;
  bool _saving = false;
  bool _loading = true;
  String? _error;

  num get _amount => num.tryParse('${widget.collection['amount']}') ?? 0;

  String get _agentName => '${widget.collection['agentName'] ?? ''}'.trim();

  @override
  void initState() {
    super.initState();
    _accountId = widget.accounts.isNotEmpty
        ? 'account:${widget.accounts.first['id']}'
        : 'visa:${widget.visas.first['id']}';
    _loadExtras();
  }

  @override
  void dispose() {
    _commission.dispose();
    _receivedAmount.dispose();
    for (final part in _parts) {
      part.amount.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExtras() async {
    try {
      final results = await Future.wait([
        widget.session.api
            .list(ApiEndpoints.wallets)
            .catchError((_) => <dynamic>[]),
        widget.session.api
            .list(ApiEndpoints.agentCredits)
            .catchError((_) => <dynamic>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _wallets = results[0].where((item) => item['active'] != false).toList();
        _agentCredits = results[1];
        _loading = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ApiClient.errorMessage(exception);
      });
    }
  }

  String? _sourceId(String key) =>
      key.contains(':') ? key.substring(key.indexOf(':') + 1) : key;

  bool _isVisa(String key) => key.startsWith('visa:');

  String? _accountType(String key) {
    if (_isVisa(key)) return 'purchase_visa';
    for (final account in widget.accounts) {
      if ('${account['id']}' == _sourceId(key)) return '${account['type']}';
    }
    return null;
  }

  bool get _visa => _isVisa(_accountId);
  bool get _fawry => _accountType(_accountId) == 'fawry';
  bool get _profit => _accountType(_accountId) == 'profit';
  bool get _profitQr => _accountType(_accountId) == 'profit_qr';

  num get _requiredBalance => _profitQr
      ? _amount + profitCollectionCommission(_amount)
      : _amount;

  num? get _selectedBalance {
    if (_visa) {
      for (final visa in widget.visas) {
        if ('visa:${visa['id']}' == _accountId) {
          return num.tryParse('${visa['balance']}') ?? 0;
        }
      }
      return null;
    }
    for (final account in widget.accounts) {
      if ('account:${account['id']}' == _accountId) {
        return num.tryParse('${account['balance']}') ?? 0;
      }
    }
    return null;
  }

  bool get _shortBalance {
    final balance = _selectedBalance;
    if (balance == null || _requiredBalance <= 0) return false;
    return (balance * 100).round() < (_requiredBalance * 100).round();
  }

  num _currentAgentCredit() {
    final key = _agentName.toLowerCase();
    if (key.isEmpty) return 0;
    for (final credit in _agentCredits) {
      if ('${credit['agentName']}'.trim().toLowerCase() == key) {
        return num.tryParse('${credit['balance']}') ?? 0;
      }
    }
    return 0;
  }

  num? _agentCreditChange() {
    final received = parseNum(_receivedAmount.text.trim());
    if (received == null) return null;
    return ((_amount - received) * 100).round() / 100;
  }

  num? _treasuryCash() {
    var walletTotal = 0.0;
    for (final part in _parts) {
      final amount = parseNum(part.amount.text.trim());
      if (amount == null) return null;
      walletTotal += amount;
    }
    return ((_amount - walletTotal) * 100).round() / 100;
  }

  String? _splitError() {
    if (!_splitIncoming) return null;
    if (_wallets.isEmpty) {
      return 'أضف محفظة نشطة زي فودافون كاش قبل تقسيم الداخل.';
    }
    final ids = <String>[];
    for (final part in _parts) {
      final walletId = part.walletId;
      final amount = parseNum(part.amount.text.trim());
      if (walletId == null) return 'اختر المحفظة اللي هتستلم الجزء.';
      if (amount == null || amount <= 0) return 'أدخل مبلغ المحفظة.';
      if (ids.contains(walletId)) {
        return 'المحفظة متكررة. اجمع مبلغها في سطر واحد.';
      }
      ids.add(walletId);
    }
    if (ids.isEmpty) return 'أضف جزء المحفظة.';
    final cash = _treasuryCash();
    if (cash == null || cash < 0) {
      return 'جزء المحفظة أكبر من المبلغ. الباقي بس هو اللي يفضل في الخزنة.';
    }
    return null;
  }

  void _setSplit(bool enabled) {
    setState(() {
      _splitIncoming = enabled;
      if (enabled) {
        _useAgentCredit = false;
        _receivedAmount.clear();
        if (_parts.isEmpty) _parts.add(_WalletPart());
      }
      _error = null;
    });
  }

  void _setAgentCredit(bool enabled) {
    setState(() {
      _useAgentCredit = enabled;
      if (enabled) {
        _splitIncoming = false;
        if (_receivedAmount.text.trim().isEmpty) {
          _receivedAmount.text = _amount == _amount.roundToDouble()
              ? _amount.toStringAsFixed(0)
              : _amount.toString();
        }
      } else {
        _receivedAmount.clear();
      }
      _error = null;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_shortBalance) {
      setState(() => _error = 'رصيد الحساب مش كفاية للمبلغ.');
      return;
    }
    final splitError = _splitError();
    if (splitError != null) {
      setState(() => _error = splitError);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final request = <String, dynamic>{
      if (_visa)
        'purchaseVisaId': _sourceId(_accountId)
      else
        'accountId': _sourceId(_accountId),
      if (_visa || _profit) 'withService': _withService,
      'commission': _fawry || _profitQr || _visa || _profit
          ? 0
          : parseNum(_commission.text) ?? 0,
      if (_useAgentCredit) ...{
        'useAgentCredit': true,
        'cashAmount': parseNum(_receivedAmount.text.trim())!,
      },
      if (_splitIncoming) ...{
        'cashAmount': _treasuryCash(),
        'incomingParts': [
          for (final part in _parts)
            {
              'walletId': part.walletId,
              'amount': parseNum(part.amount.text.trim())!,
            },
        ],
      },
    };
    try {
      await widget.session.api.post(
        ApiEndpoints.executeCollection('${widget.collection['id']}'),
        request,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = ApiClient.errorMessage(exception);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final collection = widget.collection;
    return HesbaModalCard(
      title: 'تنفيذ المعلّق ${collection['reference']}',
      subtitle:
          '${collection['companyName']} · $_agentName · ${money(collection['amount'])}',
      actions: HesbaModalActions(
        primaryLabel: 'تأكيد التنفيذ',
        primaryEnabled: !_saving && !_loading && !_shortBalance,
        cancelEnabled: !_saving,
        onPrimary: _submit,
        onCancel: () => Navigator.of(context).pop(false),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HesbaModalField(
              label: 'الحساب المستخدم *',
              child: DropdownButtonFormField<String>(
                initialValue: _accountId,
                isExpanded: true,
                decoration: const InputDecoration(),
                items: [
                  for (final account in widget.accounts)
                    DropdownMenuItem(
                      value: 'account:${account['id']}',
                      child: _sourceOption(
                        '${account['name']} — ${money(account['balance'])}',
                        num.tryParse('${account['balance']}') ?? 0,
                        account['type'] == 'profit_qr'
                            ? _amount + profitCollectionCommission(_amount)
                            : _amount,
                      ),
                    ),
                  for (final visa in widget.visas)
                    DropdownMenuItem(
                      value: 'visa:${visa['id']}',
                      child: _sourceOption(
                        'فيزا مشتريات — ${visa['name']} — ${money(visa['balance'])}',
                        num.tryParse('${visa['balance']}') ?? 0,
                        _amount,
                      ),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                        _accountId = value!;
                        _error = null;
                      }),
              ),
            ),
            if (_shortBalance) ...[
              const SizedBox(height: 10),
              _shortBalanceNotice(),
            ],
            const SizedBox(height: 18),
            if (_visa) _serviceChoices(visa: true),
            if (_profit) _serviceChoices(visa: false),
            if (_profitQr)
              HesbaModalCallout(
                child: Text(
                  'خصم مكسب عند التوريد ${money(profitCollectionCommission(_amount))} — ٤ جنيه لكل ألف، ويُخصم فوق مبلغ العملية.',
                ),
              ),
            if (!_visa && !_profit && !_profitQr && !_fawry)
              HesbaModalField(
                label: tr(ar: 'العمولة', en: 'Commission'),
                child: TextFormField(
                  controller: _commission,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [ArabicDigitsFormatter()],
                  decoration: const InputDecoration(),
                  validator: (value) {
                    final number = parseNum(
                      value?.trim().isEmpty ?? true ? '0' : value!.trim(),
                    );
                    return number == null || number < 0
                        ? 'أدخل عمولة صحيحة'
                        : null;
                  },
                ),
              ),
            if (_fawry)
              const HesbaModalCallout(
                child: Text(
                  'حساب فوري: العمولة مش بتتسجل مع التنفيذ. الأدمن بيكتب النزلة في اليوم التالي.',
                ),
              ),
            const SizedBox(height: 8),
            _agentCreditSection(),
            const SizedBox(height: 4),
            _splitSection(),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: HesbaColors.red)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sourceOption(String label, num balance, num needed) {
    final short =
        needed > 0 && (balance * 100).round() < (needed * 100).round();
    return Text.rich(
      TextSpan(
        children: [
          if (short)
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsetsDirectional.only(end: 6),
                child: Icon(Icons.error, color: HesbaColors.red, size: 18),
              ),
            ),
          TextSpan(text: short ? '$label · رصيد غير كافٍ' : label),
        ],
      ),
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: short ? HesbaColors.red : HesbaColors.ink,
        fontWeight: short ? FontWeight.w700 : FontWeight.w400,
      ),
    );
  }

  Widget _shortBalanceNotice() {
    final balance = _selectedBalance ?? 0;
    return HesbaModalCallout(
      backgroundColor: HesbaColors.redLight,
      borderColor: HesbaColors.red,
      textStyle: const TextStyle(
        color: HesbaColors.red,
        fontWeight: FontWeight.w700,
        height: 1.45,
      ),
      child: Text(
        'رصيد غير كافٍ. الحساب فيه ${money(balance)} والعملية محتاجة ${money(_requiredBalance)}. مش هينفع يتأكد التنفيذ قبل ما تختار حساب يغطي المبلغ.',
      ),
    );
  }

  Widget _serviceChoices({required bool visa}) {
    final value = purchaseVisaCollectionProfit(_amount, _withService);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: const Text('من غير خدمة · ٢٠'),
                selected: !_withService,
                onSelected: _saving
                    ? null
                    : (_) => setState(() => _withService = false),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ChoiceChip(
                label: const Text('بخدمة · ١٣'),
                selected: _withService,
                onSelected: _saving
                    ? null
                    : (_) => setState(() => _withService = true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        HesbaModalCallout(
          child: Text(
            visa
                ? 'المكسب ${money(value)} بيدخل الخزنة، والفيزا بتنقص بالمبلغ.'
                : 'العمولة ${money(value)} بتتسجل على حساب المكسب، والحساب بينقص بالمبلغ.',
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _agentCreditSection() {
    final change = _agentCreditChange();
    final current = _currentAgentCredit();
    final name = _agentName.isEmpty ? 'المندوب' : _agentName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          value: _useAgentCredit,
          title: const Text('آجل المندوب'),
          subtitle: const Text(
            'فعّلها لو المستلم فعليًا أقل من مبلغ التوريد أو أكتر لتسديد آجل قديم. الكاش الكامل دخل الخزنة وقت التسجيل، والفرق بيتظبط عند التنفيذ.',
          ),
          onChanged: _saving ? null : (value) => _setAgentCredit(value ?? false),
        ),
        if (_useAgentCredit) ...[
          const SizedBox(height: 8),
          HesbaModalField(
            label: 'المبلغ المستلم فعليًا *',
            child: TextFormField(
              controller: _receivedAmount,
              keyboardType: TextInputType.number,
              inputFormatters: const [ArabicDigitsFormatter()],
              decoration: const InputDecoration(),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                if (!_useAgentCredit) return null;
                final received = parseNum(value?.trim() ?? '');
                if (received == null || received < 0) {
                  return 'أدخل المبلغ المستلم فعليًا';
                }
                if (received > _amount) {
                  final repayment = received - _amount;
                  if (current <= 0) return 'المندوب ده ملوش آجل يتسدد';
                  if (repayment > current) {
                    return 'أقصى مبلغ تسديد هو ${money(current)}';
                  }
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 10),
          HesbaModalCallout(
            child: Text(
              change == null
                  ? 'اكتب المبلغ المستلم عشان يظهر فرق الآجل.'
                  : change > 0
                  ? 'هيتسجل على $name آجل ${money(change)}، ويخرج الفرق من الخزنة. الرصيد بعد العملية ${money(current + change)}.'
                  : change < 0
                  ? 'هيتسدد من الآجل ${money(-change)}. الرصيد بعد العملية ${money(current + change)}.'
                  : 'المبلغ كامل، مفيش تغيير في الآجل ولا في الخزنة.',
            ),
          ),
        ],
      ],
    );
  }

  Widget _splitSection() {
    if (!_loading && _wallets.isEmpty) {
      return const HesbaModalCallout(
        child: Text(
          'عشان تقسّم الداخل بين الخزنة ومحفظة، أضف محفظة نشطة زي فودافون كاش.',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          value: _splitIncoming,
          title: const Text('تقسيم المبلغ الداخل'),
          subtitle: const Text(
            'اكتب جزء المحفظة بس. الكاش دخل الخزنة وقت تسجيل المعلّق، وجزء المحفظة بيتحول من الخزنة للمحفظة.',
          ),
          onChanged: _saving || _loading
              ? null
              : (value) => _setSplit(value ?? false),
        ),
        if (_splitIncoming) ...[
          for (var index = 0; index < _parts.length; index++) _partRow(index),
          if (_treasuryCash() case final cash?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                cash < 0
                    ? 'جزء المحفظة أكبر من المبلغ.'
                    : cash == 0
                    ? 'المبلغ كله يتحول للمحفظة ويخرج من الخزنة.'
                    : 'الباقي ${money(cash)} يفضل في الخزنة.',
                style: TextStyle(
                  color: cash < 0 ? HesbaColors.red : HesbaColors.teal,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _saving || _parts.length >= 5
                  ? null
                  : () => setState(() => _parts.add(_WalletPart())),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إضافة محفظة'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _partRow(int index) {
    final part = _parts[index];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: HesbaModalField(
              label: 'المحفظة *',
              child: DropdownButtonFormField<String>(
                key: ValueKey('hold-wallet-$index-${part.walletId}'),
                initialValue: part.walletId,
                isExpanded: true,
                decoration: const InputDecoration(),
                hint: const Text('اختر المحفظة'),
                items: [
                  for (final wallet in _wallets)
                    DropdownMenuItem(
                      value: '${wallet['id']}',
                      child: Text(
                        '${wallet['name']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => part.walletId = value),
                validator: (_) => part.walletId == null ? 'اختر المحفظة' : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: HesbaModalField(
              label: 'مبلغ المحفظة *',
              child: TextFormField(
                controller: part.amount,
                keyboardType: TextInputType.number,
                inputFormatters: const [ArabicDigitsFormatter()],
                decoration: const InputDecoration(),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final number = parseNum(value?.trim() ?? '');
                  return number == null || number <= 0
                      ? 'أدخل مبلغ المحفظة'
                      : null;
                },
              ),
            ),
          ),
          if (_parts.length > 1)
            IconButton(
              tooltip: 'حذف',
              onPressed: _saving
                  ? null
                  : () => setState(() {
                      _parts.removeAt(index).amount.dispose();
                    }),
              icon: const Icon(Icons.close, size: 18),
            ),
        ],
      ),
    );
  }
}

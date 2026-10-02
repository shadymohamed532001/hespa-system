import 'package:flutter/material.dart';

import 'company_catalog.dart';
import 'profit_collection_commission.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/digits.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/widgets/hesba_modal.dart';
import '../auth/session_controller.dart';
import '../../core/settings/tr.dart';

Future<bool> showReceiveCollectionDialog({
  required BuildContext context,
  required SessionController session,
}) async {
  return await showHesbaModal<bool>(
        context: context,
        builder: (_) => _ReceiveCollectionDialog(session: session),
      ) ??
      false;
}

class _ReceiveCollectionDialog extends StatefulWidget {
  const _ReceiveCollectionDialog({required this.session});

  final SessionController session;

  @override
  State<_ReceiveCollectionDialog> createState() =>
      _ReceiveCollectionDialogState();
}

class _ReceiveCollectionDialogState extends State<_ReceiveCollectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _agentName = TextEditingController();
  final _company = TextEditingController();
  final _amount = TextEditingController();
  final _receivedAmount = TextEditingController();
  final _commission = TextEditingController(text: '0');
  final List<_WalletPart> _parts = [];

  List<dynamic> _accounts = [];
  List<dynamic> _visas = [];
  List<dynamic> _wallets = [];
  List<dynamic> _agentCredits = [];
  String _mode = 'immediate';
  String? _accountId;
  bool _withService = false;
  String? _companyName;
  TimeOfDay _receivedAt = TimeOfDay.now();
  bool _loadingAccounts = true;
  bool _splitIncoming = false;
  bool _useAgentCredit = false;
  bool _saving = false;
  String? _error;

  bool get _isImmediate => _mode == 'immediate';

  bool get _selectedIsFawry => _selectedAccountType == 'fawry';

  bool get _selectedIsProfit => _selectedAccountType == 'profit';

  bool get _selectedIsProfitQr => _selectedAccountType == 'profit_qr';

  bool get _selectedIsVisa => _accountId?.startsWith('visa:') ?? false;

  num get _requiredBalance {
    final amount = parseNum(_amount.text.trim()) ?? 0;
    if (_selectedIsProfit || _selectedIsProfitQr) {
      return amount + profitCollectionCommission(amount);
    }
    return amount;
  }

  num? get _selectedBalance {
    if (_selectedIsVisa) {
      for (final item in _visas) {
        if ('visa:${item['id']}' == _accountId) {
          return num.tryParse('${item['balance']}') ?? 0;
        }
      }
      return null;
    }
    for (final item in _accounts) {
      if ('account:${item['id']}' == _accountId) {
        return num.tryParse('${item['balance']}') ?? 0;
      }
    }
    return null;
  }

  bool get _shortBalance {
    if (!_isImmediate) return false;
    final balance = _selectedBalance;
    if (balance == null || _requiredBalance <= 0) return false;
    return (balance * 100).round() < (_requiredBalance * 100).round();
  }

  String? get _selectedSourceId {
    final key = _accountId;
    if (key == null || !key.contains(':')) return key;
    return key.substring(key.indexOf(':') + 1);
  }

  String? get _selectedAccountType {
    if (_selectedIsVisa) return 'purchase_visa';
    for (final item in _accounts) {
      if ('${item['id']}' == _selectedSourceId) return '${item['type']}';
    }
    return null;
  }

  List<String> get _companyNames {
    final names = <String>[...kCompanyCatalog];
    for (final item in _accounts) {
      if (item['type'] != 'company') continue;
      final name = '${item['name']}'.trim();
      if (name.isEmpty || names.contains(name)) continue;
      names.add(name);
    }
    return names;
  }

  @override
  void initState() {
    super.initState();
    _company.addListener(_syncCompanySelection);
    _agentName.addListener(_onAgentNameChanged);
    _amount.addListener(_onMoneyChanged);
    _receivedAmount.addListener(_onMoneyChanged);
    _loadAccounts();
  }

  @override
  void dispose() {
    _company.removeListener(_syncCompanySelection);
    _agentName.removeListener(_onAgentNameChanged);
    _amount.removeListener(_onMoneyChanged);
    _receivedAmount.removeListener(_onMoneyChanged);
    _agentName.dispose();
    _company.dispose();
    _amount.dispose();
    _receivedAmount.dispose();
    _commission.dispose();
    for (final part in _parts) {
      part.amount.removeListener(_onMoneyChanged);
      part.amount.dispose();
    }
    super.dispose();
  }

  void _onMoneyChanged() {
    _syncProfitCommission();
    if (mounted) setState(() {});
  }

  void _onAgentNameChanged() {
    if (mounted && _useAgentCredit) setState(() {});
  }

  void _syncProfitCommission() {
    if (_selectedIsProfitQr) {
      _commission.text = '0';
      return;
    }
    if (!_selectedIsProfit) return;
    final amount = parseNum(_amount.text.trim()) ?? 0;
    final text = formatProfitCollectionCommission(amount);
    if (_commission.text == text) return;
    _commission.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _syncCompanySelection() {
    final typed = _company.text.trim();
    _companyName = _companyNames.contains(typed) ? typed : null;
  }

  Future<void> _loadAccounts() async {
    try {
      final walletsFuture = widget.session.api
          .list(ApiEndpoints.wallets)
          .catchError((_) => <dynamic>[]);
      final creditsFuture = widget.session.api
          .list(ApiEndpoints.agentCredits)
          .catchError((_) => <dynamic>[]);
      final visasFuture = widget.session.api
          .list(ApiEndpoints.purchaseVisas)
          .catchError((_) => <dynamic>[]);
      final results = await Future.wait([
        widget.session.api.list(ApiEndpoints.accounts),
        walletsFuture,
        creditsFuture,
        visasFuture,
      ]);
      if (!mounted) return;
      final accounts = results[0];
      setState(() {
        _accounts = accounts.where((item) => item['active'] != false).toList();
        _wallets = results[1].where((item) => item['active'] != false).toList();
        _agentCredits = results[2];
        _visas = results[3].where((item) => item['active'] != false).toList();
        _accountId = _accounts.isNotEmpty
            ? 'account:${_accounts.first['id']}'
            : _visas.isNotEmpty
            ? 'visa:${_visas.first['id']}'
            : null;
        _loadingAccounts = false;
        _syncProfitCommission();
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _loadingAccounts = false;
        _error = ApiClient.errorMessage(exception);
      });
    }
  }

  Future<void> _pickTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: _receivedAt,
      helpText: 'اختر وقت الاستلام',
      cancelText: tr(ar: 'إلغاء', en: 'Cancel'),
      confirmText: 'اختيار',
    );
    if (value != null && mounted) setState(() => _receivedAt = value);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isImmediate && _selectedSourceId == null) {
      setState(() => _error = 'لا يوجد حساب متاح لتنفيذ العملية فورًا.');
      return;
    }
    if (_isImmediate && _shortBalance) {
      setState(() => _error = 'رصيد الحساب مش كفاية للمبلغ.');
      return;
    }
    if (_splitIncoming) {
      final splitError = _splitError();
      if (splitError != null) {
        setState(() => _error = splitError);
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final now = DateTime.now();
    final receivedAt = DateTime(
      now.year,
      now.month,
      now.day,
      _receivedAt.hour,
      _receivedAt.minute,
    );
    final request = <String, dynamic>{
      'agentName': _recordedAgentName(),
      'companyName': _companyName!,
      'amount': parseNum(_amount.text.trim())!,
      'executionMode': _mode,
      'receivedAt': receivedAt.toIso8601String(),
      'commission':
          _isImmediate &&
              !_selectedIsFawry &&
              !_selectedIsVisa &&
              !_selectedIsProfit &&
              !_selectedIsProfitQr
          ? parseNum(_commission.text.trim()) ?? 0
          : 0,
      if (_isImmediate && _selectedIsVisa) ...{
        'purchaseVisaId': _selectedSourceId,
        'withService': _withService,
      } else if (_isImmediate) ...{
        'accountId': _selectedSourceId,
      },
      if (_useAgentCredit) ...{
        'useAgentCredit': true,
        'cashAmount': parseNum(_receivedAmount.text.trim())!,
      },
      if (_splitIncoming) ..._splitPayload(),
    };

    try {
      await widget.session.api.post(ApiEndpoints.receiveCollection, request);
      if (mounted) Navigator.of(context).pop(true);
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = ApiClient.errorMessage(exception);
      });
    }
  }

  String _recordedAgentName() {
    if (!_isImmediate || _useAgentCredit) return _agentName.text.trim();
    final username = widget.session.username?.trim() ?? '';
    return username.length >= 2 ? username : 'موظف';
  }

  String _requiredText(String? value) {
    return value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : '';
  }

  String? _agentNameValidator(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'اكتب اسم المندوب';
    if (name.length < 2) return 'اسم المندوب لازم يكون حرفين على الأقل';
    if (name.length > 150) return 'اسم المندوب طويل جدًا';
    return null;
  }

  String _searchKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه');
  }

  void _setSplit(bool enabled) {
    if (enabled && _parts.isEmpty) _addPart(rebuild: false);
    setState(() {
      _splitIncoming = enabled && _isImmediate;
      _error = null;
    });
  }

  void _setAgentCredit(bool enabled) {
    setState(() {
      _useAgentCredit = enabled;
      if (enabled) {
        _splitIncoming = false;
        if (_receivedAmount.text.trim().isEmpty) {
          _receivedAmount.text = _amount.text.trim();
        }
      } else {
        _receivedAmount.clear();
      }
      _error = null;
    });
  }

  num _currentAgentCredit() {
    final key = _agentCreditKey(_agentName.text);
    if (key.isEmpty) return 0;
    for (final credit in _agentCredits) {
      if (_agentCreditKey('${credit['agentName']}') == key) {
        return num.tryParse('${credit['balance']}') ?? 0;
      }
    }
    return 0;
  }

  String _agentCreditKey(String value) => value.trim().toLowerCase();

  num? _agentCreditChange() {
    final amount = parseNum(_amount.text.trim());
    final received = parseNum(_receivedAmount.text.trim());
    if (amount == null || received == null) return null;
    return ((amount - received) * 100).round() / 100;
  }

  void _addPart({bool rebuild = true}) {
    final part = _WalletPart();
    part.amount.addListener(_onMoneyChanged);
    _parts.add(part);
    if (rebuild) setState(() {});
  }

  void _removePart(int index) {
    final part = _parts.removeAt(index);
    part.amount.removeListener(_onMoneyChanged);
    part.amount.dispose();
    setState(() {});
  }

  Map<String, dynamic>? _walletById(String? id) {
    if (id == null) return null;
    for (final wallet in _wallets) {
      if ('${wallet['id']}' == id) return wallet as Map<String, dynamic>;
    }
    return null;
  }

  String _walletLabel(Map<String, dynamic> wallet) {
    final type = _walletTypeLabel('${wallet['type']}');
    final name = '${wallet['name']}';
    final balance = money(wallet['balance']);
    return type.isEmpty ? '$name — $balance' : '$name · $type — $balance';
  }

  String _walletTypeLabel(String type) => switch (type) {
    'vodafone_cash' => 'Vodafone Cash',
    'orange_cash' => 'Orange Cash',
    'etisalat_cash' => 'e& cash (اتصالات كاش)',
    'we_pay' => 'WE Pay',
    'instapay' => 'InstaPay',
    'other_wallet' => 'محفظة أخرى',
    'wallet' => 'محفظة',
    _ => '',
  };

  num? _treasuryCash() {
    final total = parseNum(_amount.text.trim());
    if (total == null) return null;
    var walletTotal = 0.0;
    for (final part in _parts) {
      final amount = parseNum(part.amount.text.trim());
      if (amount == null) return null;
      walletTotal += amount;
    }
    return ((total - walletTotal) * 100).round() / 100;
  }

  String? _splitError() {
    if (!_splitIncoming) return null;
    if (_wallets.isEmpty) {
      return 'أضف محفظة نشطة زي فودافون كاش قبل تقسيم الداخل.';
    }
    final total = parseNum(_amount.text.trim());
    if (total == null || total <= 0) return 'أدخل المبلغ الكلي.';
    final ids = <String>[];
    for (final part in _parts) {
      final walletId = part.walletId;
      final amount = parseNum(part.amount.text.trim());
      if (walletId == null || _walletById(walletId) == null) {
        return 'اختر المحفظة اللي هتستلم الجزء.';
      }
      if (amount == null || amount <= 0) return 'أدخل مبلغ المحفظة.';
      if (ids.contains(walletId)) {
        return 'المحفظة متكررة. اجمع مبلغها في سطر واحد.';
      }
      ids.add(walletId);
    }
    if (ids.isEmpty) return 'أضف جزء المحفظة.';
    final cash = _treasuryCash();
    if (cash == null || cash < 0) {
      return 'جزء المحفظة أكبر من المبلغ. الباقي بس هو اللي يدخل الخزنة.';
    }
    return null;
  }

  Map<String, dynamic> _splitPayload() {
    return {
      'cashAmount': _treasuryCash(),
      'incomingParts': [
        for (final part in _parts)
          {
            'walletId': part.walletId,
            'amount': parseNum(part.amount.text.trim())!,
          },
      ],
    };
  }

  String _flowText() {
    if (!_isImmediate) {
      return 'يدخل الكاش الخزنة لكنه يظل محجوزًا كالتزام حتى تنفيذ العملية لاحقًا.';
    }
    if (_useAgentCredit) {
      final amount = parseNum(_amount.text.trim()) ?? 0;
      final received = parseNum(_receivedAmount.text.trim()) ?? 0;
      final change = _agentCreditChange() ?? 0;
      final action = change > 0
          ? 'ويتسجل على المندوب آجل ${money(change)}.'
          : change < 0
          ? 'ويتسدد من آجل المندوب ${money(-change)}.'
          : 'ومفيش تغيير في آجل المندوب.';
      return 'يتسحب ${money(amount)} من حساب التنفيذ، ويدخل الخزنة ${money(received)}، $action';
    }
    if (_splitIncoming && _splitError() == null) {
      final total = parseNum(_amount.text.trim())!;
      final cash = _treasuryCash()!;
      final wallets = _parts
          .map((part) {
            final wallet = _walletById(part.walletId);
            final name = wallet == null ? 'المحفظة' : '${wallet['name']}';
            return '$name ${money(part.amount.text.trim())}';
          })
          .join('، ');
      final treasury = cash == 0
          ? 'مفيش كاش يدخل الخزنة.'
          : 'يدخل الخزنة ${money(cash)}.';
      return 'يتسحب ${money(total)} من حساب التنفيذ. $treasury يدخل $wallets.';
    }
    if (_selectedIsVisa) {
      final amount = parseNum(_amount.text.trim()) ?? 0;
      if (!widget.session.isAdmin) {
        return 'يتسحب ${money(amount)} من الفيزا ويدخل الكاش الخزنة.';
      }
      final profit = purchaseVisaCollectionProfit(amount, _withService);
      final service = _withService
          ? 'بخدمة، والمكسب ١٣ جنيه لكل ألف (${money(profit)}).'
          : 'من غير خدمة، والمكسب ٢٠ جنيه لكل ألف (${money(profit)}).';
      return 'يتسحب ${money(amount)} من فيزا المشتريات، ويدخل الكاش الخزنة، ويتضاف المكسب على الخزنة. $service';
    }
    if (_selectedIsFawry) {
      return 'يدخل الكاش الخزنة وينخفض رصيد حساب فوري. العمولة بتتسجل نزلة في اليوم التالي.';
    }
    if (_selectedIsProfit) {
      return _profitDebitMessage();
    }
    if (_selectedIsProfitQr) {
      if (!widget.session.isAdmin) {
        return 'يتسحب إجمالي ${money(_requiredBalance)} من حساب مكسب QR.';
      }
      final amount = parseNum(_amount.text.trim()) ?? 0;
      final fee = profitCollectionCommission(amount);
      return 'يدخل الكاش الخزنة، ويُخصم من حساب مكسب QR المبلغ وخصم مكسب ${money(fee)} (٤ جنيه لكل ألف).';
    }
    return 'يدخل الكاش الخزنة، وينخفض رصيد الحساب المستخدم، وتُسجل العمولة في نفس اللحظة.';
  }

  @override
  Widget build(BuildContext context) {
    return HesbaModalCard(
      title: tr(ar: 'استلام كاش من مندوب', en: 'Receive cash from agent'),
      subtitle:
          'اختر تنفيذ العملية فورًا أو الاحتفاظ بها كمعلّق للتنفيذ لاحقًا.',
      actions: HesbaModalActions(
        primaryLabel: _isImmediate ? 'استلام وتنفيذ الآن' : 'تسجيل كمعلّق',
        primaryEnabled: !_saving && !(_isImmediate && _shortBalance),
        cancelEnabled: !_saving,
        onPrimary: _submit,
        onCancel: () => Navigator.of(context).pop(false),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 520;
                final width = twoColumns
                    ? (constraints.maxWidth - 24) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 24,
                  runSpacing: 20,
                  children: [
                    SizedBox(width: width, child: _modeField()),
                    if (!_isImmediate || _useAgentCredit)
                      SizedBox(width: width, child: _agentField()),
                    SizedBox(width: width, child: _companyField()),
                    SizedBox(
                      width: width,
                      child: _textField(
                        label: tr(ar: 'المبلغ *', en: 'Amount *'),
                        controller: _amount,
                        fieldKey: const ValueKey('collection-amount'),
                        numeric: true,
                        validator: (value) {
                          final number = parseNum(value?.trim() ?? '');
                          return number == null || number <= 0
                              ? tr(
                                  ar: 'أدخل مبلغًا صحيحًا',
                                  en: 'Enter a valid amount',
                                )
                              : null;
                        },
                      ),
                    ),
                    SizedBox(width: width, child: _timeField()),
                    if (_isImmediate)
                      SizedBox(width: width, child: _accountField()),
                    if (_isImmediate && _shortBalance)
                      SizedBox(
                        width: constraints.maxWidth,
                        child: _shortBalanceNotice(),
                      ),
                    if (_isImmediate && _selectedIsVisa)
                      SizedBox(
                        width: constraints.maxWidth,
                        child: _visaServiceField(),
                      ),
                    if (_isImmediate && _selectedIsProfit)
                      SizedBox(
                        width: constraints.maxWidth,
                        child: _profitDebitNotice(),
                      ),
                    if (_isImmediate &&
                        _selectedIsProfitQr &&
                        widget.session.isAdmin)
                      SizedBox(
                        width: width,
                        child: HesbaModalCallout(
                          child: Text(
                            'خصم مكسب عند التوريد: ${money(profitCollectionCommission(parseNum(_amount.text.trim()) ?? 0))} — ٤ جنيه لكل ألف، ويُخصم فوق مبلغ العملية.',
                          ),
                        ),
                      )
                    else if (_isImmediate &&
                        widget.session.isAdmin &&
                        !_selectedIsFawry &&
                        !_selectedIsVisa &&
                        !_selectedIsProfit)
                      SizedBox(
                        width: width,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _textField(
                              label: tr(ar: 'العمولة', en: 'Commission'),
                              controller: _commission,
                              numeric: true,
                              validator: (value) {
                                final number = parseNum(
                                  value?.trim().isEmpty ?? true
                                      ? '0'
                                      : value!.trim(),
                                );
                                return number == null || number < 0
                                    ? tr(
                                        ar: 'أدخل عمولة صحيحة',
                                        en: 'Enter a valid commission',
                                      )
                                    : null;
                              },
                            ),
                          ],
                        ),
                      ),
                    if (_isImmediate && _selectedIsFawry)
                      SizedBox(
                        width: width,
                        child: const HesbaModalCallout(
                          child: Text(
                            'حساب فوري: العمولة مش بتتسجل مع العملية. الأدمن بيكتب النزلة في اليوم التالي.',
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            if (_isImmediate) ...[
              const SizedBox(height: 16),
              _agentCreditSection(),
              if (!_useAgentCredit) ...[
                const SizedBox(height: 8),
                _splitSection(),
              ],
            ],
            const SizedBox(height: 18),
            HesbaModalCallout(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: _isImmediate ? 'تنفيذ فوري: ' : 'معلّق: ',
                      style: const TextStyle(fontWeight: FontWeight.w400),
                    ),
                    TextSpan(text: _flowText()),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: HesbaColors.redLight,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: HesbaColors.red),
                ),
              ),
            ],
            if (_saving) ...[
              const SizedBox(height: 12),
              const Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _agentField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _textField(
          label: 'اسم المندوب *',
          controller: _agentName,
          fieldKey: const ValueKey('agent-name'),
          validator: _agentNameValidator,
        ),
        if (_useAgentCredit && _agentCredits.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('اختار مديون حالي أو اكتب اسم جديد', style: HesbaText.caption),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final credit in _agentCredits)
                ActionChip(
                  label: Text(
                    '${credit['agentName']} · ${money(credit['balance'])}',
                  ),
                  onPressed: _saving
                      ? null
                      : () {
                          final name = '${credit['agentName']}';
                          _agentName.value = TextEditingValue(
                            text: name,
                            selection: TextSelection.collapsed(
                              offset: name.length,
                            ),
                          );
                        },
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _agentCreditSection() {
    final change = _agentCreditChange();
    final current = _currentAgentCredit();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            value: _useAgentCredit,
            title: const Text('آجل المندوب'),
            subtitle: const Text(
              'فعّلها لو المندوب دفع أقل من مبلغ التوريد أو دفع زيادة لتسديد آجل قديم.',
            ),
            onChanged: _saving
                ? null
                : (value) => _setAgentCredit(value ?? false),
          ),
        ),
        if (_useAgentCredit) ...[
          const SizedBox(height: 10),
          _textField(
            label: 'المبلغ المستلم فعليًا *',
            controller: _receivedAmount,
            fieldKey: const ValueKey('received-amount'),
            numeric: true,
            validator: (value) {
              final received = parseNum(value?.trim() ?? '');
              final amount = parseNum(_amount.text.trim());
              if (received == null || received < 0) {
                return 'أدخل المبلغ المستلم فعليًا';
              }
              if (amount != null && received > amount) {
                final repayment = received - amount;
                if (current <= 0) return 'المندوب ده ملوش آجل يتسدد';
                if (repayment > current) {
                  return 'أقصى مبلغ تسديد هو ${money(current)}';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          HesbaModalCallout(
            child: Text(
              change == null
                  ? 'اكتب مبلغ العملية والمبلغ المستلم عشان يظهر فرق الآجل.'
                  : change > 0
                  ? 'هيتسجل على ${_agentName.text.trim().isEmpty ? 'المندوب' : _agentName.text.trim()} آجل ${money(change)}. الرصيد بعد العملية ${money(current + change)}.'
                  : change < 0
                  ? 'هيتسدد من الآجل ${money(-change)}. الرصيد بعد العملية ${money(current + change)}.'
                  : 'المبلغ كامل، مفيش آجل جديد ولا تسديد.',
            ),
          ),
        ],
      ],
    );
  }

  Widget _splitSection() {
    if (_wallets.isEmpty) {
      return const HesbaModalCallout(
        child: Text(
          'عشان تقسّم الداخل بين الخزنة ومحفظة، أضف محفظة نشطة زي فودافون كاش.',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            value: _splitIncoming,
            title: const Text('تقسيم المبلغ الداخل'),
            subtitle: const Text(
              'اكتب جزء المحفظة بس. الباقي من المبلغ يدخل الخزنة، والمبلغ كله يتسحب من حساب التنفيذ.',
            ),
            onChanged: _saving ? null : (value) => _setSplit(value ?? false),
          ),
        ),
        if (_splitIncoming) ...[
          const SizedBox(height: 8),
          for (var index = 0; index < _parts.length; index++) _partRow(index),
          if (_treasuryCash() case final cash?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                cash < 0
                    ? 'جزء المحفظة أكبر من المبلغ.'
                    : cash == 0
                    ? 'المبلغ كله يدخل المحفظة.'
                    : 'الباقي ${money(cash)} يدخل الخزنة.',
                style: TextStyle(
                  color: cash < 0 ? HesbaColors.red : HesbaColors.teal,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _saving || _parts.length >= 5 ? null : _addPart,
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
                key: ValueKey('wallet-$index-${part.walletId}'),
                initialValue: part.walletId,
                isExpanded: true,
                decoration: const InputDecoration(),
                hint: const Text('اختر المحفظة'),
                items: [
                  for (final wallet in _wallets)
                    DropdownMenuItem(
                      value: '${wallet['id']}',
                      child: Text(
                        _walletLabel(wallet as Map<String, dynamic>),
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
            child: _textField(
              label: 'مبلغ المحفظة *',
              controller: part.amount,
              numeric: true,
              validator: (value) {
                final number = parseNum(value?.trim() ?? '');
                return number == null || number <= 0
                    ? 'أدخل مبلغ المحفظة'
                    : null;
              },
            ),
          ),
          if (_parts.length > 1)
            IconButton(
              tooltip: 'حذف',
              onPressed: _saving ? null : () => _removePart(index),
              icon: const Icon(Icons.close, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _modeField() {
    return HesbaModalField(
      label: 'طريقة التنفيذ *',
      child: DropdownButtonFormField<String>(
        initialValue: _mode,
        isExpanded: true,
        decoration: const InputDecoration(),
        items: const [
          DropdownMenuItem(
            value: 'immediate',
            child: Text('تنفيذ العملية الآن'),
          ),
          DropdownMenuItem(
            value: 'hold',
            child: Text('تسجيل كمعلّق وتنفيذ لاحقًا'),
          ),
        ],
        onChanged: _saving
            ? null
            : (value) => setState(() {
                _mode = value ?? 'immediate';
                if (_mode != 'immediate') {
                  _splitIncoming = false;
                  _useAgentCredit = false;
                  _receivedAmount.clear();
                }
                _error = null;
              }),
      ),
    );
  }

  Widget _companyField() {
    final names = _companyNames;
    return FormField<String>(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (_) {
        if (_loadingAccounts) {
          return tr(ar: 'جارٍ تحميل الشركات', en: 'Loading companies');
        }
        if (names.isEmpty) {
          return tr(
            ar: 'لا توجد شركات في القائمة',
            en: 'No companies yet. Add a company account first',
          );
        }
        if (_companyName == null) {
          return tr(
            ar: 'اختر شركة من القائمة',
            en: 'Choose a company from the list',
          );
        }
        return null;
      },
      builder: (field) {
        return HesbaModalField(
          label: tr(ar: 'الشركة *', en: 'Company *'),
          child: DropdownMenu<String>(
            controller: _company,
            enabled: !_saving && !_loadingAccounts,
            enableFilter: true,
            enableSearch: true,
            requestFocusOnTap: true,
            expandedInsets: EdgeInsets.zero,
            menuHeight: 240,
            hintText: _loadingAccounts
                ? tr(ar: 'جارٍ تحميل الشركات...', en: 'Loading companies...')
                : tr(
                    ar: 'اكتب حرفًا للبحث في أسماء الشركات',
                    en: 'Type a letter to search companies',
                  ),
            errorText: field.errorText,
            textStyle: const TextStyle(color: HesbaColors.ink, fontSize: 15),
            inputDecorationTheme: Theme.of(context).inputDecorationTheme,
            menuStyle: const MenuStyle(
              backgroundColor: WidgetStatePropertyAll(Colors.white),
              surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
            ),
            filterCallback: (entries, filter) {
              final query = _searchKey(filter);
              if (query.isEmpty) return entries;
              return entries
                  .where((entry) => _searchKey(entry.label).contains(query))
                  .toList();
            },
            dropdownMenuEntries: [
              for (final name in names)
                DropdownMenuEntry<String>(value: name, label: name),
            ],
            onSelected: _saving
                ? null
                : (value) {
                    setState(() {
                      _companyName = value;
                      _error = null;
                    });
                    field.didChange(value);
                  },
          ),
        );
      },
    );
  }

  Widget _visaServiceField() {
    final amount = parseNum(_amount.text.trim()) ?? 0;
    final profit = purchaseVisaCollectionProfit(amount, _withService);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _ServiceChoice(
                title: 'من غير خدمة',
                subtitle: widget.session.isAdmin
                    ? 'المكسب ٢٠ جنيه على كل ألف'
                    : 'تنفيذ من غير خدمة',
                selected: !_withService,
                onTap: _saving
                    ? null
                    : () => setState(() => _withService = false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ServiceChoice(
                title: 'بخدمة ماكينة',
                subtitle: widget.session.isAdmin
                    ? 'الماكينة بتاخد ٧، والمكسب ١٣'
                    : 'تنفيذ بخدمة ماكينة',
                selected: _withService,
                onTap: _saving
                    ? null
                    : () => setState(() => _withService = true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        HesbaModalCallout(
          child: Text(
            widget.session.isAdmin
                ? 'هيتسحب ${money(amount)} من الفيزا، والمكسب ${money(profit)} هيدخل الخزنة مع الكاش.'
                : 'هيتسحب ${money(amount)} من الفيزا.',
          ),
        ),
      ],
    );
  }

  String _profitDebitMessage() {
    if (!widget.session.isAdmin) {
      return 'هيتسحب إجمالي ${money(_requiredBalance)} من الحساب.';
    }
    final amount = parseNum(_amount.text.trim()) ?? 0;
    final fee = profitCollectionCommission(amount);
    final remaining = (_selectedBalance ?? 0) - _requiredBalance;
    return 'مبلغ التوريد ${money(amount)}، وخصم مكسب ${money(fee)} (٤ جنيه لكل ألف). هيتسحب إجمالي ${money(_requiredBalance)} من الحساب. الرصيد بعد التنفيذ ${money(remaining)}.';
  }

  Widget _profitDebitNotice() {
    return HesbaModalCallout(child: Text(_profitDebitMessage()));
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
        'رصيد غير كافٍ. الحساب فيه ${money(balance)} والعملية محتاجة ${money(_requiredBalance)}. اختار حساب يغطي المبلغ.',
      ),
    );
  }

  Widget _accountField() {
    return HesbaModalField(
      label: 'الحساب المستخدم في التنفيذ *',
      child: DropdownButtonFormField<String>(
        key: ValueKey(_accountId),
        initialValue: _accountId,
        isExpanded: true,
        decoration: const InputDecoration(),
        hint: Text(_loadingAccounts ? 'جارٍ تحميل الحسابات...' : 'اختر الحساب'),
        items: [
          for (final item in _accounts)
            DropdownMenuItem(
              value: 'account:${item['id']}',
              child: _sourceOption(
                '${item['name']} — ${money(item['balance'])}',
                num.tryParse('${item['balance']}') ?? 0,
                (item['type'] == 'profit_qr' || item['type'] == 'profit')
                    ? (parseNum(_amount.text.trim()) ?? 0) +
                          profitCollectionCommission(
                            parseNum(_amount.text.trim()) ?? 0,
                          )
                    : parseNum(_amount.text.trim()) ?? 0,
              ),
            ),
          for (final item in _visas)
            DropdownMenuItem(
              value: 'visa:${item['id']}',
              child: _sourceOption(
                'فيزا مشتريات — ${item['name']} — ${money(item['balance'])}',
                num.tryParse('${item['balance']}') ?? 0,
                parseNum(_amount.text.trim()) ?? 0,
              ),
            ),
        ],
        onChanged: _saving || _loadingAccounts
            ? null
            : (value) => setState(() {
                _accountId = value;
                _syncProfitCommission();
              }),
        validator: (_) =>
            _isImmediate && _accountId == null ? 'اختر الحساب المستخدم' : null,
      ),
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    Key? fieldKey,
    bool numeric = false,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return HesbaModalField(
      label: label,
      child: TextFormField(
        key: fieldKey,
        controller: controller,
        enabled: !_saving,
        readOnly: readOnly,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: numeric ? const [MoneyInputFormatter()] : null,
        textDirection: numeric ? TextDirection.ltr : TextDirection.rtl,
        textAlign: numeric ? TextAlign.left : TextAlign.right,
        validator:
            validator ??
            (value) {
              final message = _requiredText(value);
              return message.isEmpty ? null : message;
            },
      ),
    );
  }

  Widget _timeField() {
    return HesbaModalField(
      label: 'وقت الاستلام *',
      child: InkWell(
        onTap: _saving ? null : _pickTime,
        borderRadius: BorderRadius.circular(9),
        child: InputDecorator(
          decoration: const InputDecoration(),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatTime(_receivedAt),
                  style: const TextStyle(color: HesbaColors.ink, fontSize: 15),
                ),
                const Icon(Icons.schedule, size: 19),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  }
}

class _ServiceChoice extends StatelessWidget {
  const _ServiceChoice({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? HesbaColors.tealLight : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? HesbaColors.teal : HesbaColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(subtitle, style: HesbaText.bodyMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletPart {
  String? walletId;
  final TextEditingController amount = TextEditingController();
}

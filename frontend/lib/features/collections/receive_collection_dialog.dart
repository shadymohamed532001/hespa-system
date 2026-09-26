import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
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
  final _company = TextEditingController();
  final _amount = TextEditingController();
  final _cashAmount = TextEditingController();
  final _commission = TextEditingController(text: '0');
  final List<_WalletPart> _parts = [];

  List<dynamic> _accounts = [];
  List<dynamic> _wallets = [];
  String _mode = 'immediate';
  String? _accountId;
  String? _companyName;
  TimeOfDay _receivedAt = TimeOfDay.now();
  bool _loadingAccounts = true;
  bool _splitIncoming = false;
  bool _saving = false;
  String? _error;

  bool get _isImmediate => _mode == 'immediate';

  bool get _selectedIsFawry {
    for (final item in _accounts) {
      if ('${item['id']}' == _accountId) return item['type'] == 'fawry';
    }
    return false;
  }

  List<String> get _companyNames {
    final names = <String>[];
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
    _amount.addListener(_onMoneyChanged);
    _cashAmount.addListener(_onMoneyChanged);
    _loadAccounts();
  }

  @override
  void dispose() {
    _company.removeListener(_syncCompanySelection);
    _amount.removeListener(_onMoneyChanged);
    _cashAmount.removeListener(_onMoneyChanged);
    _company.dispose();
    _amount.dispose();
    _cashAmount.dispose();
    _commission.dispose();
    for (final part in _parts) {
      part.amount.removeListener(_onMoneyChanged);
      part.amount.dispose();
    }
    super.dispose();
  }

  void _onMoneyChanged() {
    if (mounted && _splitIncoming) setState(() {});
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
      final results = await Future.wait([
        widget.session.api.list(ApiEndpoints.accounts),
        walletsFuture,
      ]);
      if (!mounted) return;
      final accounts = results[0];
      setState(() {
        _accounts = accounts.where((item) => item['active'] != false).toList();
        _wallets = results[1]
            .where((item) => item['active'] != false)
            .toList();
        _accountId = _accounts.isEmpty ? null : '${_accounts.first['id']}';
        _loadingAccounts = false;
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
    if (_isImmediate && _accountId == null) {
      setState(() => _error = 'لا يوجد حساب متاح لتنفيذ العملية فورًا.');
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
      'amount': num.parse(_amount.text.trim()),
      'executionMode': _mode,
      'receivedAt': receivedAt.toIso8601String(),
      'commission': _isImmediate && !_selectedIsFawry
          ? num.tryParse(_commission.text.trim()) ?? 0
          : 0,
      if (_isImmediate) 'accountId': _accountId,
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
    final username = widget.session.username?.trim() ?? '';
    return username.length >= 2 ? username : 'موظف';
  }

  String _requiredText(String? value) {
    return value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : '';
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

  String? _splitError() {
    if (!_splitIncoming) return null;
    if (_wallets.isEmpty) {
      return 'أضف محفظة نشطة زي فودافون كاش قبل تقسيم الداخل.';
    }
    final total = num.tryParse(_amount.text.trim());
    final cash = num.tryParse(_cashAmount.text.trim());
    if (total == null || total <= 0 || cash == null || cash < 0) {
      return 'أدخل المبلغ الكلي والكاش اللي يدخل الخزنة.';
    }
    final ids = <String>[];
    var walletTotal = 0.0;
    for (final part in _parts) {
      final walletId = part.walletId;
      final amount = num.tryParse(part.amount.text.trim());
      if (walletId == null || _walletById(walletId) == null) {
        return 'اختر المحفظة اللي هتستلم الجزء.';
      }
      if (amount == null || amount <= 0) {
        return 'أدخل مبلغ المحفظة.';
      }
      if (ids.contains(walletId)) {
        return 'المحفظة متكررة. اجمع مبلغها في سطر واحد.';
      }
      ids.add(walletId);
      walletTotal += amount;
    }
    if (ids.isEmpty) return 'أضف جزء المحفظة.';
    final sum = cash + walletTotal;
    if ((sum - total).abs() > 0.009) {
      return 'مجموع الكاش والمحافظ ${money(sum)} لازم يساوي المبلغ ${money(total)}.';
    }
    return null;
  }

  Map<String, dynamic> _splitPayload() {
    return {
      'cashAmount': num.parse(_cashAmount.text.trim()),
      'incomingParts': [
        for (final part in _parts)
          {
            'walletId': part.walletId,
            'amount': num.parse(part.amount.text.trim()),
          },
      ],
    };
  }

  String _flowText() {
    if (!_isImmediate) {
      return 'يدخل الكاش الخزنة لكنه يظل محجوزًا كالتزام حتى تنفيذ العملية لاحقًا.';
    }
    if (_splitIncoming && _splitError() == null) {
      final total = num.parse(_amount.text.trim());
      final cash = num.parse(_cashAmount.text.trim());
      final wallets = _parts.map((part) {
        final wallet = _walletById(part.walletId);
        final name = wallet == null ? 'المحفظة' : '${wallet['name']}';
        return '$name ${money(part.amount.text.trim())}';
      }).join('، ');
      return 'يتسحب ${money(total)} من حساب التنفيذ. يدخل الخزنة ${money(cash)}. يدخل $wallets.';
    }
    if (_selectedIsFawry) {
      return 'يدخل الكاش الخزنة وينخفض رصيد حساب فوري. العمولة بتتسجل نزلة في اليوم التالي.';
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
        primaryEnabled: !_saving,
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
                    SizedBox(width: width, child: _companyField()),
                    SizedBox(
                      width: width,
                      child: _textField(
                        label: tr(ar: 'المبلغ *', en: 'Amount *'),
                        controller: _amount,
                        numeric: true,
                        validator: (value) {
                          final number = num.tryParse(value?.trim() ?? '');
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
                    if (_isImmediate && !_selectedIsFawry)
                      SizedBox(
                        width: width,
                        child: _textField(
                          label: tr(ar: 'العمولة', en: 'Commission'),
                          controller: _commission,
                          numeric: true,
                          validator: (value) {
                            final number = num.tryParse(
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
              _splitSection(),
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
                    TextSpan(
                      text: _flowText(),
                    ),
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
              'السحب من حساب التنفيذ على المبلغ كله. الكاش بس يدخل الخزنة، والباقي يدخل المحفظة.',
            ),
            onChanged: _saving ? null : (value) => _setSplit(value ?? false),
          ),
        ),
        if (_splitIncoming) ...[
          const SizedBox(height: 8),
          _textField(
            label: 'الكاش اللي يدخل الخزنة *',
            controller: _cashAmount,
            numeric: true,
            validator: (value) {
              final number = num.tryParse(value?.trim() ?? '');
              return number == null || number < 0 ? 'أدخل مبلغ الكاش' : null;
            },
          ),
          for (var index = 0; index < _parts.length; index++) _partRow(index),
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
                final number = num.tryParse(value?.trim() ?? '');
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
                if (_mode != 'immediate') _splitIncoming = false;
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
            ar: 'لا توجد شركات. أضف حساب شركة من فوري والشركات',
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
                  .where(
                    (entry) => _searchKey(entry.label).contains(query),
                  )
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

  Widget _accountField() {
    return HesbaModalField(
      label: 'الحساب المستخدم في التنفيذ *',
      child: DropdownButtonFormField<String>(
        key: ValueKey(_accountId),
        initialValue: _accountId,
        isExpanded: true,
        decoration: const InputDecoration(),
        hint: Text(_loadingAccounts ? 'جارٍ تحميل الحسابات...' : 'اختر الحساب'),
        items: _accounts
            .map<DropdownMenuItem<String>>(
              (item) => DropdownMenuItem(
                value: '${item['id']}',
                child: Text('${item['name']} — ${money(item['balance'])}'),
              ),
            )
            .toList(),
        onChanged: _saving || _loadingAccounts
            ? null
            : (value) => setState(() => _accountId = value),
        validator: (_) =>
            _isImmediate && _accountId == null ? 'اختر الحساب المستخدم' : null,
      ),
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    bool numeric = false,
    String? Function(String?)? validator,
  }) {
    return HesbaModalField(
      label: label,
      child: TextFormField(
        controller: controller,
        enabled: !_saving,
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
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

class _WalletPart {
  String? walletId;
  final TextEditingController amount = TextEditingController();
}

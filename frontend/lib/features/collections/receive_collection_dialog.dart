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
  final _commission = TextEditingController(text: '0');

  List<dynamic> _accounts = [];
  String _mode = 'immediate';
  String? _accountId;
  String? _companyName;
  TimeOfDay _receivedAt = TimeOfDay.now();
  bool _loadingAccounts = true;
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
    _loadAccounts();
  }

  @override
  void dispose() {
    _company.removeListener(_syncCompanySelection);
    _company.dispose();
    _amount.dispose();
    _commission.dispose();
    super.dispose();
  }

  void _syncCompanySelection() {
    final typed = _company.text.trim();
    _companyName = _companyNames.contains(typed) ? typed : null;
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts = await widget.session.api.list(ApiEndpoints.accounts);
      if (!mounted) return;
      setState(() {
        _accounts = accounts.where((item) => item['active'] != false).toList();
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
                      text: _isImmediate
                          ? (_selectedIsFawry
                                ? 'يدخل الكاش الخزنة وينخفض رصيد حساب فوري. العمولة بتتسجل نزلة في اليوم التالي.'
                                : 'يدخل الكاش الخزنة، وينخفض رصيد الحساب المستخدم، وتُسجل العمولة في نفس اللحظة.')
                          : 'يدخل الكاش الخزنة لكنه يظل محجوزًا كالتزام حتى تنفيذ العملية لاحقًا.',
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

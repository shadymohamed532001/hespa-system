import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/error_box.dart';
import '../../core/widgets/page_frame.dart';
import '../auth/session_controller.dart';
import '../../core/settings/tr.dart';

class InternalTransferPage extends StatefulWidget {
  const InternalTransferPage({super.key, required this.session});

  final SessionController session;

  @override
  State<InternalTransferPage> createState() => _InternalTransferPageState();
}

class _InternalTransferPageState extends State<InternalTransferPage> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reference = TextEditingController();

  List<_TransferAsset> _assets = [];
  String? _fromValue;
  String? _toValue;
  bool _loading = true;
  bool _saving = false;
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
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        widget.session.api.list(ApiEndpoints.accounts),
        widget.session.api.list(ApiEndpoints.wallets),
        widget.session.api.list(ApiEndpoints.machines),
        widget.session.api.list(ApiEndpoints.ledgerList(limit: 200)),
      ]);
      final accounts = values[0];
      final wallets = values[1];
      final machines = values[2];
      final ledger = values[3];
      final assets = <_TransferAsset>[
        const _TransferAsset(
          value: 'treasury:',
          type: 'treasury',
          name: 'الخزنة المركزية',
        ),
        ...accounts
            .where((item) => item['active'] != false)
            .map(
              (item) => _TransferAsset(
                value: 'account:${item['id']}',
                type: 'account',
                id: '${item['id']}',
                name: '${item['name']}',
              ),
            ),
        ...wallets
            .where((item) => item['active'] != false)
            .map(
              (item) => _TransferAsset(
                value: 'wallet:${item['id']}',
                type: 'wallet',
                id: '${item['id']}',
                name: '${item['name']}',
              ),
            ),
        ...machines
            .where((item) => item['active'] != false)
            .map(
              (item) => _TransferAsset(
                value: 'machine:${item['id']}',
                type: 'machine',
                id: '${item['id']}',
                name: '${item['name']}',
              ),
            ),
      ];
      _nextSequence =
          ledger
              .where((entry) => entry['category'] == 'internal_transfer')
              .length +
          1;
      _assets = assets;
      _fromValue = assets.first.value;
      _toValue = assets.length > 1 ? assets[1].value : null;
      _reference.text = _newReference();
      _error = null;
    } catch (exception) {
      _error = ApiClient.errorMessage(exception);
    }
    if (mounted) setState(() => _loading = false);
  }

  String _newReference() {
    final sequence = _nextSequence.toString().padLeft(3, '0');
    return 'TRF-${DateTime.now().year}-$sequence';
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: tr(ar: 'تحويل داخلي', en: 'Internal transfer'),
      subtitle: 'نقل الأموال بين أصول المحل دون تسجيل مصروف',
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
                const _TransferNotice(),
                const SizedBox(height: 20),
                _TransferFormCard(
                  formKey: _formKey,
                  assets: _assets,
                  fromValue: _fromValue,
                  toValue: _toValue,
                  amount: _amount,
                  reference: _reference,
                  saving: _saving,
                  onFromChanged: (value) => setState(() => _fromValue = value),
                  onToChanged: (value) => setState(() => _toValue = value),
                  onSubmit: _submit,
                ),
              ],
            ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_fromValue == _toValue) {
      showAppSnack(context, 'المصدر والوجهة يجب أن يكونا مختلفين', error: true);
      return;
    }

    final from = _assets.firstWhere((item) => item.value == _fromValue);
    final to = _assets.firstWhere((item) => item.value == _toValue);
    setState(() => _saving = true);
    try {
      await widget.session.api.post(ApiEndpoints.treasuryTransfer, {
        'fromType': from.type,
        if (from.id != null) 'fromId': from.id,
        'toType': to.type,
        if (to.id != null) 'toId': to.id,
        'amount': num.parse(_amount.text.trim()),
        if (_reference.text.trim().isNotEmpty)
          'reference': _reference.text.trim(),
      });
      _nextSequence += 1;
      _amount.clear();
      _reference.text = _newReference();
      if (mounted) showAppSnack(context, 'تم تنفيذ التحويل الداخلي');
    } catch (exception) {
      if (mounted) {
        showAppSnack(context, ApiClient.errorMessage(exception), error: true);
      }
    }
    if (mounted) setState(() => _saving = false);
  }
}

class _TransferNotice extends StatelessWidget {
  const _TransferNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF4F7),
        borderRadius: BorderRadius.circular(11),
      ),
      child: const Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'هذه الحركة لا تُسجّل كمصروف أو ربح. ',
              style: TextStyle(fontWeight: FontWeight.w400),
            ),
            TextSpan(
              text: 'يتم فقط خفض رصيد الأصل المصدر وزيادة رصيد الأصل المستلم.',
            ),
          ],
        ),
        style: TextStyle(color: Color(0xFF425C6B), fontSize: 13, height: 1.55),
      ),
    );
  }
}

class _TransferFormCard extends StatelessWidget {
  const _TransferFormCard({
    required this.formKey,
    required this.assets,
    required this.fromValue,
    required this.toValue,
    required this.amount,
    required this.reference,
    required this.saving,
    required this.onFromChanged,
    required this.onToChanged,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final List<_TransferAsset> assets;
  final String? fromValue;
  final String? toValue;
  final TextEditingController amount;
  final TextEditingController reference;
  final bool saving;
  final ValueChanged<String?> onFromChanged;
  final ValueChanged<String?> onToChanged;
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
                Text('بيانات التحويل', style: HesbaText.sectionTitle),
                SizedBox(height: 2),
                Text(
                  'انقل مبلغًا بين الخزنة وحسابات التشغيل',
                  style: HesbaText.panelSub,
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
                            child: _AssetField(
                              label: 'من *',
                              value: fromValue,
                              assets: assets,
                              enabled: !saving,
                              onChanged: onFromChanged,
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: _AssetField(
                              label: 'إلى *',
                              value: toValue,
                              assets: assets,
                              enabled: !saving,
                              onChanged: onToChanged,
                            ),
                          ),
                          SizedBox(
                            width: fieldWidth,
                            child: _LabeledField(
                              label: tr(ar: 'المبلغ *', en: 'Amount *'),
                              child: TextFormField(
                                controller: amount,
                                enabled: !saving,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.left,
                                validator: (value) {
                                  final number = num.tryParse(
                                    value?.trim() ?? '',
                                  );
                                  return number == null || number <= 0
                                      ? tr(
                                          ar: 'أدخل مبلغًا صحيحًا',
                                          en: 'Enter a valid amount',
                                        )
                                      : null;
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: fieldWidth,
                          child: _LabeledField(
                            label: 'مرجع الحركة',
                            child: TextFormField(
                              controller: reference,
                              enabled: !saving,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: saving ? null : onSubmit,
                          child: saving
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('تنفيذ التحويل الداخلي'),
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

class _AssetField extends StatelessWidget {
  const _AssetField({
    required this.label,
    required this.value,
    required this.assets,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<_TransferAsset> assets;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _LabeledField(
      label: label,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: const InputDecoration(),
        items: assets
            .map(
              (asset) =>
                  DropdownMenuItem(value: asset.value, child: Text(asset.name)),
            )
            .toList(),
        onChanged: enabled ? onChanged : null,
        validator: (selected) => selected == null ? 'اختر الأصل' : null,
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
        Text(label, style: HesbaText.fieldLabel),
        const SizedBox(height: 7),
        child,
      ],
    );
  }
}

class _TransferAsset {
  const _TransferAsset({
    required this.value,
    required this.type,
    required this.name,
    this.id,
  });

  final String value;
  final String type;
  final String name;
  final String? id;
}

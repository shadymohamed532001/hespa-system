import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/digits.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/error_box.dart';
import '../../core/widgets/hesba_modal.dart';
import '../../core/widgets/page_frame.dart';
import '../auth/session_controller.dart';

class PurchaseVisasPage extends StatefulWidget {
  const PurchaseVisasPage({super.key, required this.session});

  final SessionController session;

  @override
  State<PurchaseVisasPage> createState() => _PurchaseVisasPageState();
}

class _PurchaseVisasPageState extends State<PurchaseVisasPage> {
  List<dynamic> visas = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      visas = await widget.session.api.list(ApiEndpoints.purchaseVisas);
    } catch (exception) {
      error = ApiClient.errorMessage(exception);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _create() async {
    final result = await showHesbaModal<_CreateVisaInput>(
      context: context,
      builder: (context) => const _CreateVisaDialog(),
    );
    if (result == null || !mounted) return;
    try {
      await widget.session.api.post(ApiEndpoints.purchaseVisas, {
        'name': result.name,
        'ownerName': result.ownerName,
        'cardNumber': result.cardNumber,
        'expiry': result.expiry,
        'openingBalance': result.openingBalance,
      });
      await load();
      if (mounted) showAppSnack(context, 'تم تسجيل الفيزا');
    } catch (exception) {
      if (mounted) {
        showAppSnack(context, ApiClient.errorMessage(exception), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = widget.session.can(AppPermissions.manageAssets);
    return PageFrame(
      title: 'فيزا المشتريات',
      subtitle:
          'توريد الرصيد لمندوب، والمكسب ٢٠ جنيه لكل ألف أو ١٣ لو فيه خدمة',
      actions: [
        if (canCreate)
          FilledButton(onPressed: _create, child: const Text('تسجيل فيزا')),
      ],
      child: loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(80),
                child: CircularProgressIndicator(),
              ),
            )
          : error != null
          ? ErrorBox(message: error!, retry: load)
          : visas.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(40),
              child: Text(
                'لسه مفيش فيزا متسجلة. سجّل الفيزا، والسحب بيتم من استلام المندوب.',
                textAlign: TextAlign.center,
                style: TextStyle(color: HesbaColors.muted),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                return Wrap(
                  spacing: 15,
                  runSpacing: 15,
                  children: [
                    for (final raw in visas)
                      SizedBox(
                        width: wide
                            ? (constraints.maxWidth - 15) / 2
                            : constraints.maxWidth,
                        child: _VisaCard(
                          visa: raw as Map<String, dynamic>,
                          showProfit: widget.session.isAdmin,
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _VisaCard extends StatelessWidget {
  const _VisaCard({required this.visa, required this.showProfit});

  final Map<String, dynamic> visa;
  final bool showProfit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HesbaColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${visa['name']}', style: HesbaText.sectionTitle),
          const SizedBox(height: 6),
          Text('${visa['ownerName']}', style: HesbaText.bodyMuted),
          const SizedBox(height: 4),
          Text(
            _formatCardNumber('${visa['cardNumber']}'),
            style: const TextStyle(letterSpacing: 0.6),
          ),
          const SizedBox(height: 4),
          Text(
            'تنتهي ${_formatExpiry(visa['expiresOn'])}',
            style: TextStyle(color: _expiryTone(visa['expiresOn'])),
          ),
          const SizedBox(height: 14),
          Text('الرصيد', style: HesbaText.bodyMuted),
          const SizedBox(height: 2),
          Text(
            money(visa['balance']),
            style: HesbaText.pageTitle.copyWith(fontSize: 28),
          ),
          if (showProfit) ...[
            const SizedBox(height: 10),
            Text(
              'إجمالي المكسب ${money(visa['commissionBalance'])}',
              style: const TextStyle(color: HesbaColors.tealDark),
            ),
          ],
        ],
      ),
    );
  }
}

class _CreateVisaInput {
  const _CreateVisaInput({
    required this.name,
    required this.ownerName,
    required this.cardNumber,
    required this.expiry,
    required this.openingBalance,
  });

  final String name;
  final String ownerName;
  final String cardNumber;
  final String expiry;
  final num openingBalance;
}

class _CreateVisaDialog extends StatefulWidget {
  const _CreateVisaDialog();

  @override
  State<_CreateVisaDialog> createState() => _CreateVisaDialogState();
}

class _CreateVisaDialogState extends State<_CreateVisaDialog> {
  final name = TextEditingController();
  final owner = TextEditingController();
  final card = TextEditingController();
  final expiry = TextEditingController();
  final balance = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    owner.dispose();
    card.dispose();
    expiry.dispose();
    balance.dispose();
    super.dispose();
  }

  String? get _nameError {
    if (name.text.trim().isEmpty) return 'اسم الفيزا مطلوب';
    return null;
  }

  String? get _ownerError {
    if (owner.text.trim().length < 2) return 'اسم صاحب الفيزا مطلوب';
    return null;
  }

  String? get _cardError => _validateCardNumber(card.text);

  String? get _expiryError => _validateExpiry(expiry.text);

  bool get _canSave =>
      _nameError == null &&
      _ownerError == null &&
      _cardError == null &&
      _expiryError == null;

  @override
  Widget build(BuildContext context) {
    return HesbaModalCard(
      title: 'تسجيل فيزا مشتريات',
      subtitle: 'اسم الفيزا، رقمها، صاحبها، تاريخ الانتهاء، والرصيد الحالي.',
      actions: HesbaModalActions(
        primaryLabel: 'حفظ الفيزا',
        primaryEnabled: _canSave,
        onPrimary: () => Navigator.pop(
          context,
          _CreateVisaInput(
            name: name.text.trim(),
            ownerName: owner.text.trim(),
            cardNumber: _cardDigits(card.text),
            expiry: normalizeDigits(expiry.text).trim(),
            openingBalance: parseNum(balance.text.trim()) ?? 0,
          ),
        ),
        onCancel: () => Navigator.pop(context),
      ),
      child: Column(
        children: [
          HesbaModalField(
            label: 'اسم الفيزا',
            child: TextField(
              controller: name,
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
          ),
          _FieldError(message: name.text.isEmpty ? null : _nameError),
          const SizedBox(height: 16),
          HesbaModalField(
            label: 'رقم الفيزا',
            child: TextField(
              controller: card,
              keyboardType: TextInputType.number,
              inputFormatters: const [
                ArabicDigitsFormatter(),
                _CardNumberFormatter(),
              ],
              onChanged: (_) => setState(() {}),
            ),
          ),
          _FieldError(message: card.text.isEmpty ? null : _cardError),
          const SizedBox(height: 16),
          HesbaModalField(
            label: 'اسم صاحب الفيزا',
            child: TextField(
              controller: owner,
              onChanged: (_) => setState(() {}),
            ),
          ),
          _FieldError(message: owner.text.isEmpty ? null : _ownerError),
          const SizedBox(height: 16),
          HesbaModalField(
            label: 'تنتهي في',
            child: TextField(
              controller: expiry,
              keyboardType: TextInputType.number,
              inputFormatters: const [
                ArabicDigitsFormatter(),
                _ExpiryFormatter(),
              ],
              decoration: const InputDecoration(hintText: '09/28'),
              onChanged: (_) => setState(() {}),
            ),
          ),
          _FieldError(message: expiry.text.isEmpty ? null : _expiryError),
          const SizedBox(height: 16),
          HesbaModalField(
            label: 'الرصيد الحالي',
            child: TextField(
              controller: balance,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [ArabicDigitsFormatter()],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        message!,
        style: const TextStyle(color: HesbaColors.warning, fontSize: 12),
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  const _CardNumberFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = _cardDigits(newValue.text);
    final clipped = digits.length > 16 ? digits.substring(0, 16) : digits;
    return TextEditingValue(
      text: _formatCardNumber(clipped),
      selection: TextSelection.collapsed(
        offset: _formatCardNumber(clipped).length,
      ),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  const _ExpiryFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = normalizeDigits(newValue.text).replaceAll(RegExp(r'\D'), '');
    final clipped = digits.length > 4 ? digits.substring(0, 4) : digits;
    final text = clipped.length <= 2
        ? clipped
        : '${clipped.substring(0, 2)}/${clipped.substring(2)}';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

String _cardDigits(String raw) =>
    normalizeDigits(raw).replaceAll(RegExp(r'\D'), '');

String _formatCardNumber(String raw) {
  final digits = _cardDigits(raw);
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && index % 4 == 0) buffer.write(' ');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}

bool _luhn(String digits) {
  var sum = 0;
  var doubleDigit = false;
  for (var index = digits.length - 1; index >= 0; index--) {
    var value = digits.codeUnitAt(index) - 48;
    if (doubleDigit) {
      value *= 2;
      if (value > 9) value -= 9;
    }
    sum += value;
    doubleDigit = !doubleDigit;
  }
  return sum % 10 == 0;
}

String? _validateCardNumber(String raw) {
  final digits = _cardDigits(raw);
  if (digits.length != 16 || !_luhn(digits)) {
    return 'رقم الفيزا لازم يكون ١٦ رقم صحيح';
  }
  return null;
}

String? _validateExpiry(String raw) {
  final text = normalizeDigits(raw).trim();
  final match = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(text);
  if (match == null) return 'اكتب تاريخ الانتهاء شهر/سنة، مثل 09/28';
  final month = int.parse(match.group(1)!);
  if (month < 1 || month > 12) return 'شهر الانتهاء غير صحيح';
  final year = 2000 + int.parse(match.group(2)!);
  final now = DateTime.now();
  final expires = year * 12 + (month - 1);
  final current = now.year * 12 + (now.month - 1);
  if (expires < current) return 'الفيزا منتهية';
  return null;
}

String _formatExpiry(dynamic value) {
  final text = '$value';
  final match = RegExp(r'^(\d{4})-(\d{2})').firstMatch(text);
  if (match == null) return text;
  return '${match.group(2)}/${match.group(1)!.substring(2)}';
}

Color _expiryTone(dynamic value) {
  final text = '$value';
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(text);
  if (match == null) return HesbaColors.muted;
  final expiry = DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day);
  if (expiry.isBefore(start)) return HesbaColors.warning;
  if (expiry.difference(start).inDays <= 30) return HesbaColors.warning;
  return HesbaColors.muted;
}

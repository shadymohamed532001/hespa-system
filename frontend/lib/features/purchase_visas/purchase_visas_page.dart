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

  Future<void> _withdraw(Map<String, dynamic> visa) async {
    final result = await showHesbaModal<_WithdrawInput>(
      context: context,
      builder: (context) => _WithdrawDialog(visa: visa),
    );
    if (result == null || !mounted) return;
    try {
      await widget.session.api
          .post(ApiEndpoints.purchaseVisaWithdraw('${visa['id']}'), {
            'amount': result.amount,
            'agentName': result.agentName,
            'withService': result.withService,
            if (result.note.isNotEmpty) 'note': result.note,
          });
      await load();
      if (!mounted) return;
      final quote = _quotePurchaseVisa(result.amount, result.withService);
      showAppSnack(
        context,
        'اتسحب ${money(quote.principal)}، والمكسب ${money(quote.netProfit)}، ودخل الخزنة ${money(quote.treasuryCredit)}',
      );
    } catch (exception) {
      if (mounted) {
        showAppSnack(context, ApiClient.errorMessage(exception), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = widget.session.can(AppPermissions.manageAssets);
    final canWithdraw = widget.session.can(AppPermissions.usePurchaseVisas);
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
                'لسه مفيش فيزا متسجلة. سجّل الفيزا الأول وبعدين اسحب منها.',
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
                          canWithdraw: canWithdraw,
                          showProfit: widget.session.isAdmin,
                          onWithdraw: () => _withdraw(raw),
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
  const _VisaCard({
    required this.visa,
    required this.canWithdraw,
    required this.showProfit,
    required this.onWithdraw,
  });

  final Map<String, dynamic> visa;
  final bool canWithdraw;
  final bool showProfit;
  final VoidCallback onWithdraw;

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
          if (canWithdraw) ...[
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton(
                onPressed: onWithdraw,
                child: const Text('سحب من الفيزا'),
              ),
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

class _WithdrawInput {
  const _WithdrawInput({
    required this.amount,
    required this.agentName,
    required this.withService,
    required this.note,
  });

  final num amount;
  final String agentName;
  final bool withService;
  final String note;
}

class _WithdrawDialog extends StatefulWidget {
  const _WithdrawDialog({required this.visa});

  final Map<String, dynamic> visa;

  @override
  State<_WithdrawDialog> createState() => _WithdrawDialogState();
}

class _WithdrawDialogState extends State<_WithdrawDialog> {
  final amount = TextEditingController();
  final agent = TextEditingController();
  final note = TextEditingController();
  bool withService = false;

  @override
  void dispose() {
    amount.dispose();
    agent.dispose();
    note.dispose();
    super.dispose();
  }

  num? get _amount {
    final value = parseNum(amount.text.trim());
    if (value == null || value <= 0) return null;
    return value;
  }

  _VisaQuote? get _quote {
    final value = _amount;
    if (value == null) return null;
    return _quotePurchaseVisa(value, withService);
  }

  @override
  Widget build(BuildContext context) {
    final balance = parseNum('${widget.visa['balance']}') ?? 0;
    final quote = _quote;
    final agentName = agent.text.trim();
    final tooMuch = quote != null && quote.principal > balance;
    final canSave = quote != null && agentName.isNotEmpty && !tooMuch;

    return HesbaModalCard(
      title: 'سحب من ${widget.visa['name']}',
      subtitle:
          'الرصيد ${money(balance)}. من غير خدمة المكسب ٢٠ جنيه لكل ألف، وبخدمة الماكينة بتاخد ٧ ويفضل لك ١٣.',
      actions: HesbaModalActions(
        primaryLabel: 'تأكيد السحب',
        primaryEnabled: canSave,
        onPrimary: () => Navigator.pop(
          context,
          _WithdrawInput(
            amount: quote!.principal,
            agentName: agentName,
            withService: withService,
            note: note.text.trim(),
          ),
        ),
        onCancel: () => Navigator.pop(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ServiceChoice(
            title: 'من غير خدمة',
            subtitle: 'المكسب ٢٠ جنيه على كل ألف',
            selected: !withService,
            onTap: () => setState(() => withService = false),
          ),
          const SizedBox(height: 10),
          _ServiceChoice(
            title: 'بخدمة ماكينة',
            subtitle: 'الماكينة بتاخد ٧، والمكسب ١٣ جنيه على كل ألف',
            selected: withService,
            onTap: () => setState(() => withService = true),
          ),
          const SizedBox(height: 18),
          HesbaModalField(
            label: 'المبلغ المسحوب من الفيزا',
            child: TextField(
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [ArabicDigitsFormatter()],
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 16),
          HesbaModalField(
            label: 'اسم المندوب',
            child: TextField(
              controller: agent,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 16),
          HesbaModalField(
            label: 'ملاحظة',
            child: TextField(controller: note, maxLength: 300),
          ),
          const SizedBox(height: 8),
          HesbaModalCallout(
            backgroundColor: tooMuch
                ? HesbaColors.warningLight
                : const Color(0xFFEEF4F7),
            borderColor: tooMuch ? HesbaColors.warning : HesbaColors.border,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote == null
                      ? 'هيتسحب من الفيزا: —'
                      : 'هيتسحب من الفيزا: ${money(quote.principal)}',
                ),
                const SizedBox(height: 4),
                Text(
                  quote == null
                      ? 'خدمة الماكينة: —'
                      : 'خدمة الماكينة: ${money(quote.serviceFee)}',
                ),
                const SizedBox(height: 4),
                Text(
                  quote == null
                      ? 'المكسب: —'
                      : 'المكسب: ${money(quote.netProfit)}',
                ),
                const SizedBox(height: 4),
                Text(
                  quote == null
                      ? 'هيدخل الخزنة: —'
                      : 'هيدخل الخزنة: ${money(quote.treasuryCredit)}',
                ),
                if (tooMuch) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'المبلغ أكبر من رصيد الفيزا',
                    style: TextStyle(color: HesbaColors.warning),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
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
  final VoidCallback onTap;

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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

class _VisaQuote {
  const _VisaQuote({
    required this.principal,
    required this.serviceFee,
    required this.netProfit,
    required this.treasuryCredit,
  });

  final num principal;
  final num serviceFee;
  final num netProfit;
  final num treasuryCredit;
}

num _perThousand(num amount, int rate) {
  final cents = (amount * 100).round();
  final feeCents = ((cents * rate) / 1000).round();
  return feeCents / 100;
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

_VisaQuote _quotePurchaseVisa(num amount, bool withService) {
  final gross = _perThousand(amount, 20);
  final service = withService ? _perThousand(amount, 7) : 0;
  final net = ((gross - service) * 100).round() / 100;
  return _VisaQuote(
    principal: amount,
    serviceFee: service,
    netProfit: net,
    treasuryCredit: ((amount + net) * 100).round() / 100,
  );
}

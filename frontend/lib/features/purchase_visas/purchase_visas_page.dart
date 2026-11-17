import 'package:flutter/material.dart';

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
import '../collections/profit_collection_commission.dart';

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

  Future<void> load({bool silent = false}) async {
    if (mounted && !silent) {
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

  Future<void> _topUp(Object visa) async {
    final row = visa as Map<String, dynamic>;
    final result = await showHesbaModal<_TopUpVisaInput>(
      context: context,
      maxWidth: 480,
      builder: (context) => _TopUpVisaDialog(visaName: '${row['name']}'),
    );
    if (result == null || !mounted) return;
    try {
      await widget.session.api
          .post(ApiEndpoints.purchaseVisaTopUp('${row['id']}'), {
            'amount': result.amount,
            if (result.reference.isNotEmpty) 'reference': result.reference,
          });
      await load();
      if (mounted) showAppSnack(context, 'تم شحن الفيزا');
    } catch (exception) {
      if (mounted) {
        showAppSnack(context, ApiClient.errorMessage(exception), error: true);
      }
    }
  }

  Future<void> _externalWithdraw() async {
    final result = await showHesbaModal<_ExternalVisaInput>(
      context: context,
      maxWidth: 520,
      builder: (context) =>
          _ExternalVisaDialog(showProfit: widget.session.isAdmin),
    );
    if (result == null || !mounted) return;
    try {
      final response = await widget.session.api.post(
        ApiEndpoints.purchaseVisaExternalWithdraw,
        {
          'amount': result.amount,
          'destination': result.destination,
          if (result.destination != 'machine') ...{
            'agentName': result.agentName,
            'profitPayer': result.profitPayer,
          },
          'withService': result.withService,
          if (result.note.isNotEmpty) 'note': result.note,
        },
      );
      if (!mounted) return;
      final body = response as Map<String, dynamic>;
      showAppSnack(
        context,
        'تم. ادّي صاحب الفيزا ${money(body['customerCash'])} من الخزنة',
      );
    } catch (exception) {
      if (mounted) {
        showAppSnack(context, ApiClient.errorMessage(exception), error: true);
      }
    }
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
    final canTopUp = widget.session.can(AppPermissions.topUpAssets);
    final canUse = widget.session.can(AppPermissions.usePurchaseVisas);
    return PageFrame(
      onRefresh: () => load(silent: true),
      title: 'فيزا المشتريات',
      subtitle:
          'توريد الرصيد لمندوب، والمكسب ٢٠ جنيه لكل ألف أو ١٣ لو فيه خدمة',
      actions: [
        if (canUse)
          OutlinedButton.icon(
            onPressed: _externalWithdraw,
            icon: const Icon(Icons.person_outline, size: 18),
            label: const Text('فيزا مشتريات خارجية'),
          ),
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
                final tileWidth = wide
                    ? (constraints.maxWidth - 15) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 15,
                  runSpacing: 15,
                  children: [
                    for (final raw in visas)
                      SizedBox(
                        width: tileWidth,
                        child: _VisaCard(
                          visa: raw as Map<String, dynamic>,
                          showProfit: widget.session.isAdmin,
                          canTopUp: canTopUp,
                          onTopUp: () => _topUp(raw),
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
    required this.showProfit,
    required this.canTopUp,
    required this.onTopUp,
  });

  final Map<String, dynamic> visa;
  final bool showProfit;
  final bool canTopUp;
  final VoidCallback onTopUp;

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
          if (canTopUp) ...[
            const SizedBox(height: 16),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.icon(
                onPressed: onTopUp,
                icon: const Icon(Icons.add_card_outlined, size: 18),
                label: const Text('شحن الفيزا'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopUpVisaInput {
  const _TopUpVisaInput({required this.amount, required this.reference});

  final num amount;
  final String reference;
}

class _TopUpVisaDialog extends StatefulWidget {
  const _TopUpVisaDialog({required this.visaName});

  final String visaName;

  @override
  State<_TopUpVisaDialog> createState() => _TopUpVisaDialogState();
}

class _TopUpVisaDialogState extends State<_TopUpVisaDialog> {
  final amount = TextEditingController();
  final reference = TextEditingController();

  @override
  void dispose() {
    amount.dispose();
    reference.dispose();
    super.dispose();
  }

  num? get _parsed => parseNum(amount.text.trim());

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;
    return HesbaModalCard(
      title: 'شحن الفيزا',
      subtitle: 'إضافة رصيد جديد إلى ${widget.visaName}.',
      actions: HesbaModalActions(
        primaryLabel: 'شحن',
        primaryEnabled: parsed != null && parsed > 0,
        onPrimary: () => Navigator.pop(
          context,
          _TopUpVisaInput(amount: parsed!, reference: reference.text.trim()),
        ),
        onCancel: () => Navigator.pop(context),
      ),
      child: Column(
        children: [
          HesbaModalField(
            label: 'مبلغ الشحن *',
            child: TextField(
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [MoneyInputFormatter()],
              textDirection: TextDirection.ltr,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 16),
          HesbaModalField(
            label: 'رقم المرجع (اختياري)',
            child: TextField(controller: reference),
          ),
        ],
      ),
    );
  }
}

class _CreateVisaInput {
  const _CreateVisaInput({required this.name, required this.openingBalance});

  final String name;
  final num openingBalance;
}

class _CreateVisaDialog extends StatefulWidget {
  const _CreateVisaDialog();

  @override
  State<_CreateVisaDialog> createState() => _CreateVisaDialogState();
}

class _CreateVisaDialogState extends State<_CreateVisaDialog> {
  final name = TextEditingController();
  final balance = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    balance.dispose();
    super.dispose();
  }

  String? get _nameError {
    if (name.text.trim().length < 2) return 'اسم صاحب الفيزا مطلوب';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return HesbaModalCard(
      title: 'تسجيل فيزا مشتريات',
      subtitle: 'اسم صاحب الفيزا والرصيد اللي فيها.',
      actions: HesbaModalActions(
        primaryLabel: 'حفظ الفيزا',
        primaryEnabled: _nameError == null,
        onPrimary: () => Navigator.pop(
          context,
          _CreateVisaInput(
            name: name.text.trim(),
            openingBalance: parseNum(balance.text.trim()) ?? 0,
          ),
        ),
        onCancel: () => Navigator.pop(context),
      ),
      child: Column(
        children: [
          HesbaModalField(
            label: 'اسم صاحب الفيزا',
            child: TextField(
              controller: name,
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
          ),
          _FieldError(message: name.text.isEmpty ? null : _nameError),
          const SizedBox(height: 16),
          HesbaModalField(
            label: 'الرصيد الحالي',
            child: TextField(
              controller: balance,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [MoneyInputFormatter()],
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

class _ExternalVisaInput {
  const _ExternalVisaInput({
    required this.amount,
    required this.destination,
    required this.agentName,
    required this.withService,
    required this.profitPayer,
    required this.note,
  });

  final num amount;
  final String destination;
  final String agentName;
  final bool withService;
  final String profitPayer;
  final String note;
}

/// One-off withdrawal from an external purchase visa that is not registered.
class _ExternalVisaDialog extends StatefulWidget {
  const _ExternalVisaDialog({required this.showProfit});

  final bool showProfit;

  @override
  State<_ExternalVisaDialog> createState() => _ExternalVisaDialogState();
}

class _ExternalVisaDialogState extends State<_ExternalVisaDialog> {
  final amount = TextEditingController();
  final agent = TextEditingController();
  final note = TextEditingController();
  String destination = 'agent';
  bool withService = false;
  String profitPayer = 'agent';

  @override
  void dispose() {
    amount.dispose();
    agent.dispose();
    note.dispose();
    super.dispose();
  }

  bool get _toMachine => destination == 'machine';

  num? get _amount {
    final value = parseNum(amount.text.trim());
    return value == null || value <= 0 ? null : value;
  }

  bool get _canSave =>
      _amount != null && (_toMachine || agent.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final value = _amount;
    final profit = purchaseVisaCollectionProfit(value ?? 0, withService);
    final customerPays = _toMachine || profitPayer == 'customer';
    final customerCash = customerPays ? (value ?? 0) - profit : (value ?? 0);
    final agentCash = customerPays ? (value ?? 0) : (value ?? 0) + profit;

    return HesbaModalCard(
      title: 'فيزا مشتريات خارجية',
      subtitle:
          'فيزا مش متسجلة عندك: بتسحب منها على مندوب أو من أي ماكينة، وصاحبها بياخد فلوسه كاش من الخزنة.',
      actions: HesbaModalActions(
        primaryLabel: 'تأكيد السحب',
        primaryEnabled: _canSave,
        onPrimary: () => Navigator.pop(
          context,
          _ExternalVisaInput(
            amount: value!,
            destination: destination,
            agentName: agent.text.trim(),
            withService: withService,
            profitPayer: _toMachine ? 'customer' : profitPayer,
            note: note.text.trim(),
          ),
        ),
        onCancel: () => Navigator.pop(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HesbaModalField(
            label: 'المبلغ اللي هيتسحب من الفيزا',
            child: TextField(
              controller: amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: const [MoneyInputFormatter()],
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ChoiceTile(
                  title: 'على مندوب',
                  subtitle: 'المندوب بيدفع كاش للخزنة',
                  selected: !_toMachine,
                  onTap: () => setState(() => destination = 'agent'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ChoiceTile(
                  title: 'على ماكينة',
                  subtitle: 'بتسحبها من أي ماكينة',
                  selected: _toMachine,
                  onTap: () => setState(() => destination = 'machine'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_toMachine) ...[
            HesbaModalField(
              label: 'اسم المندوب',
              child: TextField(
                controller: agent,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: _ChoiceTile(
                  title: 'من غير خدمة',
                  subtitle: widget.showProfit ? '٢٠ جنيه لكل ألف' : null,
                  selected: !withService,
                  onTap: () => setState(() => withService = false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ChoiceTile(
                  title: 'بخدمة ماكينة',
                  subtitle: widget.showProfit ? '١٣ جنيه لكل ألف' : null,
                  selected: withService,
                  onTap: () => setState(() => withService = true),
                ),
              ),
            ],
          ),
          if (!_toMachine) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ChoiceTile(
                    title: 'المكسب على المندوب',
                    subtitle: 'صاحب الفيزا ياخد المبلغ كامل',
                    selected: profitPayer == 'agent',
                    onTap: () => setState(() => profitPayer = 'agent'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ChoiceTile(
                    title: 'المكسب على صاحب الفيزا',
                    subtitle: 'بيتخصم من اللي هياخده',
                    selected: profitPayer == 'customer',
                    onTap: () => setState(() => profitPayer = 'customer'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          HesbaModalField(
            label: 'ملاحظة',
            child: TextField(controller: note, maxLength: 300),
          ),
          const SizedBox(height: 8),
          HesbaModalCallout(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value == null
                      ? 'هيتسحب من الفيزا: —'
                      : 'هيتسحب من الفيزا: ${money(value)}',
                ),
                const SizedBox(height: 4),
                if (!_toMachine) ...[
                  Text(
                    value == null
                        ? 'المندوب يدفع للخزنة: —'
                        : 'المندوب يدفع للخزنة: ${money(agentCash)}',
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  value == null
                      ? 'صاحب الفيزا ياخد من الخزنة: —'
                      : 'صاحب الفيزا ياخد من الخزنة: ${money(customerCash)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (widget.showProfit) ...[
                  const SizedBox(height: 4),
                  Text(
                    value == null ? 'المكسب: —' : 'المكسب: ${money(profit)}',
                    style: const TextStyle(color: HesbaColors.tealDark),
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

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
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
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: HesbaText.bodyMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

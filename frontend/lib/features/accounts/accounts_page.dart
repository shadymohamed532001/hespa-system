import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/digits.dart';
import '../../core/utils/datetime_formatter.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/error_box.dart';
import '../../core/widgets/hesba_modal.dart';
import '../../core/widgets/metric_card.dart';
import '../../core/widgets/page_frame.dart';
import '../../core/widgets/soft_badge.dart';
import '../auth/session_controller.dart';
import '../../core/settings/tr.dart';
import 'fawry_cash_input.dart';
import 'fawry_today_operations_page.dart';
import 'profit_qr_commission.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key, required this.session, required this.kind});

  final SessionController session;
  final String kind;

  bool get isFawry => kind == 'fawry';
  bool get isProfitQr => kind == 'profit_qr';

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  List<dynamic> data = [];
  Map<String, num> todayDrops = {};
  String? dropsError;
  bool loading = true;
  String? error;
  bool _reviewingToday = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    var reportDropsError = false;
    try {
      data = await widget.session.api.list(
        ApiEndpoints.accountsList(
          includeInactive: widget.session.can(AppPermissions.manageAssets),
        ),
      );
      final drops = await _loadTodayDrops();
      todayDrops = drops.amounts;
      dropsError = drops.error;
      reportDropsError = widget.isFawry && drops.error != null;
      error = null;
    } catch (e) {
      error = ApiClient.errorMessage(e);
    }
    if (mounted) setState(() => loading = false);
    if (reportDropsError && mounted) {
      showAppSnack(context, dropsError!, error: true);
    }
  }

  List<dynamic> get _rows =>
      data.where((item) => item['type'] == widget.kind).toList();

  Future<({Map<String, num> amounts, String? error})> _loadTodayDrops() async {
    if (!widget.session.isAdmin) {
      return (amounts: <String, num>{}, error: null);
    }
    try {
      final payload = await widget.session.api.getMap(
        ApiEndpoints.fawryDailyDrops,
      );
      final drops = <String, num>{};
      for (final drop in (payload['drops'] as List? ?? const [])) {
        drops['${drop['accountId']}'] = num.tryParse('${drop['amount']}') ?? 0;
      }
      return (amounts: drops, error: null);
    } catch (exception) {
      return (
        amounts: <String, num>{},
        error: ApiClient.errorMessage(exception),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isFawry && _reviewingToday) {
      return FawryTodayOperationsPage(
        session: widget.session,
        onBack: () => setState(() => _reviewingToday = false),
      );
    }
    final rows = _rows;
    final isFawry = widget.isFawry;
    final isProfitQr = widget.isProfitQr;
    return PageFrame(
      title: isFawry
          ? 'حسابات فوري'
          : isProfitQr
          ? 'حسابات مكسب QR'
          : 'حسابات مكسب عادي',
      subtitle: !widget.session.isAdmin
          ? 'إدارة الحسابات والشحن والتحويلات'
          : isFawry
          ? widget.session.isAdmin
                ? 'عمولة فوري مش بتتحسب مع العملية. النزلة اليومية بتزيد رصيد الحساب'
                : 'متابعة الرصيد والترحيل لكل حساب'
          : isProfitQr
          ? 'العميل يحوّل على QR ثم يستلم كاش: عمولة العميل ٥ جنيه لحد ٥٠٠، و١٠ جنيه لحد ألف، وفوق ألف ١٠ جنيه لكل ألف، وخصم مكسب ٢ جنيه لكل ألف. التوريد من الحساب عليه خصم ٤ جنيه لكل ألف.'
          : 'حساب مكسب عادي. حد الرصيد قبل زيادة الشحن مليون جنيه. الشحن يضيف ٥ جنيه لكل ألف إلى رصيد الحساب، والتحويل يخصم ٤ جنيه لكل ألف من العمولات.',
      actions: [
        if (isFawry)
          IconButton.filledTonal(
            tooltip: 'عمليات فوري النهارده',
            onPressed: () => setState(() => _reviewingToday = true),
            icon: const Icon(Icons.receipt_long_outlined),
          ),
        if (widget.session.can(AppPermissions.manageAssets))
          OutlinedButton.icon(
            onPressed: () => _accountDialog(context),
            icon: const Icon(Icons.add, size: 18),
            label: Text(tr(ar: 'إضافة حساب', en: 'Add account')),
          ),
        if (isFawry && widget.session.isAdmin)
          OutlinedButton.icon(
            onPressed: loading ? null : _openDailyCommission,
            icon: const Icon(Icons.today_outlined, size: 18),
            label: const Text('عمولة فوري اليومية'),
          ),
        if (isProfitQr && widget.session.can(AppPermissions.useWallets))
          FilledButton.icon(
            onPressed: loading ? null : _profitQrCashOut,
            icon: const Icon(Icons.payments_outlined, size: 18),
            label: const Text('سحب كاش لعميل'),
          )
        else if (widget.session.can(AppPermissions.topUpAssets))
          FilledButton.icon(
            onPressed: () => _chooseTopUp(context),
            icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
            label: const Text('شحن حساب'),
          ),
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
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 1100
                        ? 4
                        : constraints.maxWidth >= 760
                        ? 2
                        : 1;
                    return GridView.count(
                      crossAxisCount: columns,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: columns == 1 ? 2.6 : 1.85,
                      children: [
                        MetricCard(
                          label: tr(ar: 'إجمالي الأرصدة', en: 'Total balances'),
                          value: money(
                            rows.fold<num>(
                              0,
                              (s, e) =>
                                  s + (num.tryParse('${e['balance']}') ?? 0),
                            ),
                          ),
                          note: isFawry
                              ? 'جميع حسابات فوري'
                              : isProfitQr
                              ? 'جميع حسابات مكسب QR'
                              : 'جميع حسابات المكسب العادي',
                        ),
                        if (widget.session.isAdmin)
                          MetricCard(
                            label: tr(ar: 'العمولات', en: 'Commissions'),
                            value: money(
                              rows.fold<num>(
                                0,
                                (s, e) =>
                                    s +
                                    (num.tryParse(
                                          '${e['commissionBalance']}',
                                        ) ??
                                        0),
                              ),
                            ),
                            note: isFawry
                                ? 'نزلة فوري داخلة في رصيد الحساب'
                                : isProfitQr
                                ? 'عمولة العميل للخزنة؛ خصم استقبال ٢ وتوريد ٤ لكل ألف'
                                : 'زيادة الشحن تدخل الرصيد، و٤ جنيه تخصم من العمولات لكل ألف تحويل',
                            accent: true,
                          ),
                        MetricCard(
                          label: 'عدد الحسابات',
                          value: '${rows.length}',
                          note: 'يشمل الحسابات الموقوفة',
                        ),
                        if (!isProfitQr)
                          MetricCard(
                            label: isFawry
                                ? 'الحد الأقصى لفوري'
                                : 'الحد الأقصى للمكسب',
                            value: isFawry ? '5,000,000 ج.م' : '1,000,000 ج.م',
                            note: isFawry
                                ? 'لكل حساب فوري'
                                : 'قبل إضافة زيادة الشحن',
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),
                _AccountsTable(
                  rows: rows,
                  canManage: widget.session.can(AppPermissions.manageAssets),
                  showProfits: widget.session.isAdmin,
                  limit: isProfitQr
                      ? null
                      : isFawry
                      ? _fawryLimit
                      : _profitLimit,
                  onManage: _manageAccount,
                ),
              ],
            ),
    );
  }

  Future<void> _manageAccount(Map<String, dynamic> account) async {
    final active = account['active'] == true;
    final balance = num.tryParse('${account['balance']}') ?? 0;
    final commission = num.tryParse('${account['commissionBalance']}') ?? 0;
    final canDelete =
        widget.session.can(AppPermissions.manageAssets) &&
        balance == 0 &&
        commission == 0;
    final typeLabel = _accountType('${account['type']}');

    final result = await showHesbaModal<_ManageAction>(
      context: context,
      builder: (ctx) => HesbaModalCard(
        title: 'إدارة ${account['name']}',
        subtitle: '$typeLabel · الرصيد الحالي ${money(balance)}',
        footer: Text(
          widget.session.isAdmin
              ? 'لا يمكن الحذف النهائي إلا إذا كان الرصيد والعمولة صفرًا ولا توجد أي حركات مرتبطة بالحساب.'
              : 'إدارة حالة الحساب مع الإبقاء على السجل والرصيد.',
          textAlign: TextAlign.center,
          style: HesbaText.caption,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HesbaModalCallout(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: active ? 'الحساب نشط. ' : 'الحساب موقوف. ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(
                      text: active
                          ? 'إيقافه يخفيه من التشغيل (الشحن والتحويلات) مع الإبقاء على السجل والرصيد ظاهرين في الإجماليات.'
                          : 'إعادة تفعيله ترجعه للظهور في التشغيل اليومي (الشحن والتحويلات).',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            HesbaModalActions(
              primaryLabel: active
                  ? 'إيقاف وإخفاء الحساب'
                  : tr(ar: 'إعادة تفعيل الحساب', en: 'Reactivate account'),
              onPrimary: () => Navigator.pop(
                ctx,
                active ? _ManageAction.deactivate : _ManageAction.activate,
              ),
              onCancel: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed:
                  !canDelete || !widget.session.can(AppPermissions.manageAssets)
                  ? null
                  : () async {
                      final confirmed = await showHesbaModal<bool>(
                        context: ctx,
                        maxWidth: 460,
                        builder: (confirmCtx) => HesbaModalCard(
                          title: tr(
                            ar: 'تأكيد الحذف النهائي',
                            en: 'Confirm permanent delete',
                          ),
                          subtitle:
                              'هل أنت متأكد من الحذف النهائي لـ «${account['name']}»؟ هذا الإجراء لا يمكن التراجع عنه.',
                          child: HesbaModalActions(
                            primaryLabel: tr(
                              ar: 'تأكيد الحذف',
                              en: 'Confirm delete',
                            ),
                            danger: true,
                            onPrimary: () => Navigator.pop(confirmCtx, true),
                            onCancel: () => Navigator.pop(confirmCtx, false),
                          ),
                        ),
                      );
                      if (confirmed == true && ctx.mounted) {
                        Navigator.pop(ctx, _ManageAction.delete);
                      }
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: HesbaColors.red,
                disabledForegroundColor: const Color(0xFFD4A0A0),
                side: BorderSide(
                  color: canDelete
                      ? const Color(0xFFE2B6B6)
                      : HesbaColors.border,
                ),
              ),
              child: Text(
                canDelete
                    ? tr(ar: 'حذف نهائي', en: 'Delete permanently')
                    : tr(
                        ar: 'الحذف النهائي غير متاح',
                        en: 'Permanent delete unavailable',
                      ),
              ),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    if (!mounted) return;
    switch (result) {
      case _ManageAction.activate:
        await _action(
          () => widget.session.api.patch(
            ApiEndpoints.accountStatus('${account['id']}'),
            {'active': true},
          ),
        );
      case _ManageAction.deactivate:
        await _action(
          () => widget.session.api.patch(
            ApiEndpoints.accountStatus('${account['id']}'),
            {'active': false},
          ),
        );
      case _ManageAction.delete:
        if (!widget.session.can(AppPermissions.manageAssets)) {
          showAppSnack(context, 'الحذف النهائي غير مسموح لحسابك', error: true);
          return;
        }
        try {
          final response = await widget.session.api.delete(
            ApiEndpoints.account('${account['id']}'),
          );
          await load();
          if (!mounted) return;
          final message = response is Map && response['message'] != null
              ? '${response['message']}'
              : 'تم الحذف النهائي للحساب بنجاح';
          showAppSnack(context, message);
        } catch (e) {
          if (mounted) {
            showAppSnack(context, ApiClient.errorMessage(e), error: true);
          }
        }
    }
  }

  Future<void> _accountDialog(BuildContext context) async {
    final name = TextEditingController();
    final opening = TextEditingController(text: '0');
    final type = widget.kind;
    final ok = await showHesbaModal<bool>(
      context: context,
      maxWidth: 520,
      builder: (ctx) => HesbaModalCard(
        title: tr(ar: 'إضافة حساب جديد', en: 'Add new account'),
        subtitle: tr(
          ar: 'أدخل بيانات الحساب ثم احفظه في النظام.',
          en: 'Enter account details then save it to the system.',
        ),
        actions: HesbaModalActions(
          primaryLabel: tr(ar: 'إضافة', en: 'Add'),
          onPrimary: () => Navigator.pop(ctx, true),
          onCancel: () => Navigator.pop(ctx, false),
        ),
        child: Column(
          children: [
            HesbaModalField(
              label: 'اسم الحساب *',
              child: TextField(
                controller: name,
                decoration: const InputDecoration(),
              ),
            ),
            const SizedBox(height: 18),
            HesbaModalField(
              label: tr(ar: 'الرصيد الافتتاحي *', en: 'Opening balance *'),
              child: TextField(
                controller: opening,
                keyboardType: TextInputType.number,
                inputFormatters: const [MoneyInputFormatter()],
                decoration: const InputDecoration(),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await _action(
        () => widget.session.api.post(ApiEndpoints.accounts, {
          'name': name.text,
          'type': type,
          'openingBalance': parseNum(opening.text) ?? 0,
        }),
      );
    }
  }

  Future<void> _chooseTopUp(BuildContext context) async {
    final active = _rows.where((e) => e['active'] == true).toList();
    if (active.isEmpty) {
      showAppSnack(context, 'لا يوجد حساب نشط للشحن', error: true);
      return;
    }
    var id = '${active.first['id']}';
    final amount = TextEditingController();
    final reference = TextEditingController();
    final depositorName = TextEditingController();
    var cashCounts = emptyFawryCashCounts();
    String? formError;
    bool selectedIsFawry() =>
        active.firstWhere((item) => '${item['id']}' == id)['type'] == 'fawry';
    final ok = await showHesbaModal<bool>(
      context: context,
      maxWidth: 620,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final isFawry = selectedIsFawry();
          return HesbaModalCard(
            title: isFawry ? 'تسجيل إيداع فوري' : 'شحن الحساب',
            subtitle: tr(
              ar: isFawry
                  ? 'اكتب اسم الشخص وعدد الورقات، والإجمالي هيتحسب تلقائيًا.'
                  : 'أضف رصيدًا مباشرًا للحساب المحدد.',
              en: isFawry
                  ? 'Enter the depositor name and the banknote counts.'
                  : 'Add balance directly to the selected account.',
            ),
            actions: HesbaModalActions(
              primaryLabel: isFawry
                  ? 'تسجيل الإيداع'
                  : tr(ar: 'إضافة الرصيد', en: 'Add balance'),
              onPrimary: () {
                if (isFawry && depositorName.text.trim().isEmpty) {
                  setLocal(
                    () => formError = 'اكتب اسم الشخص الذي قام بالإيداع',
                  );
                  return;
                }
                if (isFawry && fawryCashTotal(cashCounts) <= 0) {
                  setLocal(() => formError = 'اكتب عدد ورقة واحدة على الأقل');
                  return;
                }
                if (!isFawry && (parseNum(amount.text) ?? 0) <= 0) {
                  setLocal(() => formError = 'أدخل مبلغًا صحيحًا');
                  return;
                }
                Navigator.pop(ctx, true);
              },
              onCancel: () => Navigator.pop(ctx, false),
            ),
            child: Column(
              children: [
                HesbaModalField(
                  label: 'الحساب *',
                  child: DropdownButtonFormField<String>(
                    initialValue: id,
                    isExpanded: true,
                    decoration: const InputDecoration(),
                    items: [
                      for (final e in active)
                        DropdownMenuItem(
                          value: '${e['id']}',
                          child: Text('${e['name']} — ${money(e['balance'])}'),
                        ),
                    ],
                    onChanged: (v) => setLocal(() {
                      id = v!;
                      cashCounts = emptyFawryCashCounts();
                      formError = null;
                    }),
                  ),
                ),
                const SizedBox(height: 18),
                if (isFawry) ...[
                  HesbaModalField(
                    label: 'مين عمل الإيداع؟ *',
                    child: TextField(
                      controller: depositorName,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        hintText: 'اكتب اسم اللي عمل الإيداع',
                      ),
                      onChanged: (_) => setLocal(() => formError = null),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FawryCashInput(
                    key: ValueKey(id),
                    onChanged: (value) {
                      cashCounts = value;
                      if (formError != null) {
                        setLocal(() => formError = null);
                      }
                    },
                  ),
                ] else
                  HesbaModalField(
                    label: tr(ar: 'مبلغ الشحن *', en: 'Top-up amount *'),
                    child: TextField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      inputFormatters: const [MoneyInputFormatter()],
                      decoration: const InputDecoration(),
                      onChanged: (_) => setLocal(() => formError = null),
                    ),
                  ),
                if (!widget.isFawry && widget.session.isAdmin) ...[
                  const SizedBox(height: 10),
                  Text(
                    'كل ألف شحن يضيف ٥ جنيه زيادة على رصيد الحساب نفسه، وتقدر تستخدم الزيادة.',
                    style: HesbaText.caption,
                  ),
                ],
                const SizedBox(height: 18),
                HesbaModalField(
                  label: tr(
                    ar: 'رقم المرجع (اختياري)',
                    en: 'Reference number (optional)',
                  ),
                  child: TextField(
                    controller: reference,
                    decoration: const InputDecoration(),
                  ),
                ),
                if (formError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    formError!,
                    style: const TextStyle(color: HesbaColors.red),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
    if (ok == true) {
      final isFawry = selectedIsFawry();
      final referenceText = reference.text.trim();
      final parsedAmount = parseNum(amount.text) ?? 0;
      await _action(
        () => widget.session.api.post(
          isFawry
              ? ApiEndpoints.fawryDeposit(id)
              : ApiEndpoints.accountTopUp(id),
          isFawry
              ? {
                  'depositorName': depositorName.text.trim(),
                  'cashCounts': cashCounts,
                  if (referenceText.isNotEmpty) 'reference': referenceText,
                }
              : {
                  'amount': parsedAmount,
                  if (referenceText.isNotEmpty) 'reference': referenceText,
                },
        ),
      );
    }
    amount.dispose();
    depositorName.dispose();
    reference.dispose();
  }

  Future<void> _profitQrCashOut() async {
    final active = _rows.where((item) => item['active'] == true).toList();
    if (active.isEmpty) {
      showAppSnack(context, 'لا يوجد حساب مكسب QR نشط', error: true);
      return;
    }
    var id = '${active.first['id']}';
    final cashAmount = TextEditingController();
    final reference = TextEditingController();
    var commissionInCash = false;
    final ok = await showHesbaModal<bool>(
      context: context,
      maxWidth: 560,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final breakdown = profitQrCashOutBreakdown(
            parseNum(cashAmount.text.trim()),
            commissionInCash: commissionInCash,
          );
          return HesbaModalCard(
            title: 'سحب كاش لعميل من مكسب QR',
            subtitle:
                'اكتب المبلغ اللي العميل حوّله، واختار طريقة تحصيل عمولتك في الخزنة.',
            actions: HesbaModalActions(
              primaryLabel: 'تنفيذ العملية',
              primaryEnabled: breakdown != null && breakdown.cashAmount >= 0,
              onPrimary: () => Navigator.pop(ctx, true),
              onCancel: () => Navigator.pop(ctx, false),
            ),
            child: Column(
              children: [
                HesbaModalField(
                  label: 'حساب مكسب QR *',
                  child: DropdownButtonFormField<String>(
                    initialValue: id,
                    isExpanded: true,
                    decoration: const InputDecoration(),
                    items: [
                      for (final account in active)
                        DropdownMenuItem(
                          value: '${account['id']}',
                          child: Text(
                            '${account['name']} — ${money(account['balance'])}',
                          ),
                        ),
                    ],
                    onChanged: (value) => setLocal(() => id = value!),
                  ),
                ),
                const SizedBox(height: 18),
                HesbaModalField(
                  label: 'المبلغ المحوّل من العميل *',
                  child: TextField(
                    controller: cashAmount,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [MoneyInputFormatter()],
                    decoration: const InputDecoration(hintText: 'مثال: 1000'),
                    onChanged: (_) => setLocal(() {}),
                  ),
                ),
                const SizedBox(height: 18),
                SwitchListTile(
                  title: const Text('العمولة نقدًا من العميل'),
                  subtitle: Text(
                    commissionInCash
                        ? 'تسلّم العميل المبلغ كاملًا وتحصّل العمولة نقدًا للخزنة.'
                        : 'تخصم العمولة من الكاش اللي هتسلّمه للعميل وتفضل في الخزنة.',
                  ),
                  value: commissionInCash,
                  onChanged: (value) =>
                      setLocal(() => commissionInCash = value),
                ),
                HesbaModalField(
                  label: tr(
                    ar: 'رقم المرجع (اختياري)',
                    en: 'Reference number (optional)',
                  ),
                  child: TextField(
                    controller: reference,
                    decoration: const InputDecoration(),
                  ),
                ),
                const SizedBox(height: 18),
                if (breakdown != null && breakdown.cashAmount < 0)
                  const Text(
                    'المبلغ أقل من العمولة؛ اختار تحصيل العمولة نقدًا من العميل.',
                  ),
                HesbaModalCallout(
                  backgroundColor: breakdown == null
                      ? const Color(0xFFEEF4F7)
                      : HesbaColors.tealLight,
                  borderColor: breakdown == null
                      ? HesbaColors.border
                      : HesbaColors.teal,
                  child: Text(
                    breakdown == null
                        ? 'اكتب المبلغ المحوّل لعرض حساب العملية.'
                        : !widget.session.isAdmin
                        ? 'العميل يحوّل ${money(breakdown.customerTransferAmount)}\nتسلّم العميل ${money(breakdown.cashAmount)} كاش'
                        : 'العميل يحوّل ${money(breakdown.customerTransferAmount)}\n'
                              'تسلّم العميل ${money(breakdown.cashAmount)} كاش\n'
                              'عمولتك في الخزنة ${money(breakdown.customerCommission)}\n'
                              'خصم مكسب عند الدخول ${money(breakdown.providerIncomingFee)}\n'
                              'يدخل رصيد QR ${money(breakdown.creditedAmount)}',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (ok == true) {
      final referenceText = reference.text.trim();
      await _action(
        () => widget.session.api.post(ApiEndpoints.profitQrCashOut(id), {
          'cashAmount': parseNum(cashAmount.text.trim()),
          'commissionMethod': commissionInCash ? 'cash' : 'deduct',
          if (referenceText.isNotEmpty) 'reference': referenceText,
        }),
      );
    }
    cashAmount.dispose();
    reference.dispose();
  }

  Future<void> _openDailyCommission() async {
    final accounts = [
      for (final item in data)
        if (item is Map && item['type'] == 'fawry' && item['active'] == true)
          Map<String, dynamic>.from(item),
    ];
    if (accounts.isEmpty) {
      showAppSnack(context, 'مفيش حساب فوري نشط', error: true);
      return;
    }
    final amounts = await showHesbaModal<Map<String, num>>(
      context: context,
      maxWidth: 560,
      builder: (ctx) => _DailyCommissionDialog(
        accounts: accounts,
        todayDrops: todayDrops,
        dropsError: dropsError,
        todayLabel: formatDate(DateTime.now().toIso8601String()),
      ),
    );
    if (amounts == null || amounts.isEmpty || !mounted) return;
    await _action(() async {
      for (final entry in amounts.entries) {
        await widget.session.api.post(ApiEndpoints.fawryDailyDrop(entry.key), {
          'amount': entry.value,
        });
      }
    });
  }

  Future<void> _action(Future<dynamic> Function() operation) async {
    try {
      await operation();
      await load();
      if (mounted) showAppSnack(context, 'تم حفظ العملية بنجاح');
    } catch (e) {
      if (mounted) {
        showAppSnack(context, ApiClient.errorMessage(e), error: true);
      }
    }
  }
}

enum _ManageAction { activate, deactivate, delete }

class _DailyCommissionDialog extends StatefulWidget {
  const _DailyCommissionDialog({
    required this.accounts,
    required this.todayDrops,
    required this.dropsError,
    required this.todayLabel,
  });

  final List<Map<String, dynamic>> accounts;
  final Map<String, num> todayDrops;
  final String? dropsError;
  final String todayLabel;

  @override
  State<_DailyCommissionDialog> createState() => _DailyCommissionDialogState();
}

class _DailyCommissionDialogState extends State<_DailyCommissionDialog> {
  final _amount = TextEditingController();
  late String _accountId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _accountId = '${widget.accounts.first['id']}';
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  num? get _recorded => widget.todayDrops[_accountId];

  void _submit() {
    if (_recorded != null) return;
    final amount = parseNum(_amount.text.trim());
    if (amount == null || amount < 0) {
      setState(() => _error = 'اكتب عمولة صحيحة، أو 0 لو منزّلش حاجة');
      return;
    }
    Navigator.pop(context, {_accountId: amount});
  }

  @override
  Widget build(BuildContext context) {
    final recorded = _recorded;
    return HesbaModalCard(
      title: 'عمولة فوري اليومية',
      subtitle: 'تاريخ اليوم ${widget.todayLabel}',
      actions: HesbaModalActions(
        primaryLabel: 'تسجيل العمولة',
        primaryEnabled: recorded == null && widget.dropsError == null,
        onPrimary: _submit,
        onCancel: () => Navigator.pop(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HesbaModalCallout(
            child: Text(
              'اختار حساب فوري من القائمة، وبعدين اكتب العمولة اللي نزلت النهاردة. المبلغ يتضاف على رصيد الحساب.',
            ),
          ),
          const SizedBox(height: 18),
          HesbaModalField(
            label: 'الحساب *',
            child: DropdownButtonFormField<String>(
              key: ValueKey(_accountId),
              initialValue: _accountId,
              isExpanded: true,
              decoration: const InputDecoration(),
              items: [
                for (final account in widget.accounts)
                  DropdownMenuItem(
                    value: '${account['id']}',
                    child: Text(
                      '${account['name']} — ${money(account['balance'])}',
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _accountId = value;
                  _error = null;
                  _amount.clear();
                });
              },
            ),
          ),
          const SizedBox(height: 18),
          if (widget.dropsError != null)
            Text(
              widget.dropsError!,
              style: const TextStyle(color: HesbaColors.red),
            )
          else if (recorded != null)
            Text(
              'اتسجلت النهاردة ${money(recorded)}',
              style: HesbaText.tableCell.copyWith(color: HesbaColors.tealDark),
            )
          else
            HesbaModalField(
              label: 'العمولة كام *',
              child: TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: const [MoneyInputFormatter()],
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: HesbaColors.red)),
          ],
        ],
      ),
    );
  }
}

class _AccountsTable extends StatelessWidget {
  const _AccountsTable({
    required this.rows,
    required this.canManage,
    required this.showProfits,
    required this.limit,
    required this.onManage,
  });

  final List<dynamic> rows;
  final bool canManage;
  final bool showProfits;
  final num? limit;
  final Future<void> Function(Map<String, dynamic> account) onManage;

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
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFF2F5F8),
                ),
                headingRowHeight: 52,
                horizontalMargin: 20,
                columnSpacing: 28,
                dataRowMinHeight: 60,
                dataRowMaxHeight: 68,
                columns: [
                  DataColumn(label: Text('الحساب', style: _headerStyle)),
                  DataColumn(
                    label: Text(
                      tr(ar: 'الرصيد الحالي', en: 'Current balance'),
                      style: _headerStyle,
                    ),
                  ),
                  if (limit != null)
                    DataColumn(
                      label: Text('المتاح حتى الحد', style: _headerStyle),
                    ),
                  if (showProfits)
                    DataColumn(
                      label: Text(
                        tr(ar: 'العمولات', en: 'Commissions'),
                        style: _headerStyle,
                      ),
                    ),
                  DataColumn(
                    label: Text(
                      tr(ar: 'الحالة', en: 'Status'),
                      style: _headerStyle,
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      tr(ar: 'إدارة', en: 'Admin'),
                      style: _headerStyle,
                    ),
                  ),
                ],
                rows: [
                  for (final e in rows)
                    DataRow(
                      cells: [
                        DataCell(
                          Text('${e['name']}', style: HesbaText.tableEmphasis),
                        ),
                        DataCell(
                          Text(
                            money(e['balance']),
                            style: HesbaText.tableEmphasis,
                          ),
                        ),
                        if (limit != null)
                          DataCell(
                            Text(
                              money(
                                limit! - (num.tryParse('${e['balance']}') ?? 0),
                              ),
                              style: HesbaText.tableCell,
                            ),
                          ),
                        if (showProfits)
                          DataCell(
                            Text(
                              money(e['commissionBalance']),
                              style: HesbaText.tableEmphasis.copyWith(
                                color: HesbaColors.tealDark,
                              ),
                            ),
                          ),
                        DataCell(SoftBadge.status(active: e['active'] == true)),
                        DataCell(
                          canManage
                              ? OutlinedButton(
                                  onPressed: () =>
                                      onManage(e as Map<String, dynamic>),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: HesbaColors.ink,
                                    side: const BorderSide(
                                      color: HesbaColors.border,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    minimumSize: const Size(0, 36),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(tr(ar: 'إدارة', en: 'Admin')),
                                )
                              : const Text('—'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

const _fawryLimit = 5000000;
const _profitLimit = 1000000;

const _headerStyle = HesbaText.tableHeader;

String _accountType(String type) =>
    {
      'fawry': tr(ar: 'فوري', en: 'Fawry'),
      'company': tr(ar: 'شركة', en: 'Company'),
      'operating': tr(ar: 'تشغيلي', en: 'Operating'),
      'profit': tr(ar: 'مكسب عادي', en: 'Regular profit'),
      'profit_qr': tr(ar: 'مكسب QR', en: 'QR profit'),
    }[type] ??
    type;

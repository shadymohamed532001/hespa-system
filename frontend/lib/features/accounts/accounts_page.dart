import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
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

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key, required this.session});

  final SessionController session;

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  List<dynamic> data = [];
  Map<String, num> todayDrops = {};
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      data = await widget.session.api.list(
        ApiEndpoints.accountsList(
          includeInactive: widget.session.can(AppPermissions.manageAssets),
        ),
      );
      todayDrops = await _loadTodayDrops();
      error = null;
    } catch (e) {
      error = ApiClient.errorMessage(e);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<Map<String, num>> _loadTodayDrops() async {
    if (!widget.session.isAdmin) return {};
    try {
      final payload = await widget.session.api.getMap(
        ApiEndpoints.fawryDailyDrops,
      );
      final drops = <String, num>{};
      for (final drop in (payload['drops'] as List? ?? const [])) {
        drops['${drop['accountId']}'] = num.tryParse('${drop['amount']}') ?? 0;
      }
      return drops;
    } catch (_) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'حسابات فوري والشركات',
      subtitle: widget.session.isAdmin
          ? 'عمولة فوري مش بتتحسب مع العملية. النزلة اليومية بتزيد رصيد الحساب'
          : 'متابعة الرصيد والترحيل لكل حساب',
      actions: [
        if (widget.session.can(AppPermissions.manageAssets))
          OutlinedButton.icon(
            onPressed: () => _accountDialog(context),
            icon: const Icon(Icons.add, size: 18),
            label: Text(tr(ar: 'إضافة حساب', en: 'Add account')),
          ),
        if (widget.session.isAdmin)
          OutlinedButton.icon(
            onPressed: loading ? null : _openDailyCommission,
            icon: const Icon(Icons.today_outlined, size: 18),
            label: const Text('عمولة فوري اليومية'),
          ),
        if (widget.session.can(AppPermissions.topUpAssets))
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
                            data.fold<num>(
                              0,
                              (s, e) =>
                                  s + (num.tryParse('${e['balance']}') ?? 0),
                            ),
                          ),
                          note: 'جميع حسابات فوري والشركات',
                        ),
                        if (widget.session.isAdmin)
                          MetricCard(
                            label: tr(ar: 'العمولات', en: 'Commissions'),
                            value: money(
                              data.fold<num>(
                                0,
                                (s, e) =>
                                    s +
                                    (num.tryParse(
                                          '${e['commissionBalance']}',
                                        ) ??
                                        0),
                              ),
                            ),
                            note: 'نزلة فوري داخلة في رصيد الحساب',
                            accent: true,
                          ),
                        MetricCard(
                          label: 'عدد الحسابات',
                          value: '${data.length}',
                          note: 'يشمل الحسابات الموقوفة',
                        ),
                        const MetricCard(
                          label: 'الحد الأقصى لفوري',
                          value: '5,000,000 ج.م',
                          note: 'لكل حساب فوري',
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),
                _AccountsTable(
                  rows: data,
                  canManage: widget.session.can(AppPermissions.manageAssets),
                  showProfits: widget.session.isAdmin,
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
    final canDelete = widget.session.isAdmin && balance == 0 && commission == 0;
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
    var type = 'fawry';
    final ok = await showHesbaModal<bool>(
      context: context,
      maxWidth: 520,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => HesbaModalCard(
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
              SizedBox(height: 18),
              HesbaModalField(
                label: tr(ar: 'النوع *', en: 'Type *'),
                child: DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(),
                  items: [
                    DropdownMenuItem(
                      value: 'fawry',
                      child: Text(tr(ar: 'فوري', en: 'Fawry')),
                    ),
                    DropdownMenuItem(
                      value: 'company',
                      child: Text(tr(ar: 'شركة', en: 'Company')),
                    ),
                    DropdownMenuItem(
                      value: 'operating',
                      child: Text(tr(ar: 'تشغيلي', en: 'Operating')),
                    ),
                  ],
                  onChanged: (v) => setLocal(() => type = v!),
                ),
              ),
              const SizedBox(height: 18),
              HesbaModalField(
                label: tr(ar: 'الرصيد الافتتاحي *', en: 'Opening balance *'),
                child: TextField(
                  controller: opening,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      await _action(
        () => widget.session.api.post(ApiEndpoints.accounts, {
          'name': name.text,
          'type': type,
          'openingBalance': num.tryParse(opening.text) ?? 0,
        }),
      );
    }
  }

  Future<void> _chooseTopUp(BuildContext context) async {
    final active = data.where((e) => e['active'] == true).toList();
    if (active.isEmpty) {
      showAppSnack(context, 'لا يوجد حساب نشط للشحن', error: true);
      return;
    }
    var id = '${active.first['id']}';
    final amount = TextEditingController();
    final reference = TextEditingController();
    final ok = await showHesbaModal<bool>(
      context: context,
      maxWidth: 520,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => HesbaModalCard(
          title: 'شحن الحساب',
          subtitle: tr(
            ar: 'أضف رصيدًا مباشرًا للحساب المحدد.',
            en: 'Add balance directly to the selected account.',
          ),
          actions: HesbaModalActions(
            primaryLabel: tr(ar: 'إضافة الرصيد', en: 'Add balance'),
            onPrimary: () => Navigator.pop(ctx, true),
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
                  onChanged: (v) => setLocal(() => id = v!),
                ),
              ),
              SizedBox(height: 18),
              HesbaModalField(
                label: tr(ar: 'مبلغ الشحن *', en: 'Top-up amount *'),
                child: TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(),
                ),
              ),
              SizedBox(height: 18),
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
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      await _action(
        () => widget.session.api.post(ApiEndpoints.accountTopUp(id), {
          'amount': num.tryParse(amount.text) ?? 0,
          if (reference.text.isNotEmpty) 'reference': reference.text,
        }),
      );
    }
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
        todayLabel: formatDate(DateTime.now().toIso8601String()),
      ),
    );
    if (amounts == null || amounts.isEmpty || !mounted) return;
    await _action(() async {
      for (final entry in amounts.entries) {
        await widget.session.api.post(
          ApiEndpoints.fawryDailyDrop(entry.key),
          {'amount': entry.value},
        );
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
    required this.todayLabel,
  });

  final List<Map<String, dynamic>> accounts;
  final Map<String, num> todayDrops;
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
    final amount = num.tryParse(_amount.text.trim());
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
        primaryEnabled: recorded == null,
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
          if (recorded != null)
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
    required this.onManage,
  });

  final List<dynamic> rows;
  final bool canManage;
  final bool showProfits;
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
                          Text(
                            '${e['name']} · ${_accountType('${e['type']}')}',
                            style: HesbaText.tableEmphasis,
                          ),
                        ),
                        DataCell(
                          Text(
                            money(e['balance']),
                            style: HesbaText.tableEmphasis,
                          ),
                        ),
                        DataCell(
                          Text(
                            e['type'] == 'fawry'
                                ? money(
                                    _fawryLimit -
                                        (num.tryParse('${e['balance']}') ?? 0),
                                  )
                                : 'بدون حد محدد',
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

const _headerStyle = HesbaText.tableHeader;

String _accountType(String type) =>
    {
      'fawry': tr(ar: 'فوري', en: 'Fawry'),
      'company': tr(ar: 'شركة', en: 'Company'),
      'operating': tr(ar: 'تشغيلي', en: 'Operating'),
    }[type] ??
    type;

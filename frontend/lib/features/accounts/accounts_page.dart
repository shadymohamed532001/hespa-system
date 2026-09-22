import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/error_box.dart';
import '../../core/widgets/hesba_modal.dart';
import '../../core/widgets/metric_card.dart';
import '../../core/widgets/page_frame.dart';
import '../../core/widgets/soft_badge.dart';
import '../auth/session_controller.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key, required this.session});

  final SessionController session;

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  List<dynamic> data = [];
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
        ApiEndpoints.accountsList(includeInactive: widget.session.isAdmin),
      );
      error = null;
    } catch (e) {
      error = ApiClient.errorMessage(e);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'حسابات فوري والشركات',
      subtitle: 'متابعة الرصيد والترحيل والعمولات لكل حساب',
      actions: widget.session.isAdmin
          ? [
              OutlinedButton.icon(
                onPressed: () => _accountDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة حساب'),
              ),
              FilledButton.icon(
                onPressed: () => _chooseTopUp(context),
                icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                label: const Text('شحن حساب'),
              ),
            ]
          : const [],
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
                          label: 'إجمالي الأرصدة',
                          value: money(
                            data.fold<num>(
                              0,
                              (s, e) =>
                                  s + (num.tryParse('${e['balance']}') ?? 0),
                            ),
                          ),
                          note: 'جميع حسابات فوري والشركات',
                        ),
                        MetricCard(
                          label: 'العمولات',
                          value: money(
                            data.fold<num>(
                              0,
                              (s, e) =>
                                  s +
                                  (num.tryParse('${e['commissionBalance']}') ??
                                      0),
                            ),
                          ),
                          note: 'منفصلة عن أصل الرصيد',
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
                  isAdmin: widget.session.isAdmin,
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
    final canDelete = balance == 0 && commission == 0;
    final typeLabel = _accountType('${account['type']}');

    final result = await showHesbaModal<_ManageAction>(
      context: context,
      builder: (ctx) => HesbaModalCard(
        title: 'إدارة ${account['name']}',
        subtitle: '$typeLabel · الرصيد الحالي ${money(balance)}',
        footer: const Text(
          'لا يمكن الحذف النهائي إلا إذا كان الرصيد والعمولة صفرًا ولا توجد أي حركات مرتبطة بالحساب.',
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
                  : 'إعادة تفعيل الحساب',
              onPrimary: () => Navigator.pop(
                ctx,
                active ? _ManageAction.deactivate : _ManageAction.activate,
              ),
              onCancel: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: !canDelete || !widget.session.isAdmin
                  ? null
                  : () async {
                      final confirmed = await showHesbaModal<bool>(
                        context: ctx,
                        maxWidth: 460,
                        builder: (confirmCtx) => HesbaModalCard(
                          title: 'تأكيد الحذف النهائي',
                          subtitle:
                              'هل أنت متأكد من الحذف النهائي لـ «${account['name']}»؟ هذا الإجراء لا يمكن التراجع عنه.',
                          child: HesbaModalActions(
                            primaryLabel: 'تأكيد الحذف',
                            danger: true,
                            onPrimary: () =>
                                Navigator.pop(confirmCtx, true),
                            onCancel: () =>
                                Navigator.pop(confirmCtx, false),
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
                canDelete ? 'حذف نهائي' : 'الحذف النهائي غير متاح',
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
        if (!widget.session.isAdmin) {
          showAppSnack(
            context,
            'الحذف النهائي متاح للأدمن فقط',
            error: true,
          );
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
          title: 'إضافة حساب جديد',
          subtitle: 'أدخل بيانات الحساب ثم احفظه في النظام.',
          actions: HesbaModalActions(
            primaryLabel: 'إضافة',
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
                label: 'النوع *',
                child: DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(),
                  items: const [
                    DropdownMenuItem(value: 'fawry', child: Text('فوري')),
                    DropdownMenuItem(value: 'company', child: Text('شركة')),
                    DropdownMenuItem(
                      value: 'operating',
                      child: Text('تشغيلي'),
                    ),
                  ],
                  onChanged: (v) => setLocal(() => type = v!),
                ),
              ),
              const SizedBox(height: 18),
              HesbaModalField(
                label: 'الرصيد الافتتاحي *',
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
          subtitle: 'أضف رصيدًا مباشرًا للحساب المحدد.',
          actions: HesbaModalActions(
            primaryLabel: 'إضافة الرصيد',
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
              const SizedBox(height: 18),
              HesbaModalField(
                label: 'مبلغ الشحن *',
                child: TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(),
                ),
              ),
              const SizedBox(height: 18),
              HesbaModalField(
                label: 'رقم المرجع (اختياري)',
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

class _AccountsTable extends StatelessWidget {
  const _AccountsTable({
    required this.rows,
    required this.isAdmin,
    required this.onManage,
  });

  final List<dynamic> rows;
  final bool isAdmin;
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
                columns: const [
                  DataColumn(label: Text('الحساب', style: _headerStyle)),
                  DataColumn(label: Text('الرصيد الحالي', style: _headerStyle)),
                  DataColumn(
                    label: Text('المتاح حتى الحد', style: _headerStyle),
                  ),
                  DataColumn(label: Text('العمولات', style: _headerStyle)),
                  DataColumn(label: Text('الحالة', style: _headerStyle)),
                  DataColumn(label: Text('إدارة', style: _headerStyle)),
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
                          Text(money(e['balance']), style: HesbaText.tableEmphasis),
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
                        DataCell(
                          Text(
                            money(e['commissionBalance']),
                            style: HesbaText.tableEmphasis.copyWith(
                              color: HesbaColors.tealDark,
                            ),
                          ),
                        ),
                        DataCell(
                          SoftBadge.status(active: e['active'] == true),
                        ),
                        DataCell(
                          isAdmin
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
                                  child: const Text('إدارة'),
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
    {'fawry': 'فوري', 'company': 'شركة', 'operating': 'تشغيلي'}[type] ?? type;

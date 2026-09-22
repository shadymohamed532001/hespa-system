import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/error_box.dart';
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

    final result = await showDialog<_ManageAction>(
      context: context,
      barrierColor: const Color(0x990B2430),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'إدارة ${account['name']}',
                  style: HesbaText.modalTitle,
                ),
                const SizedBox(height: 6),
                Text(
                  '$typeLabel · الرصيد الحالي ${money(balance)}',
                  style: HesbaText.bodyMuted,
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF4F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: active ? 'الحساب نشط. ' : 'الحساب موقوف. ',
                          style: const TextStyle(
                            color: HesbaColors.ink,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        TextSpan(
                          text: active
                              ? 'إيقافه يخفيه من التشغيل (الشحن والتحويلات) مع الإبقاء على السجل والرصيد ظاهرين في الإجماليات.'
                              : 'إعادة تفعيله ترجعه للظهور في التشغيل اليومي (الشحن والتحويلات).',
                        ),
                      ],
                    ),
                    style: const TextStyle(
                      color: Color(0xFF425C6B),
                      fontSize: 13,
                      height: 1.55,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton(
                      onPressed: () => Navigator.pop(
                        ctx,
                        active
                            ? _ManageAction.deactivate
                            : _ManageAction.activate,
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                      child: Text(
                        active
                            ? 'إيقاف وإخفاء الحساب'
                            : 'إعادة تفعيل الحساب',
                      ),
                    ),
                    OutlinedButton(
                      onPressed: !canDelete || !widget.session.isAdmin
                          ? null
                          : () async {
                              final confirmed = await showDialog<bool>(
                                context: ctx,
                                builder: (confirmCtx) => AlertDialog(
                                  title: const Text('تأكيد الحذف النهائي'),
                                  content: Text(
                                    'هل أنت متأكد من الحذف النهائي لـ «${account['name']}»؟\n\nهذا الإجراء لا يمكن التراجع عنه، ومتاح للأدمن فقط عندما يكون الرصيد والعمولة صفرًا بدون أي حركات.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(confirmCtx, false),
                                      child: const Text('إلغاء'),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFFB95050),
                                      ),
                                      onPressed: () =>
                                          Navigator.pop(confirmCtx, true),
                                      child: const Text('تأكيد الحذف'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true && ctx.mounted) {
                                Navigator.pop(ctx, _ManageAction.delete);
                              }
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB95050),
                        disabledForegroundColor: const Color(0xFFD4A0A0),
                        side: BorderSide(
                          color: canDelete
                              ? const Color(0xFFE2B6B6)
                              : HesbaColors.border,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      child: Text(
                        canDelete
                            ? 'حذف نهائي'
                            : 'الحذف النهائي غير متاح',
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HesbaColors.ink,
                        side: const BorderSide(color: HesbaColors.border),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'لا يمكن الحذف النهائي إلا إذا كان الرصيد والعمولة صفرًا ولا توجد أي حركات مرتبطة بالحساب.',
                  textAlign: TextAlign.center,
                  style: HesbaText.caption,
                ),
              ],
            ),
          ),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('إضافة حساب جديد'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'اسم الحساب'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'النوع'),
                  items: const [
                    DropdownMenuItem(value: 'fawry', child: Text('فوري')),
                    DropdownMenuItem(value: 'company', child: Text('شركة')),
                    DropdownMenuItem(value: 'operating', child: Text('تشغيلي')),
                  ],
                  onChanged: (v) => setLocal(() => type = v!),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: opening,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الرصيد الافتتاحي',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إضافة'),
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('شحن حساب'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: id,
                  decoration: const InputDecoration(labelText: 'الحساب'),
                  items: [
                    for (final e in active)
                      DropdownMenuItem(
                        value: '${e['id']}',
                        child: Text('${e['name']} — ${money(e['balance'])}'),
                      ),
                  ],
                  onChanged: (v) => setLocal(() => id = v!),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'مبلغ الشحن'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reference,
                  decoration: const InputDecoration(
                    labelText: 'رقم المرجع (اختياري)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إضافة الرصيد'),
            ),
          ],
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

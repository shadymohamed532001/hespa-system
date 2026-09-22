import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/data_card.dart';
import '../../core/widgets/error_box.dart';
import '../../core/widgets/metric_card.dart';
import '../../core/widgets/page_frame.dart';
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
  Widget build(BuildContext context) => PageFrame(
    title: 'حسابات فوري والشركات',
    subtitle: 'متابعة الرصيد والترحيل والعمولات لكل حساب',
    actions: widget.session.isAdmin
        ? [
            OutlinedButton.icon(
              onPressed: () => _accountDialog(context, null),
              icon: const Icon(Icons.add),
              label: const Text('إضافة حساب'),
            ),
            FilledButton.icon(
              onPressed: () => _chooseTopUp(context),
              icon: const Icon(Icons.add_card),
              label: const Text('شحن حساب'),
            ),
          ]
        : [],
    child: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? ErrorBox(message: error!, retry: load)
        : Column(
            children: [
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.7,
                children: [
                  MetricCard(
                    label: 'إجمالي الأرصدة',
                    value: money(
                      data.fold<num>(
                        0,
                        (s, e) => s + (num.tryParse('${e['balance']}') ?? 0),
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
                            (num.tryParse('${e['commissionBalance']}') ?? 0),
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
              ),
              const SizedBox(height: 22),
              DataCard(
                columns: const [
                  'الحساب',
                  'النوع',
                  'مرحل من أمس',
                  'شحن اليوم',
                  'الرصيد الحالي',
                  'المتاح حتى الحد',
                  'العمولات',
                  'الحالة',
                ],
                rows: data.map((e) {
                  final fawry = e['type'] == 'fawry';
                  return [
                    '${e['name']}',
                    _accountType('${e['type']}'),
                    money(e['openingBalance']),
                    money(e['todayTopUp']),
                    money(e['balance']),
                    fawry
                        ? money(
                            5000000 - (num.tryParse('${e['balance']}') ?? 0),
                          )
                        : 'بدون حد محدد',
                    money(e['commissionBalance']),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StatusButton(
                          active: e['active'] == true,
                          enabled: widget.session.isAdmin,
                          onChanged: (value) async {
                            await widget.session.api.patch(
                              ApiEndpoints.accountStatus('${e['id']}'),
                              {'active': value},
                            );
                            await load();
                          },
                        ),
                        if (widget.session.isAdmin)
                          IconButton(
                            tooltip: 'حذف الحساب نهائيًا',
                            onPressed: () =>
                                _deleteAccount(e as Map<String, dynamic>),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Color(0xFFB42318),
                            ),
                          ),
                      ],
                    ),
                  ];
                }).toList(),
              ),
            ],
          ),
  );

  Future<void> _accountDialog(
    BuildContext context,
    Map<String, dynamic>? _,
  ) async {
    final name = TextEditingController();
    final opening = TextEditingController(text: '0');
    String type = 'fawry';
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
    if (data.isEmpty) return;
    String id = data.first['id'];
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
                DropdownButtonFormField(
                  initialValue: id,
                  decoration: const InputDecoration(labelText: 'الحساب'),
                  items: data
                      .where((e) => e['active'] == true)
                      .map<DropdownMenuItem<String>>(
                        (e) => DropdownMenuItem(
                          value: e['id'],
                          child: Text('${e['name']} — ${money(e['balance'])}'),
                        ),
                      )
                      .toList(),
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

  Future<void> _deleteAccount(Map<String, dynamic> account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحساب'),
        content: Text(
          'هل تريد حذف ${account['name']}؟ الحساب الذي له رصيد أو سجل حركات لا يُحذف، ويمكن إيقافه بدلًا من ذلك.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _action(
        () =>
            widget.session.api.delete(ApiEndpoints.account('${account['id']}')),
      );
    }
  }
}

String _accountType(String type) =>
    {'fawry': 'فوري', 'company': 'شركة', 'operating': 'تشغيلي'}[type] ?? type;

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.active,
    required this.enabled,
    required this.onChanged,
  });
  final bool active, enabled;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: enabled ? () => onChanged(!active) : null,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
      decoration: BoxDecoration(
        color: active ? HesbaColors.tealLight : const Color(0xFFFFEEEE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'نشط' : 'موقوف',
        style: TextStyle(
          color: active ? HesbaColors.teal : const Color(0xFFB42318),
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

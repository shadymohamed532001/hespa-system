import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/error_box.dart';
import '../../core/widgets/hesba_modal.dart';
import '../../core/widgets/page_frame.dart';
import '../../core/widgets/soft_badge.dart';
import '../auth/session_controller.dart';

class MachinesPage extends StatefulWidget {
  const MachinesPage({super.key, required this.session});

  final SessionController session;

  @override
  State<MachinesPage> createState() => _MachinesPageState();
}

class _MachinesPageState extends State<MachinesPage> {
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
        ApiEndpoints.machinesList(
          includeInactive: widget.session.can(AppPermissions.manageAssets),
        ),
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
      title: 'ماكينات شحن الرصيد',
      subtitle: 'متابعة كل ماكينة بصورة مستقلة',
      actions: [
        if (widget.session.can(AppPermissions.manageAssets))
          OutlinedButton.icon(
            onPressed: _addMachine,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('إضافة ماكينة'),
          ),
        if (widget.session.can(AppPermissions.topUpAssets))
          FilledButton.icon(
            onPressed: data.isEmpty ? null : _loadMachine,
            icon: const Icon(Icons.bolt_outlined, size: 18),
            label: const Text('شحن ماكينة'),
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
          : _MachinesTable(rows: data),
    );
  }

  Future<void> _addMachine() async {
    final name = TextEditingController();
    final opening = TextEditingController(text: '0');
    final ok = await showHesbaModal<bool>(
      context: context,
      maxWidth: 520,
      builder: (ctx) => HesbaModalCard(
        title: 'إضافة ماكينة شحن',
        subtitle: 'أنشئ ماكينة جديدة ومتابعة رصيدها بشكل مستقل.',
        actions: HesbaModalActions(
          primaryLabel: 'إضافة',
          onPrimary: () => Navigator.pop(ctx, true),
          onCancel: () => Navigator.pop(ctx, false),
        ),
        child: Column(
          children: [
            HesbaModalField(
              label: 'اسم الماكينة *',
              child: TextField(
                controller: name,
                decoration: const InputDecoration(
                  hintText: 'مثال: ماكينة شحن 02',
                ),
              ),
            ),
            const SizedBox(height: 18),
            HesbaModalField(
              label: 'الرصيد الافتتاحي',
              child: TextField(
                controller: opening,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (name.text.trim().isEmpty) {
      if (!mounted) return;
      showAppSnack(context, 'اسم الماكينة مطلوب', error: true);
      return;
    }
    try {
      await widget.session.api.post(ApiEndpoints.machines, {
        'name': name.text.trim(),
        'openingBalance': num.tryParse(opening.text) ?? 0,
      });
      await load();
      if (mounted) showAppSnack(context, 'تمت إضافة الماكينة بنجاح');
    } catch (e) {
      if (mounted) {
        showAppSnack(context, ApiClient.errorMessage(e), error: true);
      }
    }
  }

  Future<void> _loadMachine() async {
    if (data.isEmpty) return;
    final active = data.where((e) => e['active'] != false).toList();
    if (active.isEmpty) {
      showAppSnack(context, 'لا توجد ماكينة نشطة للشحن', error: true);
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
          title: 'شحن ماكينة',
          subtitle: 'يزيد الرصيد المتاح للماكينة',
          actions: HesbaModalActions(
            primaryLabel: 'تأكيد الشحن',
            onPrimary: () => Navigator.pop(ctx, true),
            onCancel: () => Navigator.pop(ctx, false),
          ),
          child: Column(
            children: [
              HesbaModalField(
                label: 'الماكينة *',
                child: DropdownButtonFormField<String>(
                  initialValue: id,
                  isExpanded: true,
                  decoration: const InputDecoration(),
                  items: [
                    for (final e in active)
                      DropdownMenuItem(
                        value: '${e['id']}',
                        child: Text(
                          '${e['name']} — متبقي ${money(e['remainingBalance'])}',
                        ),
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
    if (ok != true) return;
    try {
      await widget.session.api.post(ApiEndpoints.machineLoad(id), {
        'amount': num.tryParse(amount.text) ?? 0,
        if (reference.text.isNotEmpty) 'reference': reference.text,
      });
      await load();
      if (mounted) showAppSnack(context, 'تم شحن الماكينة بنجاح');
    } catch (e) {
      if (mounted) {
        showAppSnack(context, ApiClient.errorMessage(e), error: true);
      }
    }
  }
}

class _MachinesTable extends StatelessWidget {
  const _MachinesTable({required this.rows});

  final List<dynamic> rows;

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
                dataRowMinHeight: 58,
                dataRowMaxHeight: 64,
                columns: const [
                  DataColumn(
                    label: Text('الماكينة', style: HesbaText.tableHeader),
                  ),
                  DataColumn(
                    label: Text('المبلغ المشحون', style: HesbaText.tableHeader),
                  ),
                  DataColumn(
                    label: Text('المستخدم', style: HesbaText.tableHeader),
                  ),
                  DataColumn(
                    label: Text('المتبقي', style: HesbaText.tableHeader),
                  ),
                  DataColumn(
                    label: Text('العمولات', style: HesbaText.tableHeader),
                  ),
                  DataColumn(
                    label: Text('الحالة', style: HesbaText.tableHeader),
                  ),
                ],
                rows: [
                  for (final e in rows)
                    DataRow(
                      cells: [
                        DataCell(
                          Text(
                            '${e['name']}',
                            style: HesbaText.tableEmphasis,
                          ),
                        ),
                        DataCell(
                          Text(
                            money(e['loadedBalance']),
                            style: HesbaText.tableCell,
                          ),
                        ),
                        DataCell(
                          Text(
                            money(e['usedBalance']),
                            style: HesbaText.tableCell,
                          ),
                        ),
                        DataCell(
                          Text(
                            money(e['remainingBalance']),
                            style: HesbaText.tableEmphasis.copyWith(
                              color: HesbaColors.tealDark,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            money(e['commissionBalance']),
                            style: HesbaText.tableCell,
                          ),
                        ),
                        DataCell(
                          SoftBadge.status(active: e['active'] == true),
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

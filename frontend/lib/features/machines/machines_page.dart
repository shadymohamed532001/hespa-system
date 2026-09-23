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
import '../../core/settings/tr.dart';

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

  List<dynamic> get _active =>
      data.where((machine) => machine['active'] != false).toList();

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'ماكينات شحن الرصيد',
      subtitle:
          'اشحن رصيد الماكينة ثم سجّل كل عملية عميل: شحن رصيد، باقة، نت أرضي، أو تليفون أرضي',
      actions: [
        if (widget.session.can(AppPermissions.manageAssets))
          OutlinedButton.icon(
            onPressed: _addMachine,
            icon: const Icon(Icons.add, size: 18),
            label: Text(tr(ar: 'إضافة ماكينة', en: 'Add machine')),
          ),
        if (widget.session.can(AppPermissions.topUpAssets))
          FilledButton.tonalIcon(
            onPressed: _active.isEmpty ? null : _loadMachine,
            icon: const Icon(Icons.bolt_outlined, size: 18),
            label: const Text('شحن ماكينة'),
          ),
        if (widget.session.can(AppPermissions.useMachines))
          FilledButton.icon(
            onPressed: _active.isEmpty ? null : _useMachine,
            icon: const Icon(Icons.phone_android_outlined, size: 18),
            label: Text(tr(ar: 'استخدام ماكينة', en: 'Machine usage')),
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
          : _MachinesTable(
              rows: data,
              canManage: widget.session.can(AppPermissions.manageAssets),
              showProfits: widget.session.isAdmin,
              onManage: _manageMachine,
            ),
    );
  }

  Future<void> _manageMachine(Map<String, dynamic> machine) async {
    final active = machine['active'] == true;
    final loaded = num.tryParse('${machine['loadedBalance']}') ?? 0;
    final used = num.tryParse('${machine['usedBalance']}') ?? 0;
    final remaining = num.tryParse('${machine['remainingBalance']}') ?? 0;
    final commission = num.tryParse('${machine['commissionBalance']}') ?? 0;
    final canDelete =
        widget.session.isAdmin && loaded == 0 && used == 0 && commission == 0;

    final result = await showHesbaModal<_MachineAction>(
      context: context,
      builder: (ctx) => HesbaModalCard(
        title: 'إدارة ${machine['name']}',
        subtitle: widget.session.isAdmin
            ? 'المتبقي ${money(remaining)} · العمولات ${money(commission)}'
            : 'المتبقي ${money(remaining)}',
        footer: const Text(
          'الحذف النهائي متاح فقط عندما تكون كل الأرصدة صفرًا ولا توجد أي حركات مرتبطة بالماكينة.',
          textAlign: TextAlign.center,
          style: HesbaText.caption,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(ctx, _MachineAction.rename),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('تعديل اسم الماكينة'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.pop(
                ctx,
                active ? _MachineAction.deactivate : _MachineAction.activate,
              ),
              icon: Icon(
                active ? Icons.pause_circle_outline : Icons.play_circle_outline,
                size: 18,
              ),
              label: Text(
                active
                    ? 'إيقاف وإخفاء الماكينة'
                    : tr(ar: 'إعادة تفعيل الماكينة', en: 'Reactivate machine'),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: !canDelete
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
                              'هل أنت متأكد من حذف «${machine['name']}» نهائيًا؟ هذا الإجراء لا يمكن التراجع عنه.',
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
                        Navigator.pop(ctx, _MachineAction.delete);
                      }
                    },
              icon: const Icon(Icons.delete_outline, size: 18),
              style: OutlinedButton.styleFrom(
                foregroundColor: HesbaColors.red,
                disabledForegroundColor: const Color(0xFFD4A0A0),
                side: BorderSide(
                  color: canDelete
                      ? const Color(0xFFE2B6B6)
                      : HesbaColors.border,
                ),
              ),
              label: Text(
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

    if (result == null || !mounted) return;
    switch (result) {
      case _MachineAction.rename:
        await _renameMachine(machine);
      case _MachineAction.activate:
        await _machineAction(
          () => widget.session.api.patch(
            ApiEndpoints.machineStatus('${machine['id']}'),
            {'active': true},
          ),
          'تم تفعيل الماكينة بنجاح',
        );
      case _MachineAction.deactivate:
        await _machineAction(
          () => widget.session.api.patch(
            ApiEndpoints.machineStatus('${machine['id']}'),
            {'active': false},
          ),
          'تم إيقاف الماكينة بنجاح',
        );
      case _MachineAction.delete:
        await _machineAction(
          () => widget.session.api.delete(
            ApiEndpoints.machine('${machine['id']}'),
          ),
          'تم حذف الماكينة نهائيًا',
        );
    }
  }

  Future<void> _renameMachine(Map<String, dynamic> machine) async {
    final name = TextEditingController(text: '${machine['name']}');
    final ok = await showHesbaModal<bool>(
      context: context,
      maxWidth: 520,
      builder: (ctx) => HesbaModalCard(
        title: 'تعديل اسم الماكينة',
        subtitle: 'سيظهر الاسم الجديد في شاشة الماكينات والعمليات القادمة.',
        actions: HesbaModalActions(
          primaryLabel: 'حفظ التعديل',
          onPrimary: () => Navigator.pop(ctx, true),
          onCancel: () => Navigator.pop(ctx, false),
        ),
        child: HesbaModalField(
          label: 'اسم الماكينة *',
          child: TextField(
            controller: name,
            autofocus: true,
            decoration: const InputDecoration(),
          ),
        ),
      ),
    );
    if (ok != true) return;
    final newName = name.text.trim();
    if (newName.isEmpty) {
      if (mounted) showAppSnack(context, 'اسم الماكينة مطلوب', error: true);
      return;
    }
    await _machineAction(
      () => widget.session.api.patch(ApiEndpoints.machine('${machine['id']}'), {
        'name': newName,
      }),
      'تم تعديل اسم الماكينة بنجاح',
    );
  }

  Future<void> _machineAction(
    Future<dynamic> Function() operation,
    String successMessage,
  ) async {
    try {
      final response = await operation();
      await load();
      if (!mounted) return;
      final message = response is Map && response['message'] != null
          ? '${response['message']}'
          : successMessage;
      showAppSnack(context, message);
    } catch (e) {
      if (mounted) {
        showAppSnack(context, ApiClient.errorMessage(e), error: true);
      }
    }
  }

  Future<void> _addMachine() async {
    final name = TextEditingController();
    final opening = TextEditingController(text: '0');
    final ok = await showHesbaModal<bool>(
      context: context,
      maxWidth: 520,
      builder: (ctx) => HesbaModalCard(
        title: tr(ar: 'إضافة ماكينة شحن', en: 'Add top-up machine'),
        subtitle: tr(
          ar: 'أنشئ ماكينة جديدة ومتابعة رصيدها بشكل مستقل.',
          en: 'Create a new machine and track its balance independently.',
        ),
        actions: HesbaModalActions(
          primaryLabel: tr(ar: 'إضافة', en: 'Add'),
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
    if (_active.isEmpty) {
      showAppSnack(context, 'لا توجد ماكينة نشطة للشحن', error: true);
      return;
    }
    var id = '${_active.first['id']}';
    final amount = TextEditingController();
    final reference = TextEditingController();
    final ok = await showHesbaModal<bool>(
      context: context,
      maxWidth: 520,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => HesbaModalCard(
          title: 'شحن ماكينة',
          subtitle: 'يزيد الرصيد المتاح للماكينة قبل خدمة العملاء',
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
                    for (final e in _active)
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

  Future<void> _useMachine() async {
    if (_active.isEmpty) {
      showAppSnack(context, 'لا توجد ماكينة نشطة للاستخدام', error: true);
      return;
    }
    var id = '${_active.first['id']}';
    var serviceType = _machineServiceTypes.first.key;
    final customerNumber = TextEditingController();
    final amount = TextEditingController();
    final commission = TextEditingController(text: '0');
    final reference = TextEditingController();
    final ok = await showHesbaModal<bool>(
      context: context,
      maxWidth: 540,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => HesbaModalCard(
          title: tr(ar: 'استخدام ماكينة', en: 'Machine usage'),
          subtitle:
              'سجّل عملية العميل من رصيد الماكينة: شحن رصيد، باقة، نت أرضي، أو تليفون أرضي',
          actions: HesbaModalActions(
            primaryLabel: tr(ar: 'تنفيذ العملية', en: 'Execute operation'),
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
                    for (final e in _active)
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
                label: 'نوع الخدمة *',
                child: DropdownButtonFormField<String>(
                  initialValue: serviceType,
                  isExpanded: true,
                  decoration: const InputDecoration(),
                  items: [
                    for (final option in _machineServiceTypes)
                      DropdownMenuItem(
                        value: option.key,
                        child: Text(option.label),
                      ),
                  ],
                  onChanged: (v) => setLocal(() => serviceType = v!),
                ),
              ),
              const SizedBox(height: 18),
              HesbaModalField(
                label: 'رقم العميل / الخط *',
                child: TextField(
                  controller: customerNumber,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: 'مثال: 010xxxxxxxx أو رقم الخط الأرضي',
                  ),
                ),
              ),
              SizedBox(height: 18),
              HesbaModalField(
                label: tr(ar: 'المبلغ *', en: 'Amount *'),
                child: TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(),
                ),
              ),
              SizedBox(height: 18),
              HesbaModalField(
                label: tr(ar: 'العمولة', en: 'Commission'),
                child: TextField(
                  controller: commission,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
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
                  decoration: const InputDecoration(
                    hintText: 'رقم العملية من الماكينة إن وُجد',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    final number = customerNumber.text.trim();
    if (number.isEmpty) {
      if (mounted) {
        showAppSnack(context, 'رقم العميل أو التليفون مطلوب', error: true);
      }
      return;
    }
    try {
      await widget.session.api.post(ApiEndpoints.machineUse(id), {
        'serviceType': serviceType,
        'customerNumber': number,
        'amount': num.tryParse(amount.text.trim()) ?? 0,
        'commission': num.tryParse(commission.text.trim()) ?? 0,
        if (reference.text.trim().isNotEmpty)
          'reference': reference.text.trim(),
      });
      await load();
      if (mounted) showAppSnack(context, 'تم تسجيل استخدام الماكينة');
    } catch (e) {
      if (mounted) {
        showAppSnack(context, ApiClient.errorMessage(e), error: true);
      }
    }
  }
}

class _MachineServiceOption {
  const _MachineServiceOption(this.key, this.label);
  final String key;
  final String label;
}

const _machineServiceTypes = [
  _MachineServiceOption('mobile_credit', 'شحن رصيد موبايل'),
  _MachineServiceOption('mobile_package', 'تجديد باقة موبايل'),
  _MachineServiceOption('landline_internet', 'تجديد إنترنت أرضي'),
  _MachineServiceOption('landline_phone', 'سداد تليفون أرضي'),
  _MachineServiceOption('other', 'خدمة أخرى'),
];

class _MachinesTable extends StatelessWidget {
  const _MachinesTable({
    required this.rows,
    required this.canManage,
    required this.showProfits,
    required this.onManage,
  });

  final List<dynamic> rows;
  final bool canManage;
  final bool showProfits;
  final Future<void> Function(Map<String, dynamic> machine) onManage;

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
                columns: [
                  DataColumn(
                    label: Text('الماكينة', style: HesbaText.tableHeader),
                  ),
                  DataColumn(
                    label: Text('المبلغ المشحون', style: HesbaText.tableHeader),
                  ),
                  DataColumn(
                    label: Text(
                      tr(ar: 'المستخدم', en: 'User'),
                      style: HesbaText.tableHeader,
                    ),
                  ),
                  DataColumn(
                    label: Text('المتبقي', style: HesbaText.tableHeader),
                  ),
                  if (showProfits)
                    DataColumn(
                      label: Text(
                        tr(ar: 'العمولات', en: 'Commissions'),
                        style: HesbaText.tableHeader,
                      ),
                    ),
                  DataColumn(
                    label: Text(
                      tr(ar: 'الحالة', en: 'Status'),
                      style: HesbaText.tableHeader,
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      tr(ar: 'إدارة', en: 'Admin'),
                      style: HesbaText.tableHeader,
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
                        if (showProfits)
                          DataCell(
                            Text(
                              money(e['commissionBalance']),
                              style: HesbaText.tableCell,
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

enum _MachineAction { rename, activate, deactivate, delete }

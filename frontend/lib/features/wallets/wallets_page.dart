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

class WalletsPage extends StatefulWidget {
  const WalletsPage({super.key, required this.session, this.onOpenLedger});

  final SessionController session;
  final VoidCallback? onOpenLedger;

  @override
  State<WalletsPage> createState() => _WalletsPageState();
}

class _WalletsPageState extends State<WalletsPage> {
  List<dynamic> data = [];
  List<dynamic> ledger = [];
  bool loading = true;
  String? error;

  List<dynamic> get _active =>
      data.where((wallet) => wallet['active'] == true).toList();

  List<dynamic> get _walletLedger =>
      ledger.where((entry) => entry['entityType'] == 'wallet').take(8).toList();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final values = await Future.wait([
        widget.session.api.list(
          ApiEndpoints.walletsList(
            includeInactive: widget.session.can(AppPermissions.manageAssets),
          ),
        ),
        widget.session.api.list(ApiEndpoints.ledgerList(limit: 100)),
      ]);
      data = values[0];
      ledger = values[1];
      error = null;
    } catch (exception) {
      error = ApiClient.errorMessage(exception);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'المحافظ الإلكترونية وInstaPay',
    subtitle: tr(
      ar: 'أضف كل رقم أو حساب بشكل مستقل، ثم اشحنه أو استخدمه وسجّل العمولة',
      en: 'Add each number or account separately, then top it up or use it and record commission',
    ),
    actions: [
      if (widget.onOpenLedger != null)
        OutlinedButton.icon(
          onPressed: widget.onOpenLedger,
          icon: const Icon(Icons.receipt_long_outlined, size: 18),
          label: Text(tr(ar: 'سجل العمليات', en: 'Ledger')),
        ),
      if (widget.session.can(AppPermissions.manageAssets))
        OutlinedButton.icon(
          onPressed: _addWallet,
          icon: const Icon(Icons.add, size: 18),
          label: Text(tr(ar: 'إضافة محفظة', en: 'Add wallet')),
        ),
      if (widget.session.can(AppPermissions.topUpAssets))
        FilledButton.tonalIcon(
          onPressed: _active.isEmpty ? null : _topUpWallet,
          icon: const Icon(Icons.add_card_outlined, size: 18),
          label: Text(tr(ar: 'شحن محفظة', en: 'Wallet top-up')),
        ),
      if (widget.session.can(AppPermissions.useWallets))
        FilledButton.icon(
          onPressed: _active.isEmpty ? null : _useWallet,
          icon: const Icon(Icons.send_outlined, size: 18),
          label: Text(tr(ar: 'استخدام محفظة', en: 'Wallet usage')),
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
                      : constraints.maxWidth >= 720
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
                            (total, wallet) =>
                                total +
                                (num.tryParse('${wallet['balance']}') ?? 0),
                          ),
                        ),
                        note: 'كل المحافظ المسجلة',
                      ),
                      if (widget.session.isAdmin)
                        MetricCard(
                          label: tr(
                            ar: 'إجمالي العمولات',
                            en: 'Total commissions',
                          ),
                          value: money(
                            data.fold<num>(
                              0,
                              (total, wallet) =>
                                  total +
                                  (num.tryParse(
                                        '${wallet['commissionBalance']}',
                                      ) ??
                                      0),
                            ),
                          ),
                          note: 'من عمليات استخدام المحافظ',
                          accent: true,
                        ),
                      MetricCard(
                        label: 'الحد اليومي للشحن',
                        value: '60,000 ج.م',
                        note: tr(ar: 'لكل محفظة', en: 'Per wallet'),
                      ),
                      MetricCard(
                        label: 'الحد الشهري للشحن',
                        value: '200,000 ج.م',
                        note: tr(ar: 'لكل محفظة', en: 'Per wallet'),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),
              _WalletsTable(
                rows: data,
                canManage: widget.session.can(AppPermissions.manageAssets),
                showProfits: widget.session.isAdmin,
                onManage: _manageWallet,
              ),
              const SizedBox(height: 22),
              _WalletMovements(
                entries: _walletLedger,
                showProfits: widget.session.isAdmin,
                onOpenLedger: widget.onOpenLedger,
              ),
            ],
          ),
  );

  Future<void> _addWallet() async {
    final name = TextEditingController();
    final ownerName = TextEditingController();
    final opening = TextEditingController(text: '0');
    var type = 'vodafone_cash';
    final ok = await showHesbaModal<bool>(
      context: context,
      maxWidth: 540,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => HesbaModalCard(
          title: tr(ar: 'إضافة محفظة جديدة', en: 'Add new wallet'),
          subtitle: 'سجّل كل رقم محفظة أو حساب InstaPay بصورة مستقلة.',
          actions: HesbaModalActions(
            primaryLabel: tr(ar: 'إضافة المحفظة', en: 'Add wallet'),
            onPrimary: () => Navigator.pop(ctx, true),
            onCancel: () => Navigator.pop(ctx, false),
          ),
          child: Column(
            children: [
              HesbaModalField(
                label: 'الشركة أو النوع *',
                child: DropdownButtonFormField<String>(
                  initialValue: type,
                  isExpanded: true,
                  items: [
                    for (final entry in _walletTypes.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: (value) => setLocal(() => type = value!),
                ),
              ),
              const SizedBox(height: 18),
              HesbaModalField(
                label: 'رقم المحفظة أو عنوان InstaPay *',
                child: TextField(
                  controller: name,
                  decoration: const InputDecoration(
                    hintText: 'مثال: 010xxxxxxx أو username@instapay',
                  ),
                ),
              ),
              const SizedBox(height: 18),
              HesbaModalField(
                label: 'المحفظة باسم مين؟ *',
                child: TextField(
                  controller: ownerName,
                  decoration: const InputDecoration(
                    hintText: 'اكتب اسم صاحب المحفظة المسجل',
                  ),
                ),
              ),
              const SizedBox(height: 18),
              HesbaModalField(
                label: 'الرصيد الافتتاحي',
                child: TextField(
                  controller: opening,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    if (name.text.trim().length < 2) {
      if (mounted) {
        showAppSnack(
          context,
          'اكتب رقم المحفظة أو عنوان InstaPay',
          error: true,
        );
      }
      return;
    }
    if (ownerName.text.trim().length < 2) {
      if (mounted) {
        showAppSnack(context, 'اكتب اسم صاحب المحفظة', error: true);
      }
      return;
    }
    await _action(
      () => widget.session.api.post(ApiEndpoints.wallets, {
        'name': name.text.trim(),
        'ownerName': ownerName.text.trim(),
        'type': type,
        'openingBalance': num.tryParse(opening.text.trim()) ?? 0,
      }),
      'تمت إضافة المحفظة بنجاح',
    );
  }

  Future<void> _topUpWallet() async {
    var id = '${_active.first['id']}';
    final amount = TextEditingController();
    final reference = TextEditingController();
    final ok = await showHesbaModal<bool>(
      context: context,
      maxWidth: 540,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => HesbaModalCard(
          title: tr(ar: 'شحن محفظة', en: 'Wallet top-up'),
          subtitle: 'الحد اليومي 60,000 والشهري 200,000 ج.م لكل محفظة.',
          actions: HesbaModalActions(
            primaryLabel: tr(ar: 'إضافة الرصيد', en: 'Add balance'),
            onPrimary: () => Navigator.pop(ctx, true),
            onCancel: () => Navigator.pop(ctx, false),
          ),
          child: _WalletOperationFields(
            wallets: _active,
            selectedId: id,
            onSelected: (value) => setLocal(() => id = value),
            amount: amount,
            reference: reference,
          ),
        ),
      ),
    );
    if (ok != true) return;
    await _action(
      () => widget.session.api.post(ApiEndpoints.walletTopUp(id), {
        'amount': num.tryParse(amount.text.trim()) ?? 0,
        if (reference.text.trim().isNotEmpty)
          'reference': reference.text.trim(),
      }),
      'تم شحن المحفظة بنجاح',
    );
  }

  Future<void> _useWallet() async {
    var id = '${_active.first['id']}';
    final amount = TextEditingController();
    final commission = TextEditingController(text: '0');
    final reference = TextEditingController();
    final purpose = TextEditingController();
    final ok = await showHesbaModal<bool>(
      context: context,
      maxWidth: 540,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => HesbaModalCard(
          title: tr(ar: 'استخدام محفظة', en: 'Wallet usage'),
          subtitle:
              'استخدم الرصيد في تحويل أو دفع، وسجّل العمولة والمرجع للمراجعة.',
          actions: HesbaModalActions(
            primaryLabel: tr(ar: 'تنفيذ العملية', en: 'Execute operation'),
            onPrimary: () => Navigator.pop(ctx, true),
            onCancel: () => Navigator.pop(ctx, false),
          ),
          child: Column(
            children: [
              _WalletOperationFields(
                wallets: _active,
                selectedId: id,
                onSelected: (value) => setLocal(() => id = value),
                amount: amount,
                reference: reference,
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
              const SizedBox(height: 18),
              HesbaModalField(
                label: 'الغرض أو المستفيد (اختياري)',
                child: TextField(
                  controller: purpose,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    hintText: 'تحويل لعميل، دفع فاتورة…',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    await _action(
      () => widget.session.api.post(ApiEndpoints.walletUse(id), {
        'amount': num.tryParse(amount.text.trim()) ?? 0,
        'commission': num.tryParse(commission.text.trim()) ?? 0,
        if (reference.text.trim().isNotEmpty)
          'reference': reference.text.trim(),
        if (purpose.text.trim().isNotEmpty) 'purpose': purpose.text.trim(),
      }),
      'تم تسجيل استخدام المحفظة',
    );
  }

  Future<void> _manageWallet(Map<String, dynamic> wallet) async {
    final active = wallet['active'] == true;
    final balance = num.tryParse('${wallet['balance']}') ?? 0;
    final commission = num.tryParse('${wallet['commissionBalance']}') ?? 0;
    final canDelete = widget.session.isAdmin && balance == 0 && commission == 0;
    final result = await showHesbaModal<_WalletAction>(
      context: context,
      builder: (ctx) => HesbaModalCard(
        title: 'إدارة ${wallet['name']}',
        subtitle:
            '${_walletType('${wallet['type']}')} · باسم ${_ownerName(wallet)} · الرصيد ${money(balance)}',
        footer: Text(
          widget.session.isAdmin
              ? 'الحذف النهائي متاح فقط عندما يكون الرصيد والعمولة صفرًا ولا توجد حركات مرتبطة بالمحفظة.'
              : 'إدارة حالة المحفظة مع الإبقاء على السجل والرصيد.',
          textAlign: TextAlign.center,
          style: HesbaText.caption,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => Navigator.pop(
                ctx,
                active ? _WalletAction.deactivate : _WalletAction.activate,
              ),
              icon: Icon(
                active ? Icons.pause_circle_outline : Icons.play_circle_outline,
              ),
              label: Text(
                active ? 'إيقاف وإخفاء المحفظة' : 'إعادة تفعيل المحفظة',
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
                              'هل أنت متأكد من حذف «${wallet['name']}» نهائيًا؟',
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
                        Navigator.pop(ctx, _WalletAction.delete);
                      }
                    },
              icon: const Icon(Icons.delete_outline),
              style: OutlinedButton.styleFrom(
                foregroundColor: HesbaColors.red,
                disabledForegroundColor: const Color(0xFFD4A0A0),
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
      case _WalletAction.activate:
        await _action(
          () => widget.session.api.patch(
            ApiEndpoints.walletStatus('${wallet['id']}'),
            {'active': true},
          ),
          'تم تفعيل المحفظة',
        );
      case _WalletAction.deactivate:
        await _action(
          () => widget.session.api.patch(
            ApiEndpoints.walletStatus('${wallet['id']}'),
            {'active': false},
          ),
          'تم إيقاف المحفظة',
        );
      case _WalletAction.delete:
        await _action(
          () =>
              widget.session.api.delete(ApiEndpoints.wallet('${wallet['id']}')),
          'تم حذف المحفظة نهائيًا',
        );
    }
  }

  Future<void> _action(
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
    } catch (exception) {
      if (mounted) {
        showAppSnack(context, ApiClient.errorMessage(exception), error: true);
      }
    }
  }
}

class _WalletOperationFields extends StatelessWidget {
  const _WalletOperationFields({
    required this.wallets,
    required this.selectedId,
    required this.onSelected,
    required this.amount,
    required this.reference,
  });

  final List<dynamic> wallets;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final TextEditingController amount;
  final TextEditingController reference;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      HesbaModalField(
        label: 'المحفظة *',
        child: DropdownButtonFormField<String>(
          initialValue: selectedId,
          isExpanded: true,
          items: [
            for (final wallet in wallets)
              DropdownMenuItem(
                value: '${wallet['id']}',
                child: Text(
                  '${wallet['name']} — ${_ownerName(wallet)} — ${money(wallet['balance'])}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) onSelected(value);
          },
        ),
      ),
      SizedBox(height: 18),
      HesbaModalField(
        label: tr(ar: 'المبلغ *', en: 'Amount *'),
        child: TextField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
  );
}

class _WalletsTable extends StatelessWidget {
  const _WalletsTable({
    required this.rows,
    required this.canManage,
    required this.showProfits,
    required this.onManage,
  });

  final List<dynamic> rows;
  final bool canManage;
  final bool showProfits;
  final Future<void> Function(Map<String, dynamic>) onManage;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: HesbaColors.border),
      borderRadius: BorderRadius.circular(14),
    ),
    clipBehavior: Clip.antiAlias,
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF2F5F8)),
            headingRowHeight: 52,
            horizontalMargin: 20,
            columnSpacing: 28,
            dataRowMinHeight: 60,
            dataRowMaxHeight: 68,
            columns: [
              DataColumn(label: Text('المحفظة', style: _headerStyle)),
              DataColumn(label: Text('باسم', style: _headerStyle)),
              DataColumn(
                label: Text(
                  tr(ar: 'النوع', en: 'Type'),
                  style: _headerStyle,
                ),
              ),
              DataColumn(
                label: Text(
                  tr(ar: 'الرصيد', en: 'Balance'),
                  style: _headerStyle,
                ),
              ),
              DataColumn(label: Text('شحن اليوم', style: _headerStyle)),
              DataColumn(label: Text('الشحن الشهري', style: _headerStyle)),
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
              for (final raw in rows)
                DataRow(
                  cells: [
                    DataCell(
                      Text('${raw['name']}', style: HesbaText.tableEmphasis),
                    ),
                    DataCell(Text(_ownerName(raw), style: HesbaText.tableCell)),
                    DataCell(
                      Text(
                        _walletType('${raw['type']}'),
                        style: HesbaText.tableCell,
                      ),
                    ),
                    DataCell(
                      Text(
                        money(raw['balance']),
                        style: HesbaText.tableEmphasis,
                      ),
                    ),
                    DataCell(
                      Text(
                        '${money(raw['dailyTopUp'])} / 60,000',
                        style: HesbaText.tableCell,
                      ),
                    ),
                    DataCell(
                      Text(
                        '${money(raw['monthlyTopUp'])} / 200,000',
                        style: HesbaText.tableCell,
                      ),
                    ),
                    if (showProfits)
                      DataCell(
                        Text(
                          money(raw['commissionBalance']),
                          style: HesbaText.tableEmphasis.copyWith(
                            color: HesbaColors.tealDark,
                          ),
                        ),
                      ),
                    DataCell(SoftBadge.status(active: raw['active'] == true)),
                    DataCell(
                      canManage
                          ? OutlinedButton(
                              onPressed: () => onManage(
                                Map<String, dynamic>.from(raw as Map),
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
      ),
    ),
  );
}

enum _WalletAction { activate, deactivate, delete }

class _WalletMovements extends StatelessWidget {
  const _WalletMovements({
    required this.entries,
    required this.showProfits,
    this.onOpenLedger,
  });

  final List<dynamic> entries;
  final bool showProfits;
  final VoidCallback? onOpenLedger;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: HesbaColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('سجل عمليات المحافظ', style: HesbaText.sectionTitle),
                      SizedBox(height: 2),
                      Text(
                        showProfits
                            ? tr(
                                ar: 'آخر الشحن والاستخدام والعمولات',
                                en: 'Latest top-ups, usage, and commissions',
                              )
                            : tr(
                                ar: 'آخر عمليات الشحن والاستخدام',
                                en: 'Latest top-ups and usage',
                              ),
                        style: HesbaText.panelSub,
                      ),
                    ],
                  ),
                ),
                if (onOpenLedger != null)
                  OutlinedButton(
                    onPressed: onOpenLedger,
                    child: Text(tr(ar: 'عرض الكل', en: 'View all')),
                  ),
              ],
            ),
          ),
          if (entries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(38),
              child: Text(
                'لا توجد حركات محافظ مسجلة بعد',
                textAlign: TextAlign.center,
                style: TextStyle(color: HesbaColors.muted),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      const Color(0xFFF2F5F8),
                    ),
                    headingRowHeight: 52,
                    dataRowMinHeight: 56,
                    dataRowMaxHeight: 60,
                    horizontalMargin: 20,
                    columnSpacing: 28,
                    columns: [
                      DataColumn(
                        label: Text(
                          tr(ar: 'التاريخ والوقت', en: 'Date & time'),
                          style: HesbaText.tableHeader,
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          tr(ar: 'النوع', en: 'Type'),
                          style: HesbaText.tableHeader,
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          tr(ar: 'الوصف', en: 'Description'),
                          style: HesbaText.tableHeader,
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          tr(ar: 'المبلغ', en: 'Amount'),
                          style: HesbaText.tableHeader,
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          tr(ar: 'المستخدم', en: 'User'),
                          style: HesbaText.tableHeader,
                        ),
                      ),
                    ],
                    rows: [
                      for (final entry in entries)
                        _row(entry as Map<String, dynamic>),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  DataRow _row(Map<String, dynamic> entry) {
    final category = '${entry['category']}';
    final outflow = category == 'wallet_usage';
    final amount = num.tryParse('${entry['amount']}') ?? 0;
    final color = outflow ? HesbaColors.red : HesbaColors.tealDark;
    final sign = outflow ? '−' : '+';

    return DataRow(
      cells: [
        DataCell(
          Text(formatDateTime(entry['createdAt']), style: HesbaText.tableCell),
        ),
        DataCell(
          Text(_categoryLabel(category), style: HesbaText.tableEmphasis),
        ),
        DataCell(
          Text('${entry['description'] ?? '—'}', style: HesbaText.tableCell),
        ),
        DataCell(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '$sign${money(amount.abs())}',
              style: HesbaText.tableEmphasis.copyWith(color: color),
            ),
          ),
        ),
        DataCell(
          Text('${entry['performedBy'] ?? '—'}', style: HesbaText.tableCell),
        ),
      ],
    );
  }

  String _categoryLabel(String category) => switch (category) {
    'top_up' => tr(ar: 'شحن محفظة', en: 'Wallet top-up'),
    'wallet_usage' => tr(ar: 'استخدام محفظة', en: 'Wallet usage'),
    'commission' => tr(ar: 'عمولة', en: 'Commission'),
    'opening_balance' => tr(ar: 'رصيد افتتاحي', en: 'Opening balance'),
    'reversal' => 'عكس عملية',
    'internal_transfer' => tr(ar: 'تحويل داخلي', en: 'Internal transfer'),
    _ => category,
  };
}

const _walletTypes = {
  'vodafone_cash': 'Vodafone Cash',
  'orange_cash': 'Orange Cash',
  'etisalat_cash': 'e& cash (اتصالات كاش)',
  'we_pay': 'WE Pay',
  'instapay': 'InstaPay',
  'other_wallet': 'محفظة أخرى',
};

String _walletType(String type) =>
    _walletTypes[type] ??
    (type == 'wallet' ? tr(ar: 'محفظة إلكترونية', en: 'E-wallet') : type);

String _ownerName(dynamic wallet) {
  final value = '${wallet['ownerName'] ?? ''}'.trim();
  return value.isEmpty ? 'غير مسجل' : value;
}

const _headerStyle = HesbaText.tableHeader;

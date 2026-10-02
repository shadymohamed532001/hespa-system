import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/digits.dart';
import '../../core/utils/datetime_formatter.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/widgets/error_box.dart';
import '../../core/widgets/hesba_modal.dart';
import '../../core/widgets/metric_card.dart';
import '../../core/widgets/page_frame.dart';
import '../../core/widgets/app_snack.dart';
import '../auth/session_controller.dart';
import '../../core/settings/tr.dart';

class TreasuryPage extends StatefulWidget {
  const TreasuryPage({
    super.key,
    required this.session,
    required this.onOpenTransfer,
  });

  final SessionController session;
  final VoidCallback onOpenTransfer;

  @override
  State<TreasuryPage> createState() => _TreasuryPageState();
}

class _TreasuryPageState extends State<TreasuryPage> {
  Map<String, dynamic> summary = {};
  List<dynamic> ledger = [];
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
      final values = await Future.wait([
        widget.session.api.getMap(ApiEndpoints.treasurySummary),
        widget.session.api.list(ApiEndpoints.ledgerList(limit: 200)),
      ]);
      summary = values[0] as Map<String, dynamic>;
      ledger = values[1] as List<dynamic>;
    } catch (exception) {
      error = ApiClient.errorMessage(exception);
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> _withdraw() async {
    final actual = parseNum('${summary['actualBalance']}') ?? 0;
    final pending = parseNum('${summary['pendingAmount']}') ?? 0;
    if (actual <= 0) {
      if (mounted) {
        showAppSnack(context, 'الخزنة فاضية، مفيش مبلغ يتسحب', error: true);
      }
      return;
    }

    final request = await showHesbaModal<_WithdrawRequest>(
      context: context,
      maxWidth: 520,
      builder: (context) => _WithdrawDialog(actual: actual, pending: pending),
    );
    if (request == null || !mounted) return;

    try {
      final response = await widget.session.api
          .post(ApiEndpoints.treasuryWithdraw, {
            'mode': request.mode,
            if (request.mode == 'leave') 'leaveAmount': request.leaveAmount,
            if (request.note.isNotEmpty) 'note': request.note,
          });
      await load();
      if (!mounted) return;
      final body = response as Map<String, dynamic>;
      showAppSnack(
        context,
        'تم سحب ${money(body['withdrawnAmount'])}، والمتبقي في الخزنة ${money(body['remainingBalance'])}',
      );
    } catch (exception) {
      if (mounted) {
        showAppSnack(context, ApiClient.errorMessage(exception), error: true);
      }
    }
  }

  Future<void> _reconcile() async {
    final balance = TextEditingController(
      text: '${summary['actualBalance'] ?? ''}',
    );
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسوية الخزنة'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: balance,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: const [MoneyInputFormatter()],
                decoration: const InputDecoration(labelText: 'الرصيد المعدود'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: note,
                maxLength: 300,
                decoration: const InputDecoration(labelText: 'ملاحظة الجرد'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(ar: 'إلغاء', en: 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حفظ التسوية'),
          ),
        ],
      ),
    );
    final counted = parseNum(balance.text.trim());
    final noteValue = note.text.trim();
    balance.dispose();
    note.dispose();
    if (confirmed != true || counted == null || counted < 0 || !mounted) return;
    try {
      await widget.session.api.post(ApiEndpoints.treasuryReconcile, {
        'assetType': 'treasury',
        'countedBalance': counted,
        if (noteValue.isNotEmpty) 'note': noteValue,
      });
      await load();
      if (mounted) showAppSnack(context, 'تم تسجيل التسوية في سجل العمليات');
    } catch (exception) {
      if (mounted) {
        showAppSnack(context, ApiClient.errorMessage(exception), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'الخزنة المركزية',
      subtitle: 'الرصيد الفعلي والمتاح والالتزامات',
      actions: [
        if (widget.session.can(AppPermissions.withdrawTreasury))
          OutlinedButton(
            onPressed: loading ? null : _withdraw,
            child: const Text('سحب من الخزنة'),
          ),
        if (widget.session.can(AppPermissions.reconcileBalances))
          OutlinedButton(
            onPressed: loading ? null : _reconcile,
            child: const Text('تسوية الخزنة'),
          ),
        if (widget.session.can(AppPermissions.internalTransfer))
          FilledButton(
            onPressed: widget.onOpenTransfer,
            child: Text(tr(ar: 'تحويل داخلي', en: 'Internal transfer')),
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
                _SummaryGrid(
                  summary: summary,
                  todayMovements: _todayLedger.length,
                ),
                const SizedBox(height: 20),
                const _AccountingRule(),
                const SizedBox(height: 20),
                _TreasuryMovements(entries: ledger.take(8).toList()),
              ],
            ),
    );
  }

  List<dynamic> get _todayLedger {
    final now = DateTime.now();
    return ledger.where((entry) {
      final value = DateTime.tryParse('${entry['createdAt']}')?.toLocal();
      return value != null &&
          value.year == now.year &&
          value.month == now.month &&
          value.day == now.day;
    }).toList();
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary, required this.todayMovements});

  final Map<String, dynamic> summary;
  final int todayMovements;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth < 700
            ? 1
            : constraints.maxWidth < 1050
            ? 2
            : 4;
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            mainAxisSpacing: 15,
            crossAxisSpacing: 15,
            mainAxisExtent: 150,
          ),
          children: [
            MetricCard(
              label: 'الرصيد الفعلي',
              value: money(summary['actualBalance']),
              note: 'النقد الموجود في الخزنة',
            ),
            MetricCard(
              label: 'التزامات معلّقة',
              value: money(summary['pendingAmount']),
              note: tr(
                ar: 'أموال ليست حرة للتصرف',
                en: 'Funds that are not freely disposable',
              ),
              warning: true,
            ),
            MetricCard(
              label: 'الرصيد المتاح',
              value: money(summary['availableBalance']),
              note: 'الفعلي ناقص المعلّقات',
              accent: true,
            ),
            MetricCard(
              label: 'عدد حركات اليوم',
              value: '$todayMovements',
              note: 'تشمل التحويلات الداخلية',
            ),
          ],
        );
      },
    );
  }
}

class _AccountingRule extends StatelessWidget {
  const _AccountingRule();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF4F7),
        borderRadius: BorderRadius.circular(11),
      ),
      child: const Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'قاعدة محاسبية: ',
              style: TextStyle(fontWeight: FontWeight.w400),
            ),
            TextSpan(
              text:
                  'نقل مبلغ من الخزنة إلى حساب فوري أو محفظة أو ماكينة هو تحويل بين أصول المحل، وليس مصروفًا أو خسارة.',
            ),
          ],
        ),
        style: TextStyle(color: Color(0xFF425C6B), fontSize: 13, height: 1.55),
      ),
    );
  }
}

class _TreasuryMovements extends StatelessWidget {
  const _TreasuryMovements({required this.entries});

  final List<dynamic> entries;

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
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('حركات الخزنة', style: HesbaText.sectionTitle),
                SizedBox(height: 2),
                Text('مع توضيح نوع وأثر كل حركة', style: HesbaText.panelSub),
              ],
            ),
          ),
          if (entries.isEmpty)
            Padding(
              padding: EdgeInsets.all(38),
              child: Text(
                tr(
                  ar: 'لا توجد حركات مسجلة بعد',
                  en: 'No movements recorded yet',
                ),
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
                    headingRowHeight: 54,
                    dataRowMinHeight: 58,
                    dataRowMaxHeight: 62,
                    horizontalMargin: 20,
                    columnSpacing: 30,
                    columns: [
                      DataColumn(
                        label: Text(
                          tr(ar: 'التاريخ والوقت', en: 'Date & time'),
                        ),
                      ),
                      DataColumn(
                        label: Text(tr(ar: 'الحركة', en: 'Entry')),
                      ),
                      DataColumn(
                        label: Text(tr(ar: 'البيان', en: 'Description')),
                      ),
                      DataColumn(
                        label: Text(tr(ar: 'المبلغ', en: 'Amount')),
                      ),
                      DataColumn(
                        label: Text(tr(ar: 'التصنيف', en: 'Category')),
                      ),
                      DataColumn(
                        label: Text(tr(ar: 'الأثر', en: 'Impact')),
                      ),
                    ],
                    rows: entries
                        .map((entry) => _row(entry as Map<String, dynamic>))
                        .toList(),
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
    final rawAmount = num.tryParse('${entry['amount']}') ?? 0;
    final negative = rawAmount < 0 || _isOutflow(entry);
    final sign = rawAmount == 0
        ? ''
        : negative
        ? '−'
        : '+';
    final color = rawAmount == 0
        ? HesbaColors.muted
        : negative
        ? HesbaColors.red
        : HesbaColors.tealDark;

    return DataRow(
      cells: [
        DataCell(Text(formatDateTime(entry['createdAt']))),
        DataCell(
          Text(
            _categoryName(category),
            style: const TextStyle(
              color: HesbaColors.ink,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        DataCell(Text(entry['reference'] ?? entry['description'] ?? '—')),
        DataCell(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '$sign${money(rawAmount.abs())}',
              style: TextStyle(color: color, fontWeight: FontWeight.w400),
            ),
          ),
        ),
        DataCell(_MovementBadge(entry: entry)),
        DataCell(Text(_effect(entry))),
      ],
    );
  }

  bool _isOutflow(Map<String, dynamic> entry) {
    final category = '${entry['category']}';
    if (category == 'internal_transfer') {
      return entry['sourceType'] == 'treasury' ||
          '${entry['description']}'.contains('من الخزنة المركزية');
    }
    return category == 'company_execution' ||
        category == 'machine_usage' ||
        category == 'top_up' ||
        category == 'owner_withdrawal';
  }

  String _categoryName(String category) => switch (category) {
    'cash_receipt' => tr(
      ar: 'استلام كاش من مندوب',
      en: 'Receive cash from agent',
    ),
    'internal_transfer' => tr(ar: 'تحويل داخلي', en: 'Internal transfer'),
    'top_up' => 'شحن رصيد',
    'machine_usage' => tr(
      ar: 'استخدام رصيد ماكينة',
      en: 'Machine balance usage',
    ),
    'company_execution' => tr(
      ar: 'توريد وتسوية شركة',
      en: 'Company settlement',
    ),
    'commission' => tr(ar: 'عمولة', en: 'Commission'),
    'wallet_cash_fee' => tr(ar: 'عمولة نقدية لمحفظة', en: 'Wallet cash fee'),
    'daily_rollover' => tr(ar: 'ترحيل يومي', en: 'Daily rollover'),
    'opening_balance' => tr(ar: 'رصيد افتتاحي', en: 'Opening balance'),
    'reversal' => 'عكس حركة',
    'owner_withdrawal' => tr(ar: 'سحب من الخزنة', en: 'Treasury withdrawal'),
    'purchase_visa_usage' => tr(
      ar: 'سحب فيزا مشتريات',
      en: 'Purchase visa withdrawal',
    ),
    'reconciliation' => tr(ar: 'تسوية رصيد', en: 'Balance reconciliation'),
    _ => category,
  };

  String _effect(Map<String, dynamic> entry) {
    final category = '${entry['category']}';
    return switch (category) {
      'cash_receipt' =>
        '${entry['reference']}'.startsWith('HLD-')
            ? 'دخل الخزنة مع التزام معلّق'
            : 'دخل الكاش الخزنة',
      'internal_transfer' => tr(
        ar: 'حركة بين الأصول',
        en: 'Movement between assets',
      ),
      'top_up' => 'زيادة رصيد أصل تشغيلي',
      'machine_usage' => tr(
        ar: 'خفض رصيد الماكينة',
        en: 'Reduce machine balance',
      ),
      'company_execution' => tr(
        ar: 'خفض رصيد حساب الشركة',
        en: 'Reduce company account balance',
      ),
      'commission' => tr(
        ar: 'إضافة عمولة مستقلة',
        en: 'Add independent commission',
      ),
      'wallet_cash_fee' => tr(
        ar: 'إضافة العمولة للخزنة',
        en: 'Add fee to treasury',
      ),
      'daily_rollover' => tr(
        ar: 'ترحيل أرصدة اليوم',
        en: 'Roll over today balances',
      ),
      'opening_balance' => tr(
        ar: 'إثبات رصيد افتتاحي',
        en: 'Record opening balance',
      ),
      'reversal' => 'عكس أثر حركة سابقة',
      'owner_withdrawal' => tr(
        ar: 'خرج النقد من الخزنة',
        en: 'Cash left the treasury',
      ),
      'purchase_visa_usage' => tr(
        ar: 'دخل الكاش الخزنة والمكسب',
        en: 'Cash and profit entered the treasury',
      ),
      'reconciliation' => tr(
        ar: 'مطابقة الرصيد المعدود',
        en: 'Match the counted balance',
      ),
      _ => '${entry['description'] ?? '—'}',
    };
  }
}

class _MovementBadge extends StatelessWidget {
  const _MovementBadge({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final category = '${entry['category']}';
    final hold =
        category == 'cash_receipt' &&
        '${entry['reference']}'.startsWith('HLD-');
    final internal = category == 'internal_transfer';
    final withdrawal = category == 'owner_withdrawal';
    final background = withdrawal
        ? HesbaColors.redLight
        : hold
        ? HesbaColors.warningLight
        : internal
        ? const Color(0xFFE9EEF6)
        : HesbaColors.tealLight;
    final foreground = withdrawal
        ? HesbaColors.red
        : hold
        ? HesbaColors.warning
        : internal
        ? const Color(0xFF50657D)
        : HesbaColors.tealSoft;
    final label = withdrawal
        ? tr(ar: 'سحب نقدي', en: 'Cash withdrawal')
        : hold
        ? tr(ar: 'معلّق', en: 'Pending')
        : internal
        ? tr(ar: 'تحويل داخلي', en: 'Internal transfer')
        : tr(ar: 'تشغيل', en: 'Operations');

    return Container(
      constraints: const BoxConstraints(minWidth: 76),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _WithdrawRequest {
  const _WithdrawRequest({
    required this.mode,
    required this.leaveAmount,
    required this.note,
  });

  final String mode;
  final num leaveAmount;
  final String note;
}

class _WithdrawDialog extends StatefulWidget {
  const _WithdrawDialog({required this.actual, required this.pending});

  final num actual;
  final num pending;

  @override
  State<_WithdrawDialog> createState() => _WithdrawDialogState();
}

class _WithdrawDialogState extends State<_WithdrawDialog> {
  final leave = TextEditingController();
  final note = TextEditingController();
  String mode = 'leave';

  @override
  void dispose() {
    leave.dispose();
    note.dispose();
    super.dispose();
  }

  num? get _leaveAmount => mode == 'all' ? 0 : parseNum(leave.text.trim());

  num? get _withdrawn {
    final remaining = _leaveAmount;
    if (remaining == null || remaining < 0 || remaining > widget.actual) {
      return null;
    }
    final value = widget.actual - remaining;
    if (value <= 0) return null;
    return value;
  }

  String? get _problem {
    if (mode == 'all') return null;
    final text = leave.text.trim();
    if (text.isEmpty) return 'اكتب المبلغ اللي هيفضل في الخزنة';
    final remaining = parseNum(text);
    if (remaining == null || remaining < 0) return 'المبلغ المتبقي غير صالح';
    if (remaining > widget.actual) return 'المبلغ المتبقي أكبر من رصيد الخزنة';
    if (remaining == widget.actual) return 'المبلغ ده يسيب الخزنة زي ما هي';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _leaveAmount;
    final withdrawn = _withdrawn;
    final belowPending =
        remaining != null && widget.pending > 0 && remaining < widget.pending;

    return HesbaModalCard(
      title: 'سحب من الخزنة',
      subtitle:
          'الرصيد الفعلي ${money(widget.actual)}. السحب بيخرج الفلوس من المحل وينقص الخزنة، ومش تحويل داخلي.',
      actions: HesbaModalActions(
        primaryLabel: 'تأكيد السحب',
        primaryEnabled: withdrawn != null,
        onPrimary: () => Navigator.pop(
          context,
          _WithdrawRequest(
            mode: mode,
            leaveAmount: remaining ?? 0,
            note: note.text.trim(),
          ),
        ),
        onCancel: () => Navigator.pop(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ModeCard(
            title: 'سحب الخزنة كلها',
            subtitle: 'الخزنة هتبقى صفر',
            selected: mode == 'all',
            onTap: () => setState(() => mode = 'all'),
          ),
          const SizedBox(height: 10),
          _ModeCard(
            title: 'سيب مبلغ في الخزنة',
            subtitle: 'مثلاً سيب ٣٠٬٠٠٠ وخد الباقي',
            selected: mode == 'leave',
            onTap: () => setState(() => mode = 'leave'),
          ),
          if (mode == 'leave') ...[
            const SizedBox(height: 18),
            HesbaModalField(
              label: 'المبلغ اللي هيفضل في الخزنة',
              child: TextField(
                controller: leave,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: const [MoneyInputFormatter()],
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
          const SizedBox(height: 18),
          HesbaModalField(
            label: 'ملاحظة',
            child: TextField(controller: note, maxLength: 300),
          ),
          const SizedBox(height: 8),
          HesbaModalCallout(
            backgroundColor: belowPending
                ? HesbaColors.warningLight
                : const Color(0xFFEEF4F7),
            borderColor: belowPending
                ? HesbaColors.warning
                : HesbaColors.border,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  withdrawn == null
                      ? 'هيتسحب: —'
                      : 'هيتسحب: ${money(withdrawn)}',
                ),
                const SizedBox(height: 4),
                Text(
                  remaining == null
                      ? 'هيفضل في الخزنة: —'
                      : 'هيفضل في الخزنة: ${money(remaining)}',
                ),
                if (_problem != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _problem!,
                    style: const TextStyle(
                      color: HesbaColors.red,
                      fontSize: 13,
                    ),
                  ),
                ] else if (belowPending) ...[
                  const SizedBox(height: 8),
                  Text(
                    'الالتزامات المعلقة ${money(widget.pending)}، والمتبقي أقل منها. السحب هيتم والالتزامات هتفضل مسجلة.',
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

class _ModeCard extends StatelessWidget {
  const _ModeCard({
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

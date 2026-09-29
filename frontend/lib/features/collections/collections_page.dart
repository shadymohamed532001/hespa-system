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
import '../../core/widgets/page_frame.dart';
import '../../core/widgets/soft_badge.dart';
import '../auth/session_controller.dart';
import 'profit_collection_commission.dart';
import 'receive_collection_dialog.dart';
import '../../core/settings/tr.dart';

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key, required this.session});
  final SessionController session;
  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  List<dynamic> data = [], accounts = [], visas = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final values = await Future.wait([
        widget.session.api.list(ApiEndpoints.collections),
        widget.session.api.list(ApiEndpoints.accounts),
        widget.session.api
            .list(ApiEndpoints.purchaseVisas)
            .catchError((_) => <dynamic>[]),
      ]);
      data = values[0];
      accounts = values[1];
      visas = values[2];
      error = null;
    } catch (e) {
      error = ApiClient.errorMessage(e);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'التحصيل والمعلّقات',
      subtitle: 'استلام المندوب يمكن تنفيذه فورًا أو حفظه كمعلّق',
      actions: [
        FilledButton(
          onPressed: _receive,
          child: Text(tr(ar: 'استلام من مندوب', en: 'Receive from agent')),
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
          : _CollectionsTable(
              rows: data,
              onExecute: (row) => _execute(row),
              showProfits: widget.session.isAdmin,
            ),
    );
  }

  Future<void> _receive() async {
    final saved = await showReceiveCollectionDialog(
      context: context,
      session: widget.session,
    );
    if (saved) {
      await load();
      if (mounted) {
        showAppSnack(
          context,
          tr(ar: 'تم تسجيل التحصيل', en: 'Collection recorded'),
        );
      }
    }
  }

  Future<void> _execute(Map<String, dynamic> collection) async {
    if (accounts.isEmpty && visas.isEmpty) return;
    var accountId = accounts.isNotEmpty
        ? 'account:${accounts.first['id']}'
        : 'visa:${visas.first['id']}';
    var withService = false;
    final commission = TextEditingController(text: '0');
    final amount = num.tryParse('${collection['amount']}') ?? 0;
    String? sourceId(String key) =>
        key.contains(':') ? key.substring(key.indexOf(':') + 1) : key;
    bool isVisa(String key) => key.startsWith('visa:');
    String? accountType(String key) {
      if (isVisa(key)) return 'purchase_visa';
      for (final account in accounts) {
        if ('${account['id']}' == sourceId(key)) return '${account['type']}';
      }
      return null;
    }

    bool isFawry(String id) => accountType(id) == 'fawry';
    bool isProfit(String id) => accountType(id) == 'profit';
    bool isProfitQr(String id) => accountType(id) == 'profit_qr';
    void syncCommission() {
      if (isProfit(accountId)) {
        commission.text = formatProfitCollectionCommission(amount);
      } else if (isProfitQr(accountId)) {
        commission.text = '0';
      }
    }

    syncCommission();

    final ok = await showHesbaModal<bool>(
      context: context,
      maxWidth: 520,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final fawry = isFawry(accountId);
          final profit = isProfit(accountId);
          final profitQr = isProfitQr(accountId);
          final visa = isVisa(accountId);
          return HesbaModalCard(
            title: 'تنفيذ المعلّق ${collection['reference']}',
            subtitle:
                '${collection['companyName']} · ${collection['agentName']} · ${money(collection['amount'])}',
            actions: HesbaModalActions(
              primaryLabel: 'تأكيد التنفيذ',
              onPrimary: () => Navigator.pop(ctx, true),
              onCancel: () => Navigator.pop(ctx, false),
            ),
            child: Column(
              children: [
                HesbaModalField(
                  label: 'الحساب المستخدم *',
                  child: DropdownButtonFormField<String>(
                    initialValue: accountId,
                    isExpanded: true,
                    decoration: const InputDecoration(),
                    items: [
                      for (final e in accounts)
                        DropdownMenuItem(
                          value: 'account:${e['id']}',
                          child: Text('${e['name']} — ${money(e['balance'])}'),
                        ),
                      for (final e in visas)
                        DropdownMenuItem(
                          value: 'visa:${e['id']}',
                          child: Text(
                            'فيزا مشتريات — ${e['name']} — ${money(e['balance'])}',
                          ),
                        ),
                    ],
                    onChanged: (v) => setLocal(() {
                      accountId = v!;
                      syncCommission();
                    }),
                  ),
                ),
                const SizedBox(height: 18),
                if (visa) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('من غير خدمة · ٢٠'),
                          selected: !withService,
                          onSelected: (_) =>
                              setLocal(() => withService = false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('بخدمة · ١٣'),
                          selected: withService,
                          onSelected: (_) => setLocal(() => withService = true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  HesbaModalCallout(
                    child: Text(
                      'المكسب ${money(purchaseVisaCollectionProfit(amount, withService))} بيدخل الخزنة، والفيزا بتنقص بالمبلغ.',
                    ),
                  ),
                ] else if (profitQr)
                  HesbaModalCallout(
                    child: Text(
                      'خصم مكسب عند التوريد ${money(profitCollectionCommission(amount))} — ٤ جنيه لكل ألف، ويُخصم فوق مبلغ العملية.',
                    ),
                  )
                else if (!fawry)
                  HesbaModalField(
                    label: tr(ar: 'العمولة', en: 'Commission'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: commission,
                          readOnly: profit,
                          keyboardType: TextInputType.number,
                          inputFormatters: const [ArabicDigitsFormatter()],
                          decoration: const InputDecoration(),
                        ),
                        if (profit)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              '٤ جنيه لكل ألف من المبلغ',
                              style: HesbaText.caption,
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  const HesbaModalCallout(
                    child: Text(
                      'حساب فوري: العمولة مش بتتسجل مع التنفيذ. الأدمن بيكتب النزلة في اليوم التالي.',
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
    if (ok == true) {
      try {
        await widget.session.api.post(
          ApiEndpoints.executeCollection('${collection['id']}'),
          {
            if (isVisa(accountId))
              'purchaseVisaId': sourceId(accountId)
            else
              'accountId': sourceId(accountId),
            if (isVisa(accountId)) 'withService': withService,
            'commission':
                isFawry(accountId) || isProfitQr(accountId) || isVisa(accountId)
                ? 0
                : parseNum(commission.text) ?? 0,
          },
        );
        await load();
        if (mounted) showAppSnack(context, 'تم تنفيذ المعلّق');
      } catch (e) {
        if (mounted) {
          showAppSnack(context, ApiClient.errorMessage(e), error: true);
        }
      }
    }
  }
}

String _executionName(dynamic row) {
  final account = row['account'];
  if (account is Map && '${account['name']}'.trim().isNotEmpty) {
    return '${account['name']}';
  }
  final visa = row['purchaseVisa'];
  if (visa is Map && '${visa['name']}'.trim().isNotEmpty) {
    final service = row['withService'] == true ? 'بخدمة' : 'من غير خدمة';
    return 'فيزا مشتريات — ${visa['name']} · $service';
  }
  return '—';
}

class _CollectionsTable extends StatelessWidget {
  const _CollectionsTable({
    required this.rows,
    required this.onExecute,
    required this.showProfits,
  });

  final List<dynamic> rows;
  final Future<void> Function(Map<String, dynamic> row) onExecute;
  final bool showProfits;

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
                horizontalMargin: 16,
                columnSpacing: 22,
                dataRowMinHeight: 58,
                dataRowMaxHeight: 84,
                columns: [
                  DataColumn(
                    label: Text('الرقم', style: HesbaText.tableHeader),
                  ),
                  DataColumn(
                    label: Text('المندوب', style: HesbaText.tableHeader),
                  ),
                  DataColumn(
                    label: Text('الشركة', style: HesbaText.tableHeader),
                  ),
                  DataColumn(
                    label: Text(
                      tr(ar: 'المبلغ', en: 'Amount'),
                      style: HesbaText.tableHeader,
                    ),
                  ),
                  DataColumn(
                    label: Text('الآجل', style: HesbaText.tableHeader),
                  ),
                  DataColumn(
                    label: Text('تاريخ الاستلام', style: HesbaText.tableHeader),
                  ),
                  DataColumn(
                    label: Text('طريقة التنفيذ', style: HesbaText.tableHeader),
                  ),
                  DataColumn(
                    label: Text(
                      tr(ar: 'الحالة', en: 'Status'),
                      style: HesbaText.tableHeader,
                    ),
                  ),
                  DataColumn(
                    label: Text('تاريخ التنفيذ', style: HesbaText.tableHeader),
                  ),
                  DataColumn(
                    label: Text(
                      'الحساب المستخدم',
                      style: HesbaText.tableHeader,
                    ),
                  ),
                  if (showProfits)
                    DataColumn(
                      label: Text(
                        tr(ar: 'العمولة', en: 'Commission'),
                        style: HesbaText.tableHeader,
                      ),
                    ),
                  DataColumn(label: Text('', style: HesbaText.tableHeader)),
                ],
                rows: [
                  for (final e in rows)
                    DataRow(
                      cells: [
                        DataCell(
                          Text('${e['reference']}', style: HesbaText.tableCell),
                        ),
                        DataCell(
                          Text('${e['agentName']}', style: HesbaText.tableCell),
                        ),
                        DataCell(
                          Text(
                            '${e['companyName']}',
                            style: HesbaText.tableCell,
                          ),
                        ),
                        DataCell(
                          _CollectionAmount(row: e as Map<String, dynamic>),
                        ),
                        DataCell(
                          _AgentCreditChange(
                            value:
                                num.tryParse('${e['agentCreditChange']}') ?? 0,
                          ),
                        ),
                        DataCell(
                          Text(
                            formatDateTime(e['receivedAt'] ?? e['createdAt']),
                            style: HesbaText.tableCell,
                          ),
                        ),
                        DataCell(
                          e['executionMode'] == 'hold'
                              ? const SoftBadge.hold()
                              : const SoftBadge.immediate(),
                        ),
                        DataCell(
                          e['status'] == 'pending'
                              ? const SoftBadge.pending()
                              : e['status'] == 'reversed'
                              ? Text(
                                  tr(ar: 'معكوسة', en: 'Reversed'),
                                  style: TextStyle(color: Colors.red),
                                )
                              : const SoftBadge.done(),
                        ),
                        DataCell(
                          Text(
                            e['executedAt'] == null
                                ? '—'
                                : formatDateTime(e['executedAt']),
                            style: HesbaText.tableCell,
                          ),
                        ),
                        DataCell(
                          Text(_executionName(e), style: HesbaText.tableCell),
                        ),
                        if (showProfits)
                          DataCell(
                            Text(
                              money(e['commission'] ?? 0),
                              style: HesbaText.tableCell.copyWith(
                                color: HesbaColors.teal,
                              ),
                            ),
                          ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (e['status'] == 'pending')
                                FilledButton(
                                  onPressed: () => onExecute(e),
                                  child: const Text('تنفيذ'),
                                )
                              else
                                Text('—', style: HesbaText.tableCell),
                            ],
                          ),
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

class _AgentCreditChange extends StatelessWidget {
  const _AgentCreditChange({required this.value});

  final num value;

  @override
  Widget build(BuildContext context) {
    if (value == 0) return Text('—', style: HesbaText.tableCell);
    final opened = value > 0;
    return Text(
      opened ? 'عليه ${money(value)}' : 'سدّد ${money(-value)}',
      style: HesbaText.tableCell.copyWith(
        color: opened ? HesbaColors.warning : HesbaColors.teal,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _CollectionAmount extends StatelessWidget {
  const _CollectionAmount({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final breakdown = _incomingBreakdown(row);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(money(row['amount']), style: HesbaText.tableCell),
        if (breakdown != null)
          Text(
            breakdown,
            style: HesbaText.tableCell.copyWith(
              fontSize: 11,
              color: HesbaColors.muted,
            ),
          ),
      ],
    );
  }
}

String? _incomingBreakdown(Map<String, dynamic> row) {
  final splits = row['incomingSplits'];
  final creditChange = num.tryParse('${row['agentCreditChange']}') ?? 0;
  final hasSplits = splits is List && splits.isNotEmpty;
  if (!hasSplits && creditChange == 0) return null;
  final cash = money(row['cashAmount'] ?? 0);
  if (!hasSplits) return 'المستلم فعليًا $cash';
  final wallets = splits
      .map((part) => '${part['walletName']} ${money(part['amount'])}')
      .join(' · ');
  return 'خزنة $cash · $wallets';
}

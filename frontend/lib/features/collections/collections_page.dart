import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/datetime_formatter.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/error_box.dart';
import '../../core/widgets/page_frame.dart';
import '../../core/widgets/soft_badge.dart';
import '../auth/session_controller.dart';
import 'execute_hold_dialog.dart';
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
      onRefresh: load,
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
    final ok = await showExecuteHoldDialog(
      context: context,
      session: widget.session,
      collection: collection,
      accounts: accounts,
      visas: visas,
    );
    if (ok) {
      await load();
      if (mounted) showAppSnack(context, 'تم تنفيذ المعلّق');
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

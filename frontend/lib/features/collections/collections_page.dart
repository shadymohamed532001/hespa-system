import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

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
import 'receive_collection_dialog.dart';

class CollectionsPage extends StatefulWidget {
  const CollectionsPage({super.key, required this.session});
  final SessionController session;
  @override
  State<CollectionsPage> createState() => _CollectionsPageState();
}

class _CollectionsPageState extends State<CollectionsPage> {
  List<dynamic> data = [], accounts = [];
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
      ]);
      data = values[0];
      accounts = values[1];
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
        FilledButton(onPressed: _receive, child: const Text('استلام من مندوب')),
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
              canReverse: widget.session.can(AppPermissions.reverseOperations),
              onReverse: _reverse,
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
      if (mounted) showAppSnack(context, 'تم تسجيل التحصيل');
    }
  }

  Future<void> _execute(Map<String, dynamic> collection) async {
    if (accounts.isEmpty) return;
    var accountId = '${accounts.first['id']}';
    final commission = TextEditingController(text: '0');
    final ok = await showHesbaModal<bool>(
      context: context,
      maxWidth: 520,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => HesbaModalCard(
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
                        value: '${e['id']}',
                        child: Text('${e['name']} — ${money(e['balance'])}'),
                      ),
                  ],
                  onChanged: (v) => setLocal(() => accountId = v!),
                ),
              ),
              const SizedBox(height: 18),
              HesbaModalField(
                label: 'العمولة',
                child: TextField(
                  controller: commission,
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
      try {
        await widget.session.api.post(
          ApiEndpoints.executeCollection('${collection['id']}'),
          {
            'accountId': accountId,
            'commission': num.tryParse(commission.text) ?? 0,
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

  Future<void> _reverse(Map<String, dynamic> collection) async {
    final reason = TextEditingController();
    final ok = await showHesbaModal<bool>(
      context: context,
      maxWidth: 480,
      builder: (ctx) => HesbaModalCard(
        title: 'عكس التحصيل ${collection['reference']}',
        subtitle: 'سيتم عكس أثر الخزنة والحساب والعمولة كوحدة واحدة.',
        actions: HesbaModalActions(
          primaryLabel: 'تأكيد العكس',
          onPrimary: () => Navigator.pop(ctx, true),
          onCancel: () => Navigator.pop(ctx, false),
        ),
        child: HesbaModalField(
          label: 'سبب العكس *',
          child: TextField(
            controller: reason,
            minLines: 2,
            maxLines: 4,
            maxLength: 300,
            decoration: const InputDecoration(),
          ),
        ),
      ),
    );
    final value = reason.text.trim();
    if (ok != true || value.length < 3) return;
    try {
      await widget.session.api.post(
        ApiEndpoints.reverseCollection('${collection['id']}'),
        {'reason': value},
      );
      await load();
      if (mounted) showAppSnack(context, 'تم عكس التحصيل وتسجيل السبب');
    } catch (e) {
      if (mounted) {
        showAppSnack(context, ApiClient.errorMessage(e), error: true);
      }
    }
  }
}

class _CollectionsTable extends StatelessWidget {
  const _CollectionsTable({
    required this.rows,
    required this.onExecute,
    required this.canReverse,
    required this.onReverse,
  });

  final List<dynamic> rows;
  final Future<void> Function(Map<String, dynamic> row) onExecute;
  final bool canReverse;
  final Future<void> Function(Map<String, dynamic> row) onReverse;

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
                dataRowMaxHeight: 64,
                columns: const [
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
                    label: Text('المبلغ', style: HesbaText.tableHeader),
                  ),
                  DataColumn(
                    label: Text('وقت الاستلام', style: HesbaText.tableHeader),
                  ),
                  DataColumn(
                    label: Text('طريقة التنفيذ', style: HesbaText.tableHeader),
                  ),
                  DataColumn(
                    label: Text('الحالة', style: HesbaText.tableHeader),
                  ),
                  DataColumn(
                    label: Text('وقت التنفيذ', style: HesbaText.tableHeader),
                  ),
                  DataColumn(
                    label: Text(
                      'الحساب المستخدم',
                      style: HesbaText.tableHeader,
                    ),
                  ),
                  DataColumn(
                    label: Text('العمولة', style: HesbaText.tableHeader),
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
                          Text(money(e['amount']), style: HesbaText.tableCell),
                        ),
                        DataCell(
                          Text(
                            _formatTime(e['receivedAt'] ?? e['createdAt']),
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
                              ? const Text(
                                  'معكوسة',
                                  style: TextStyle(color: Colors.red),
                                )
                              : const SoftBadge.done(),
                        ),
                        DataCell(
                          Text(
                            e['executedAt'] == null
                                ? '—'
                                : _formatTime(e['executedAt']),
                            style: HesbaText.tableCell,
                          ),
                        ),
                        DataCell(
                          Text(
                            e['account']?['name']?.toString() ?? '—',
                            style: HesbaText.tableCell,
                          ),
                        ),
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
                                  onPressed: () =>
                                      onExecute(e as Map<String, dynamic>),
                                  child: const Text('تنفيذ'),
                                ),
                              if (canReverse && e['status'] != 'reversed') ...[
                                const SizedBox(width: 6),
                                TextButton(
                                  onPressed: () =>
                                      onReverse(e as Map<String, dynamic>),
                                  child: const Text('عكس'),
                                ),
                              ],
                              if (e['status'] != 'pending' &&
                                  (!canReverse || e['status'] == 'reversed'))
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

  static String _formatTime(dynamic value) {
    final parsed = DateTime.tryParse('$value')?.toLocal();
    if (parsed == null) return '—';
    return DateFormat('HH:mm').format(parsed);
  }
}

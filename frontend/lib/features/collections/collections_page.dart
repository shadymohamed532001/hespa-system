import '../ledger/operation_correction_dialog.dart';
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
  String _period = 'day';
  String _status = 'all';
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());

  DateTime get _periodStart {
    if (_period != 'week') return _selectedDate;
    // Weeks run from Saturday through Friday.
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day - (_selectedDate.weekday + 1) % 7,
    );
  }

  DateTime get _periodEnd => DateTime(
    _periodStart.year,
    _periodStart.month,
    _periodStart.day + (_period == 'week' ? 7 : 1),
  );

  List<dynamic> get _periodRows {
    if (_period == 'all') return data;
    final start = _periodStart;
    final end = _periodEnd;
    return data.where((row) {
      final date = DateTime.tryParse(
        '${row['receivedAt'] ?? row['createdAt']}',
      )?.toLocal();
      return date != null && !date.isBefore(start) && date.isBefore(end);
    }).toList();
  }

  List<dynamic> get _filteredRows {
    if (_status == 'all') return _periodRows;
    return _periodRows.where((row) => '${row['status']}' == _status).toList();
  }

  int _statusCount(String status) =>
      _periodRows.where((row) => '${row['status']}' == status).length;

  void _movePeriod(int direction) {
    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day + direction * (_period == 'week' ? 7 : 1),
      );
    });
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100, 12, 31),
    );
    if (date != null && mounted) setState(() => _selectedDate = date);
  }

  Widget _dateFilters() {
    final label = _period == 'week'
        ? '${formatDate(_periodStart)} — ${formatDate(DateTime(_periodEnd.year, _periodEnd.month, _periodEnd.day - 1))}'
        : formatDate(_selectedDate);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(tr(ar: 'حسب تاريخ الاستلام:', en: 'By receipt date:')),
        for (final option in [
          ('all', tr(ar: 'الكل', en: 'All')),
          ('day', tr(ar: 'يوم', en: 'Day')),
          ('week', tr(ar: 'أسبوع', en: 'Week')),
        ])
          ChoiceChip(
            label: Text(option.$2),
            selected: _period == option.$1,
            onSelected: (_) => setState(() => _period = option.$1),
          ),
        if (_period != 'all') ...[
          IconButton(
            tooltip: tr(ar: 'السابق', en: 'Previous'),
            onPressed: () => _movePeriod(-1),
            icon: const BackButtonIcon(),
          ),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(label),
          ),
          IconButton(
            tooltip: tr(ar: 'التالي', en: 'Next'),
            onPressed: () => _movePeriod(1),
            icon: Transform.flip(flipX: true, child: const BackButtonIcon()),
          ),
          TextButton(
            onPressed: () => setState(() {
              _selectedDate = DateUtils.dateOnly(DateTime.now());
            }),
            child: Text(
              _period == 'week'
                  ? tr(ar: 'الأسبوع الحالي', en: 'This week')
                  : tr(ar: 'اليوم', en: 'Today'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _statusFilters() {
    final pending = _statusCount('pending');
    final done = _statusCount('done');
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(tr(ar: 'الحالة:', en: 'Status:')),
        for (final option in [
          ('all', tr(ar: 'الكل', en: 'All')),
          ('pending', tr(ar: 'معلّق ($pending)', en: 'Pending ($pending)')),
          ('done', tr(ar: 'خلص ($done)', en: 'Done ($done)')),
        ])
          ChoiceChip(
            label: Text(option.$2),
            selected: _status == option.$1,
            onSelected: (_) => setState(() => _status = option.$1),
          ),
      ],
    );
  }

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
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _dateFilters(),
                const SizedBox(height: 10),
                _statusFilters(),
                const SizedBox(height: 16),
                if (_filteredRows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(_emptyMessage(), textAlign: TextAlign.center),
                  )
                else
                  _CollectionsTable(
                    rows: _filteredRows,
                    onExecute: (row) => _execute(row),
                    showProfits: widget.session.isAdmin,
                    onEdit: widget.session.isAdmin
                        ? (row) => _correct(row, cancel: false)
                        : null,
                    onCancel: widget.session.isAdmin
                        ? (row) => _correct(row, cancel: true)
                        : null,
                  ),
              ],
            ),
    );
  }

  String _emptyMessage() {
    if (_status == 'pending') {
      return tr(
        ar: 'لا توجد معلّقات في الفترة المحددة',
        en: 'No pending collections in this period',
      );
    }
    if (_status == 'done') {
      return tr(
        ar: 'لا توجد تحصيلات خلصت في الفترة المحددة',
        en: 'No completed collections in this period',
      );
    }
    return tr(
      ar: 'لا توجد تحصيلات في الفترة المحددة',
      en: 'No collections in this period',
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

  Future<void> _correct(
    Map<String, dynamic> row, {
    required bool cancel,
  }) async {
    final changed = await showOperationCorrection(
      context,
      widget.session,
      '${row['id']}',
      cancel: cancel,
      basePath: '/ledger/collections/${row['id']}',
    );
    if (changed) {
      await load();
      if (mounted) {
        showAppSnack(
          context,
          cancel
              ? 'تم إلغاء الاستلام وكل أجزائه'
              : 'تم تعديل الاستلام وتحديث الأرصدة',
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
    this.onEdit,
    this.onCancel,
  });

  final List<dynamic> rows;
  final Future<void> Function(Map<String, dynamic> row) onExecute;
  final bool showProfits;
  final Future<void> Function(Map<String, dynamic>)? onEdit;
  final Future<void> Function(Map<String, dynamic>)? onCancel;

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
                              else if (onEdit == null ||
                                  e['status'] == 'reversed')
                                Text('—', style: HesbaText.tableCell),
                              if (e['status'] != 'reversed' &&
                                  onEdit != null) ...[
                                TextButton(
                                  onPressed: () => onEdit!(e),
                                  child: const Text('تعديل'),
                                ),
                                TextButton(
                                  onPressed: () => onCancel!(e),
                                  child: const Text('إلغاء العملية'),
                                ),
                              ],
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

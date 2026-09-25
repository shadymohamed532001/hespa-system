import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/datetime_formatter.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/widgets/data_card.dart';
import '../../core/widgets/error_box.dart';
import '../../core/widgets/page_frame.dart';
import '../../core/widgets/app_snack.dart';
import '../auth/session_controller.dart';
import '../../core/settings/tr.dart';

class LedgerPage extends StatelessWidget {
  const LedgerPage({super.key, required this.session});
  final SessionController session;
  @override
  Widget build(BuildContext context) => _AsyncListFrame(
    session: session,
    title: tr(ar: 'سجل العمليات', en: 'Ledger'),
    subtitle: session.isAdmin
        ? tr(
            ar: 'سجل مركزي غير مختلط بين أصل المبالغ والعمولات',
            en: 'Central ledger separating principal amounts from commissions',
          )
        : tr(ar: 'سجل مركزي لحركات التشغيل', en: 'Central operating ledger'),
    endpoint: ApiEndpoints.ledgerList(limit: 200),
    columns: [
      tr(ar: 'التاريخ والوقت', en: 'Date & time'),
      tr(ar: 'النوع', en: 'Type'),
      tr(ar: 'الوصف', en: 'Description'),
      tr(ar: 'المبلغ', en: 'Amount'),
      tr(ar: 'المرجع', en: 'Reference'),
      tr(ar: 'المستخدم', en: 'User'),
    ],
    allowReversal: session.can(AppPermissions.reverseOperations),
    rowBuilder: (e) => [
      formatDateTime(e['createdAt']),
      _category('${e['category']}'),
      '${e['description']}',
      money(e['amount']),
      e['reference'] ?? '—',
      e['performedBy'] ?? '—',
    ],
  );
}

class _AsyncListFrame extends StatefulWidget {
  const _AsyncListFrame({
    required this.session,
    required this.title,
    required this.subtitle,
    required this.endpoint,
    required this.columns,
    required this.rowBuilder,
    required this.allowReversal,
  });
  final SessionController session;
  final String title, subtitle, endpoint;
  final List<String> columns;
  final List<Object> Function(Map<String, dynamic>) rowBuilder;
  final bool allowReversal;
  @override
  State<_AsyncListFrame> createState() => _AsyncListFrameState();
}

class _AsyncListFrameState extends State<_AsyncListFrame> {
  List<dynamic> data = [];
  String? error;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      data = await widget.session.api.list(widget.endpoint);
      error = null;
    } catch (e) {
      error = ApiClient.errorMessage(e);
    }
    if (mounted) setState(() => loading = false);
  }

  bool _canReverse(Map<String, dynamic> entry, Set<String> reversedIds) {
    const supported = {
      'top_up',
      'internal_transfer',
      'machine_usage',
      'wallet_usage',
      'reconciliation',
    };
    return widget.allowReversal &&
        supported.contains(entry['category']) &&
        !reversedIds.contains('${entry['id']}');
  }

  Future<void> _reverse(Map<String, dynamic> entry) async {
    final reason = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('عكس العملية'),
        content: TextField(
          controller: reason,
          autofocus: true,
          maxLength: 300,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'سبب العكس',
            hintText: 'اكتب سببًا واضحًا للمراجعة',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(ar: 'إلغاء', en: 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final text = reason.text.trim();
              if (text.length >= 3) Navigator.pop(context, text);
            },
            child: Text(tr(ar: 'تأكيد العكس', en: 'Confirm reversal')),
          ),
        ],
      ),
    );
    reason.dispose();
    if (value == null || !mounted) return;
    try {
      await widget.session.api.post(
        ApiEndpoints.reverseLedgerEntry('${entry['id']}'),
        {'reason': value},
      );
      await load();
      if (mounted) showAppSnack(context, 'تم عكس العملية وتسجيل السبب');
    } catch (exception) {
      if (mounted) {
        showAppSnack(context, ApiClient.errorMessage(exception), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: widget.title,
    subtitle: widget.subtitle,
    actions: [
      IconButton.filledTonal(onPressed: load, icon: const Icon(Icons.refresh)),
    ],
    child: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? ErrorBox(message: error!, retry: load)
        : Builder(
            builder: (context) {
              final reversedIds = data
                  .map((item) => item['reversesEntryId'])
                  .whereType<String>()
                  .toSet();
              return DataCard(
                columns: [
                  ...widget.columns,
                  if (widget.allowReversal) tr(ar: 'إجراء', en: 'Action'),
                ],
                rows: data.map((raw) {
                  final entry = raw as Map<String, dynamic>;
                  return <Object>[
                    ...widget.rowBuilder(entry),
                    if (widget.allowReversal)
                      _canReverse(entry, reversedIds)
                          ? TextButton(
                              onPressed: () => _reverse(entry),
                              child: Text(tr(ar: 'عكس', en: 'Reverse')),
                            )
                          : const Text('—'),
                  ];
                }).toList(),
              );
            },
          ),
  );
}

String _category(String value) =>
    {
      'opening_balance': tr(ar: 'رصيد افتتاحي', en: 'Opening balance'),
      'top_up': 'شحن',
      'internal_transfer': tr(ar: 'تحويل داخلي', en: 'Internal transfer'),
      'cash_receipt': 'استلام كاش',
      'company_execution': 'تنفيذ شركة',
      'commission': tr(ar: 'عمولة', en: 'Commission'),
      'wallet_cash_fee': tr(ar: 'عمولة نقدية لمحفظة', en: 'Wallet cash fee'),
      'machine_usage': tr(ar: 'استخدام ماكينة', en: 'Machine usage'),
      'wallet_usage': tr(ar: 'استخدام محفظة', en: 'Wallet usage'),
      'daily_rollover': tr(ar: 'ترحيل يومي', en: 'Daily rollover'),
      'reversal': 'عكس عملية',
      'reconciliation': 'تسوية رصيد',
    }[value] ??
    value;

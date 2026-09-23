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

class LedgerPage extends StatelessWidget {
  const LedgerPage({super.key, required this.session});
  final SessionController session;
  @override
  Widget build(BuildContext context) => _AsyncListFrame(
    session: session,
    title: 'سجل العمليات',
    subtitle: 'سجل مركزي غير مختلط بين أصل المبالغ والعمولات',
    endpoint: ApiEndpoints.ledgerList(limit: 200),
    columns: const [
      'التاريخ والوقت',
      'النوع',
      'الوصف',
      'المبلغ',
      'المرجع',
      'المستخدم',
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
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final text = reason.text.trim();
              if (text.length >= 3) Navigator.pop(context, text);
            },
            child: const Text('تأكيد العكس'),
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
                columns: [...widget.columns, if (widget.allowReversal) 'إجراء'],
                rows: data.map((raw) {
                  final entry = raw as Map<String, dynamic>;
                  return <Object>[
                    ...widget.rowBuilder(entry),
                    if (widget.allowReversal)
                      _canReverse(entry, reversedIds)
                          ? TextButton(
                              onPressed: () => _reverse(entry),
                              child: const Text('عكس'),
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
      'opening_balance': 'رصيد افتتاحي',
      'top_up': 'شحن',
      'internal_transfer': 'تحويل داخلي',
      'cash_receipt': 'استلام كاش',
      'company_execution': 'تنفيذ شركة',
      'commission': 'عمولة',
      'machine_usage': 'استخدام ماكينة',
      'wallet_usage': 'استخدام محفظة',
      'daily_rollover': 'ترحيل يومي',
      'reversal': 'عكس عملية',
      'reconciliation': 'تسوية رصيد',
    }[value] ??
    value;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/widgets/data_card.dart';
import '../../core/widgets/error_box.dart';
import '../../core/widgets/page_frame.dart';
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
      'التاريخ',
      'النوع',
      'الوصف',
      'المبلغ',
      'المرجع',
      'المستخدم',
    ],
    rowBuilder: (e) => [
      _date(e['createdAt']),
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
  });
  final SessionController session;
  final String title, subtitle, endpoint;
  final List<String> columns;
  final List<Object> Function(Map<String, dynamic>) rowBuilder;
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
        : DataCard(
            columns: widget.columns,
            rows: data
                .map((e) => widget.rowBuilder(e as Map<String, dynamic>))
                .toList(),
          ),
  );
}

String _date(dynamic value) {
  final parsed = DateTime.tryParse('$value')?.toLocal();
  return parsed == null
      ? '—'
      : DateFormat('dd/MM/yyyy  hh:mm a', 'en').format(parsed);
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
      'daily_rollover': 'ترحيل يومي',
    }[value] ??
    value;

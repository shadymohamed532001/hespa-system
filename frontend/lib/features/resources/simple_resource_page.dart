import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/data_card.dart';
import '../../core/widgets/error_box.dart';
import '../../core/widgets/metric_card.dart';
import '../../core/widgets/page_frame.dart';
import '../auth/session_controller.dart';

class SimpleResourcePage extends StatefulWidget {
  const SimpleResourcePage({
    super.key,
    required this.session,
    required this.title,
    required this.subtitle,
    required this.endpoint,
    required this.columns,
    required this.rowBuilder,
    this.adminTopUpPath,
    this.topUpLabel,
    this.topUpNote,
  });
  final SessionController session;
  final String title, subtitle, endpoint;
  final List<String> columns;
  final List<Object> Function(Map<String, dynamic>) rowBuilder;
  final String Function(String)? adminTopUpPath;
  final String? topUpLabel, topUpNote;
  @override
  State<SimpleResourcePage> createState() => _SimpleResourcePageState();
}

class _SimpleResourcePageState extends State<SimpleResourcePage> {
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
    actions: widget.session.isAdmin && widget.adminTopUpPath != null
        ? [
            FilledButton.icon(
              onPressed: _topUp,
              icon: const Icon(Icons.add),
              label: Text(widget.topUpLabel!),
            ),
          ]
        : [],
    child: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? ErrorBox(message: error!, retry: load)
        : Column(
            children: [
              if (widget.endpoint == ApiEndpoints.wallets) ...[
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 2.1,
                  children: const [
                    MetricCard(
                      label: 'الحد اليومي للشحن',
                      value: '60,000 ج.م',
                      note: 'لكل محفظة',
                    ),
                    MetricCard(
                      label: 'الحد الشهري للشحن',
                      value: '200,000 ج.م',
                      note: 'لكل محفظة',
                    ),
                    MetricCard(
                      label: 'الترحيل',
                      value: 'تلقائي',
                      note: 'المتبقي يضاف لرصيد اليوم التالي',
                      accent: true,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
              ],
              DataCard(
                columns: widget.columns,
                rows: data
                    .map((e) => widget.rowBuilder(e as Map<String, dynamic>))
                    .toList(),
              ),
            ],
          ),
  );

  Future<void> _topUp() async {
    if (data.isEmpty) return;
    String id = data.first['id'];
    final amount = TextEditingController();
    final reference = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(widget.topUpLabel!),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField(
                  initialValue: id,
                  decoration: const InputDecoration(labelText: 'اختر الحساب'),
                  items: data
                      .map<DropdownMenuItem<String>>(
                        (e) => DropdownMenuItem(
                          value: e['id'],
                          child: Text('${e['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setLocal(() => id = v!),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'المبلغ'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reference,
                  decoration: const InputDecoration(
                    labelText: 'رقم المرجع (اختياري)',
                  ),
                ),
                if (widget.topUpNote != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      widget.topUpNote!,
                      style: const TextStyle(color: HesbaColors.muted),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      try {
        await widget.session.api.post(widget.adminTopUpPath!(id), {
          'amount': num.tryParse(amount.text) ?? 0,
          if (reference.text.isNotEmpty) 'reference': reference.text,
        });
        await load();
        if (mounted) showAppSnack(context, 'تم الشحن بنجاح');
      } catch (e) {
        if (mounted) {
          showAppSnack(context, ApiClient.errorMessage(e), error: true);
        }
      }
    }
  }
}

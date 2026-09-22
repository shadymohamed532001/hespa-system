import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/data_card.dart';
import '../../core/widgets/error_box.dart';
import '../../core/widgets/hesba_modal.dart';
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
    actions:
        widget.session.can(AppPermissions.topUpAssets) &&
            widget.adminTopUpPath != null
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
    var id = '${data.first['id']}';
    final amount = TextEditingController();
    final reference = TextEditingController();
    final ok = await showHesbaModal<bool>(
      context: context,
      maxWidth: 520,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => HesbaModalCard(
          title: widget.topUpLabel!,
          subtitle: widget.topUpNote,
          actions: HesbaModalActions(
            primaryLabel: 'تأكيد',
            onPrimary: () => Navigator.pop(ctx, true),
            onCancel: () => Navigator.pop(ctx, false),
          ),
          child: Column(
            children: [
              HesbaModalField(
                label: 'اختر الحساب *',
                child: DropdownButtonFormField<String>(
                  initialValue: id,
                  isExpanded: true,
                  decoration: const InputDecoration(),
                  items: [
                    for (final e in data)
                      DropdownMenuItem(
                        value: '${e['id']}',
                        child: Text('${e['name']}'),
                      ),
                  ],
                  onChanged: (v) => setLocal(() => id = v!),
                ),
              ),
              const SizedBox(height: 18),
              HesbaModalField(
                label: 'المبلغ *',
                child: TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(),
                ),
              ),
              const SizedBox(height: 18),
              HesbaModalField(
                label: 'رقم المرجع (اختياري)',
                child: TextField(
                  controller: reference,
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

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/data_card.dart';
import '../../core/widgets/error_box.dart';
import '../../core/widgets/page_frame.dart';
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
        widget.session.api.list('/collections'),
        widget.session.api.list('/accounts'),
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
  Widget build(BuildContext context) => PageFrame(
    title: 'التحصيل والمعلّقات',
    subtitle: 'استلام المندوب يمكن تنفيذه فورًا أو حفظه كمعلّق',
    actions: [
      FilledButton(onPressed: _receive, child: const Text('استلام من مندوب')),
    ],
    child: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? ErrorBox(message: error!, retry: load)
        : DataCard(
            columns: const [
              'المرجع',
              'المندوب',
              'الشركة',
              'المبلغ',
              'طريقة التنفيذ',
              'الحالة',
              'الحساب',
              'العمولة',
              'إجراء',
            ],
            rows: data
                .map(
                  (e) => <Object>[
                    '${e['reference']}',
                    '${e['agentName']}',
                    '${e['companyName']}',
                    money(e['amount']),
                    e['executionMode'] == 'hold' ? 'معلّق' : 'فوري',
                    e['status'] == 'pending' ? 'في الانتظار' : 'تم التنفيذ',
                    e['account']?['name'] ?? '—',
                    money(e['commission']),
                    e['status'] == 'pending'
                        ? TextButton(
                            onPressed: () =>
                                _execute(e as Map<String, dynamic>),
                            child: const Text('تنفيذ الآن'),
                          )
                        : const Text(
                            'مكتمل',
                            style: TextStyle(color: HesbaColors.teal),
                          ),
                  ],
                )
                .toList(),
          ),
  );

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
    String accountId = accounts.first['id'];
    final commission = TextEditingController(text: '0');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('تنفيذ المعلّق ${collection['reference']}'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${collection['companyName']} · ${collection['agentName']} · ${money(collection['amount'])}',
                  style: const TextStyle(color: HesbaColors.muted),
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField(
                  initialValue: accountId,
                  decoration: const InputDecoration(
                    labelText: 'الحساب المستخدم',
                  ),
                  items: accounts
                      .map<DropdownMenuItem<String>>(
                        (e) => DropdownMenuItem(
                          value: e['id'],
                          child: Text('${e['name']} — ${money(e['balance'])}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setLocal(() => accountId = v!),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: commission,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'العمولة'),
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
              child: const Text('تأكيد التنفيذ'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      try {
        await widget.session.api.post(
          '/collections/${collection['id']}/execute',
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
}

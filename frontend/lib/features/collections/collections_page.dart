import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/data_card.dart';
import '../../core/widgets/error_box.dart';
import '../../core/widgets/page_frame.dart';
import '../auth/session_controller.dart';

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
      FilledButton.icon(
        onPressed: _receive,
        icon: const Icon(Icons.add),
        label: const Text('استلام كاش'),
      ),
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
    final agent = TextEditingController();
    final company = TextEditingController();
    final amount = TextEditingController();
    final commission = TextEditingController(text: '0');
    String mode = 'hold';
    String? accountId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('استلام كاش من مندوب'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: agent,
                          decoration: const InputDecoration(
                            labelText: 'المندوب',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: company,
                          decoration: const InputDecoration(
                            labelText: 'الشركة',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'المبلغ'),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField(
                    initialValue: mode,
                    decoration: const InputDecoration(
                      labelText: 'طريقة التنفيذ',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'hold',
                        child: Text('حفظ كمعلّق وتنفيذه لاحقًا'),
                      ),
                      DropdownMenuItem(
                        value: 'immediate',
                        child: Text('تنفيذ فوري الآن'),
                      ),
                    ],
                    onChanged: (v) => setLocal(() {
                      mode = v!;
                      accountId = null;
                    }),
                  ),
                  if (mode == 'immediate') ...[
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: accountId,
                      decoration: const InputDecoration(
                        labelText: 'الحساب المستخدم',
                      ),
                      items: accounts
                          .map<DropdownMenuItem<String>>(
                            (e) => DropdownMenuItem(
                              value: e['id'],
                              child: Text(
                                '${e['name']} — ${money(e['balance'])}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setLocal(() => accountId = v),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: commission,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'العمولة'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: mode == 'immediate' && accountId == null
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: Text(mode == 'hold' ? 'تسجيل كمعلّق' : 'تنفيذ فورًا'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      try {
        final request = <String, dynamic>{
          'agentName': agent.text,
          'companyName': company.text,
          'amount': num.tryParse(amount.text) ?? 0,
          'executionMode': mode,
          'commission': num.tryParse(commission.text) ?? 0,
        };
        if (accountId != null) request['accountId'] = accountId;
        await widget.session.api.post('/collections/receive', request);
        await load();
        if (mounted) showAppSnack(context, 'تم تسجيل التحصيل');
      } catch (e) {
        if (mounted) {
          showAppSnack(context, ApiClient.errorMessage(e), error: true);
        }
      }
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

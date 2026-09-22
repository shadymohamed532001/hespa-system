import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/widgets/error_box.dart';
import '../../core/widgets/metric_card.dart';
import '../../core/widgets/page_frame.dart';
import '../auth/session_controller.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.session});
  final SessionController session;
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool loading = true;
  String? error;
  Map<String, dynamic> treasury = {};
  List<dynamic> accounts = [],
      wallets = [],
      machines = [],
      collections = [],
      ledger = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await Future.wait([
        widget.session.api.getMap('/treasury/summary'),
        widget.session.api.list('/accounts'),
        widget.session.api.list('/wallets'),
        widget.session.api.list('/machines'),
        widget.session.api.list('/collections'),
        widget.session.api.list('/ledger?limit=6'),
      ]);
      treasury = values[0] as Map<String, dynamic>;
      accounts = values[1] as List<dynamic>;
      wallets = values[2] as List<dynamic>;
      machines = values[3] as List<dynamic>;
      collections = values[4] as List<dynamic>;
      ledger = values[5] as List<dynamic>;
    } catch (e) {
      error = ApiClient.errorMessage(e);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'لوحة المتابعة',
    subtitle: 'ملخص الموقف المالي والحركات المسجلة الآن',
    actions: [
      IconButton.filledTonal(onPressed: load, icon: const Icon(Icons.refresh)),
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
            children: [
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.7,
                children: [
                  MetricCard(
                    label: 'رصيد الخزنة الفعلي',
                    value: money(treasury['actualBalance']),
                    note: 'الكاش الموجود فعليًا',
                  ),
                  MetricCard(
                    label: 'محجوز للمعلّقات',
                    value: money(treasury['pendingAmount']),
                    note:
                        '${collections.where((e) => e['status'] == 'pending').length} عملية لم تنفذ',
                    warning: true,
                  ),
                  MetricCard(
                    label: 'المتاح للتصرف',
                    value: money(treasury['availableBalance']),
                    note: 'بعد خصم الالتزامات المعلّقة',
                    accent: true,
                  ),
                  MetricCard(
                    label: 'إجمالي الأصول التشغيلية',
                    value: money(_assetsTotal()),
                    note: 'حسابات ومحافظ وماكينات',
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'آخر الحركات',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: HesbaColors.navy,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (ledger.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('لا توجد حركات بعد'),
                        ),
                      ...ledger.map(
                        (entry) =>
                            _ActivityRow(entry: entry as Map<String, dynamic>),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
  );

  num _assetsTotal() {
    final accountTotal = accounts.fold<num>(
      0,
      (sum, e) => sum + (num.tryParse('${e['balance']}') ?? 0),
    );
    final walletTotal = wallets.fold<num>(
      0,
      (sum, e) => sum + (num.tryParse('${e['balance']}') ?? 0),
    );
    final machineTotal = machines.fold<num>(
      0,
      (sum, e) => sum + (num.tryParse('${e['remainingBalance']}') ?? 0),
    );
    return accountTotal + walletTotal + machineTotal;
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry});
  final Map<String, dynamic> entry;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 13),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFEDF1F3))),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: HesbaColors.tealLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.swap_horiz, color: HesbaColors.teal),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '${entry['description']}',
            style: const TextStyle(
              color: HesbaColors.navy,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          money(entry['amount']),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: HesbaColors.navy,
          ),
        ),
      ],
    ),
  );
}

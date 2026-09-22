import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/money_formatter.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/error_box.dart';
import '../../core/widgets/metric_card.dart';
import '../../core/widgets/page_frame.dart';
import '../auth/session_controller.dart';

class TreasuryPage extends StatefulWidget {
  const TreasuryPage({super.key, required this.session});
  final SessionController session;
  @override
  State<TreasuryPage> createState() => _TreasuryPageState();
}

class _TreasuryPageState extends State<TreasuryPage> {
  Map<String, dynamic> summary = {};
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      summary = await widget.session.api.getMap('/treasury/summary');
      error = null;
    } catch (e) {
      error = ApiClient.errorMessage(e);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'الخزنة المركزية',
    subtitle: 'الفرق بين النقد الفعلي والمبلغ الحر المتاح للصرف',
    actions: widget.session.isAdmin
        ? [
            OutlinedButton.icon(
              onPressed: _rollover,
              icon: const Icon(Icons.event_repeat),
              label: const Text('إقفال وترحيل اليوم'),
            ),
          ]
        : [],
    child: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? ErrorBox(message: error!, retry: load)
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 2,
                children: [
                  MetricCard(
                    label: 'رصيد الخزنة الفعلي',
                    value: money(summary['actualBalance']),
                    note: 'كل الكاش الموجود حاليًا',
                  ),
                  MetricCard(
                    label: 'محجوز للمعلّقات',
                    value: money(summary['pendingAmount']),
                    note: 'موجود في الخزنة لكنه التزام',
                    warning: true,
                  ),
                  MetricCard(
                    label: 'المتاح للتصرف',
                    value: money(summary['availableBalance']),
                    note: 'الفعلي ناقص المعلّقات',
                    accent: true,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: HesbaColors.tealLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.info_outline,
                          color: HesbaColors.teal,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ليه الرقمين مختلفين؟',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: HesbaColors.navy,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'الرصيد الفعلي هو الكاش الموجود داخل الخزنة. المتاح للتصرف هو الجزء الحر بعد خصم فلوس المندوبين المرتبطة بعمليات لم تُنفذ بعد. عند تنفيذ المعلّق لا نخصم الكاش مرة ثانية؛ التنفيذ يقلل رصيد حساب التشغيل المستخدم.',
                              style: TextStyle(
                                height: 1.7,
                                color: HesbaColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
  );
  Future<void> _rollover() async {
    try {
      await widget.session.api.post('/treasury/rollover');
      if (mounted) showAppSnack(context, 'تم ترحيل الأرصدة إلى اليوم التالي');
    } catch (e) {
      if (mounted) {
        showAppSnack(context, ApiClient.errorMessage(e), error: true);
      }
    }
  }
}

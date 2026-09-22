import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'api_client.dart';
import 'session.dart';
import 'theme.dart';

final _money = NumberFormat('#,##0.##', 'en');
String money(dynamic value) =>
    '${_money.format(num.tryParse('$value') ?? 0)} ج.م';

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions = const [],
  });
  final String title;
  final String subtitle;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(36),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: HesbaColors.muted),
                  ),
                ],
              ),
            ),
            ...actions.map(
              (e) =>
                  Padding(padding: const EdgeInsets.only(right: 10), child: e),
            ),
          ],
        ),
        const SizedBox(height: 30),
        child,
      ],
    ),
  );
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.note,
    this.accent = false,
    this.warning = false,
  });
  final String label;
  final String value;
  final String note;
  final bool accent;
  final bool warning;

  @override
  Widget build(BuildContext context) => Card(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: warning
            ? const Color(0xFFF0D18E)
            : accent
            ? const Color(0xFFB8DED8)
            : HesbaColors.border,
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(23),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: HesbaColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: HesbaColors.navy,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            note,
            style: const TextStyle(color: HesbaColors.muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

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
        ? _ErrorBox(message: error!, retry: load)
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

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key, required this.session});
  final SessionController session;
  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
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
      data = await widget.session.api.list(
        widget.session.isAdmin ? '/accounts?includeInactive=true' : '/accounts',
      );
      error = null;
    } catch (e) {
      error = ApiClient.errorMessage(e);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'حسابات فوري والشركات',
    subtitle: 'متابعة الرصيد والترحيل والعمولات لكل حساب',
    actions: widget.session.isAdmin
        ? [
            OutlinedButton.icon(
              onPressed: () => _accountDialog(context, null),
              icon: const Icon(Icons.add),
              label: const Text('إضافة حساب'),
            ),
            FilledButton.icon(
              onPressed: () => _chooseTopUp(context),
              icon: const Icon(Icons.add_card),
              label: const Text('شحن حساب'),
            ),
          ]
        : [],
    child: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? _ErrorBox(message: error!, retry: load)
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
                    label: 'إجمالي الأرصدة',
                    value: money(
                      data.fold<num>(
                        0,
                        (s, e) => s + (num.tryParse('${e['balance']}') ?? 0),
                      ),
                    ),
                    note: 'جميع حسابات فوري والشركات',
                  ),
                  MetricCard(
                    label: 'العمولات',
                    value: money(
                      data.fold<num>(
                        0,
                        (s, e) =>
                            s +
                            (num.tryParse('${e['commissionBalance']}') ?? 0),
                      ),
                    ),
                    note: 'منفصلة عن أصل الرصيد',
                    accent: true,
                  ),
                  MetricCard(
                    label: 'عدد الحسابات',
                    value: '${data.length}',
                    note: 'يشمل الحسابات الموقوفة',
                  ),
                  const MetricCard(
                    label: 'الحد الأقصى لفوري',
                    value: '5,000,000 ج.م',
                    note: 'لكل حساب فوري',
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _DataCard(
                columns: const [
                  'الحساب',
                  'النوع',
                  'مرحل من أمس',
                  'شحن اليوم',
                  'الرصيد الحالي',
                  'المتاح حتى الحد',
                  'العمولات',
                  'الحالة',
                ],
                rows: data.map((e) {
                  final fawry = e['type'] == 'fawry';
                  return [
                    '${e['name']}',
                    _accountType('${e['type']}'),
                    money(e['openingBalance']),
                    money(e['todayTopUp']),
                    money(e['balance']),
                    fawry
                        ? money(
                            5000000 - (num.tryParse('${e['balance']}') ?? 0),
                          )
                        : 'بدون حد محدد',
                    money(e['commissionBalance']),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StatusButton(
                          active: e['active'] == true,
                          enabled: widget.session.isAdmin,
                          onChanged: (value) async {
                            await widget.session.api.patch(
                              '/accounts/${e['id']}/status',
                              {'active': value},
                            );
                            await load();
                          },
                        ),
                        if (widget.session.isAdmin)
                          IconButton(
                            tooltip: 'حذف الحساب نهائيًا',
                            onPressed: () => _deleteAccount(
                              e as Map<String, dynamic>,
                            ),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Color(0xFFB42318),
                            ),
                          ),
                      ],
                    ),
                  ];
                }).toList(),
              ),
            ],
          ),
  );

  Future<void> _accountDialog(
    BuildContext context,
    Map<String, dynamic>? _,
  ) async {
    final name = TextEditingController();
    final opening = TextEditingController(text: '0');
    String type = 'fawry';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('إضافة حساب جديد'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'اسم الحساب'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'النوع'),
                  items: const [
                    DropdownMenuItem(value: 'fawry', child: Text('فوري')),
                    DropdownMenuItem(value: 'company', child: Text('شركة')),
                    DropdownMenuItem(value: 'operating', child: Text('تشغيلي')),
                  ],
                  onChanged: (v) => setLocal(() => type = v!),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: opening,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'الرصيد الافتتاحي',
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
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await _action(
        () => widget.session.api.post('/accounts', {
          'name': name.text,
          'type': type,
          'openingBalance': num.tryParse(opening.text) ?? 0,
        }),
      );
    }
  }

  Future<void> _chooseTopUp(BuildContext context) async {
    if (data.isEmpty) return;
    String id = data.first['id'];
    final amount = TextEditingController();
    final reference = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('شحن حساب'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField(
                  initialValue: id,
                  decoration: const InputDecoration(labelText: 'الحساب'),
                  items: data
                      .where((e) => e['active'] == true)
                      .map<DropdownMenuItem<String>>(
                        (e) => DropdownMenuItem(
                          value: e['id'],
                          child: Text('${e['name']} — ${money(e['balance'])}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setLocal(() => id = v!),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'مبلغ الشحن'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: reference,
                  decoration: const InputDecoration(
                    labelText: 'رقم المرجع (اختياري)',
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
              child: const Text('إضافة الرصيد'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await _action(
        () => widget.session.api.post('/accounts/$id/top-up', {
          'amount': num.tryParse(amount.text) ?? 0,
          if (reference.text.isNotEmpty) 'reference': reference.text,
        }),
      );
    }
  }

  Future<void> _action(Future<dynamic> Function() operation) async {
    try {
      await operation();
      await load();
      if (mounted) _snack(context, 'تم حفظ العملية بنجاح');
    } catch (e) {
      if (mounted) _snack(context, ApiClient.errorMessage(e), error: true);
    }
  }

  Future<void> _deleteAccount(Map<String, dynamic> account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحساب'),
        content: Text(
          'هل تريد حذف ${account['name']}؟ الحساب الذي له رصيد أو سجل حركات لا يُحذف، ويمكن إيقافه بدلًا من ذلك.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _action(
        () => widget.session.api.delete('/accounts/${account['id']}'),
      );
    }
  }
}

String _accountType(String type) =>
    {'fawry': 'فوري', 'company': 'شركة', 'operating': 'تشغيلي'}[type] ?? type;

class WalletsPage extends StatelessWidget {
  const WalletsPage({super.key, required this.session});
  final SessionController session;
  @override
  Widget build(BuildContext context) => SimpleResourcePage(
    session: session,
    title: 'المحافظ وInstaPay',
    subtitle: 'الرصيد المتبقي يُرحّل، وحدود الشحن محسوبة تلقائيًا',
    endpoint: '/wallets',
    columns: const [
      'المحفظة',
      'النوع',
      'مرحل من أمس',
      'شحن اليوم',
      'الرصيد',
      'الشحن اليومي',
      'الشحن الشهري',
      'العمولات',
    ],
    rowBuilder: (e) => [
      '${e['name']}',
      e['type'] == 'instapay' ? 'InstaPay' : 'محفظة',
      money(e['openingBalance']),
      money(e['todayTopUp']),
      money(e['balance']),
      '${money(e['dailyTopUp'])} / 60,000',
      '${money(e['monthlyTopUp'])} / 200,000',
      money(e['commissionBalance']),
    ],
    adminTopUpPath: (id) => '/wallets/$id/top-up',
    topUpLabel: 'شحن محفظة',
    topUpNote: 'الحد اليومي 60,000 والشهري 200,000 ج.م',
  );
}

class MachinesPage extends StatelessWidget {
  const MachinesPage({super.key, required this.session});
  final SessionController session;
  @override
  Widget build(BuildContext context) => SimpleResourcePage(
    session: session,
    title: 'ماكينات شحن الرصيد',
    subtitle: 'متابعة كل ماكينة بصورة مستقلة',
    endpoint: '/machines',
    columns: const [
      'الماكينة',
      'المبلغ المشحون',
      'المستخدم',
      'المتبقي',
      'العمولات',
      'الحالة',
    ],
    rowBuilder: (e) => [
      '${e['name']}',
      money(e['loadedBalance']),
      money(e['usedBalance']),
      money(e['remainingBalance']),
      money(e['commissionBalance']),
      e['active'] == true ? 'نشط' : 'موقوف',
    ],
    adminTopUpPath: (id) => '/machines/$id/load',
    topUpLabel: 'شحن ماكينة',
    topUpNote: 'يزيد الرصيد المتاح للماكينة',
  );
}

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
        ? _ErrorBox(message: error!, retry: load)
        : Column(
            children: [
              if (widget.endpoint == '/wallets') ...[
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
              _DataCard(
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
        if (mounted) _snack(context, 'تم الشحن بنجاح');
      } catch (e) {
        if (mounted) _snack(context, ApiClient.errorMessage(e), error: true);
      }
    }
  }
}

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
        ? _ErrorBox(message: error!, retry: load)
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
      if (mounted) _snack(context, 'تم ترحيل الأرصدة إلى اليوم التالي');
    } catch (e) {
      if (mounted) _snack(context, ApiClient.errorMessage(e), error: true);
    }
  }
}

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
        ? _ErrorBox(message: error!, retry: load)
        : _DataCard(
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
        if (mounted) _snack(context, 'تم تسجيل التحصيل');
      } catch (e) {
        if (mounted) _snack(context, ApiClient.errorMessage(e), error: true);
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
        if (mounted) _snack(context, 'تم تنفيذ المعلّق');
      } catch (e) {
        if (mounted) _snack(context, ApiClient.errorMessage(e), error: true);
      }
    }
  }
}

class LedgerPage extends StatelessWidget {
  const LedgerPage({super.key, required this.session});
  final SessionController session;
  @override
  Widget build(BuildContext context) => _AsyncListFrame(
    session: session,
    title: 'سجل العمليات',
    subtitle: 'سجل مركزي غير مختلط بين أصل المبالغ والعمولات',
    endpoint: '/ledger?limit=200',
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

class AdminPage extends StatelessWidget {
  const AdminPage({super.key, required this.session});
  final SessionController session;
  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'الإدارة والصلاحيات',
    subtitle: 'العمليات الحساسة متاحة للمدير فقط',
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          children: const [
            _PermissionRow(
              icon: Icons.person,
              role: 'demo — مدير النظام',
              details:
                  'إضافة وشحن وإيقاف الحسابات والمحافظ والماكينات، التحويل الداخلي، إقفال اليوم، وكل عمليات المستخدم.',
            ),
            Divider(height: 34),
            _PermissionRow(
              icon: Icons.badge_outlined,
              role: 'shix — مستخدم المحل',
              details:
                  'متابعة الأرصدة، استلام الكاش، تسجيل المعلّقات، التنفيذ الفوري وتنفيذ المعلّق، دون إعدادات الإدارة.',
            ),
          ],
        ),
      ),
    ),
  );
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.role,
    required this.details,
  });
  final IconData icon;
  final String role, details;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: HesbaColors.tealLight,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: HesbaColors.teal),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              role,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: HesbaColors.navy,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              details,
              style: const TextStyle(color: HesbaColors.muted, height: 1.6),
            ),
          ],
        ),
      ),
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
        ? _ErrorBox(message: error!, retry: load)
        : _DataCard(
            columns: widget.columns,
            rows: data
                .map((e) => widget.rowBuilder(e as Map<String, dynamic>))
                .toList(),
          ),
  );
}

class _DataCard extends StatelessWidget {
  const _DataCard({required this.columns, required this.rows});
  final List<String> columns;
  final List<List<Object>> rows;
  @override
  Widget build(BuildContext context) => Card(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF0F4F7)),
          horizontalMargin: 24,
          columnSpacing: 42,
          dataRowMinHeight: 58,
          dataRowMaxHeight: 66,
          columns: columns
              .map(
                (c) => DataColumn(
                  label: Text(
                    c,
                    style: const TextStyle(
                      color: HesbaColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              )
              .toList(),
          rows: rows
              .map(
                (row) => DataRow(
                  cells: row
                      .map(
                        (cell) => DataCell(
                          cell is Widget
                              ? cell
                              : Text(
                                  '$cell',
                                  style: const TextStyle(
                                    color: HesbaColors.muted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      )
                      .toList(),
                ),
              )
              .toList(),
        ),
      ),
    ),
  );
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.active,
    required this.enabled,
    required this.onChanged,
  });
  final bool active, enabled;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: enabled ? () => onChanged(!active) : null,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
      decoration: BoxDecoration(
        color: active ? HesbaColors.tealLight : const Color(0xFFFFEEEE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'نشط' : 'موقوف',
        style: TextStyle(
          color: active ? HesbaColors.teal : const Color(0xFFB42318),
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: HesbaColors.muted,
            ),
            const SizedBox(height: 14),
            Text(message),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: retry,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    ),
  );
}

void _snack(BuildContext context, String message, {bool error = false}) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFFB42318) : HesbaColors.teal,
      ),
    );
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

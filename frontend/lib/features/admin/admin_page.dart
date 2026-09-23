import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/error_box.dart';
import '../../core/widgets/hesba_modal.dart';
import '../../core/widgets/page_frame.dart';
import '../../core/widgets/soft_badge.dart';
import '../auth/session_controller.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key, required this.session});

  final SessionController session;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  List<dynamic> users = [];
  List<dynamic> catalog = [];
  bool loading = true;
  String? error;

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
      final results = await Future.wait([
        widget.session.api.list(ApiEndpoints.users),
        widget.session.api.list(ApiEndpoints.usersPermissionCatalog),
      ]);
      if (!mounted) return;
      setState(() {
        users = results[0];
        catalog = results[1];
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = ApiClient.errorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'المستخدمون والصلاحيات',
      subtitle: 'أضف حسابات للموظفين وحدد صلاحياتهم وحدود المبالغ',
      actions: [
        FilledButton.icon(
          onPressed: () => _openUserEditor(),
          icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
          label: const Text('إضافة مستخدم'),
        ),
      ],
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? ErrorBox(message: error!, retry: load)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _BackendNotice(),
                const SizedBox(height: 20),
                _UsersCard(
                  users: users,
                  onManage: _openUserEditor,
                  onToggleActive: _toggleActive,
                ),
                const SizedBox(height: 20),
                _PermissionMatrixCard(catalog: catalog),
              ],
            ),
    );
  }

  Future<void> _toggleActive(Map<String, dynamic> user) async {
    final id = '${user['id']}';
    final active = user['active'] == true;
    try {
      await widget.session.api.patch(ApiEndpoints.userStatus(id), {
        'active': !active,
      });
      await load();
      if (mounted) {
        showAppSnack(context, active ? 'تم تعطيل الحساب' : 'تم تفعيل الحساب');
      }
    } catch (e) {
      if (mounted) {
        showAppSnack(context, ApiClient.errorMessage(e), error: true);
      }
    }
  }

  Future<void> _openUserEditor([Map<String, dynamic>? existing]) async {
    final isEdit = existing != null;
    final username = TextEditingController(
      text: existing?['username']?.toString() ?? '',
    );
    final displayName = TextEditingController(
      text: existing?['displayName']?.toString() ?? '',
    );
    final password = TextEditingController();
    final selected = <String>{
      ...((existing?['permissions'] as List<dynamic>?) ??
              const [
                AppPermissions.viewBalances,
                AppPermissions.receiveCollections,
                AppPermissions.sellInventory,
                AppPermissions.useMachines,
              ])
          .map((e) => '$e'),
    };
    final limits = Map<String, dynamic>.from(
      (existing?['limits'] as Map?) ?? const {},
    );
    final maxReceive = TextEditingController(
      text: _limitText(limits['maxReceiveAmount']),
    );
    final maxTopUp = TextEditingController(
      text: _limitText(limits['maxTopUpAmount']),
    );
    final maxSale = TextEditingController(
      text: _limitText(limits['maxSaleAmount']),
    );
    final maxTransfer = TextEditingController(
      text: _limitText(limits['maxTransferAmount']),
    );

    final catalogItems = catalog.isNotEmpty ? catalog : _fallbackCatalog;

    final ok = await showHesbaModal<bool>(
      context: context,
      maxWidth: 640,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => HesbaModalCard(
          title: isEdit ? 'تعديل المستخدم' : 'إضافة مستخدم',
          subtitle: isEdit
              ? 'حدّث الصلاحيات أو الحدود أو كلمة المرور'
              : 'أنشئ حسابًا لشخص يعمل معك وحدد ما يُسمح له به',
          actions: HesbaModalActions(
            primaryLabel: isEdit ? 'حفظ' : 'إنشاء الحساب',
            onPrimary: () => Navigator.pop(ctx, true),
            onCancel: () => Navigator.pop(ctx, false),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isEdit) ...[
                HesbaModalField(
                  label: 'اسم المستخدم *',
                  child: TextField(
                    controller: username,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.left,
                    decoration: const InputDecoration(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              HesbaModalField(
                label: 'الاسم الظاهر',
                child: TextField(
                  controller: displayName,
                  decoration: const InputDecoration(),
                ),
              ),
              const SizedBox(height: 16),
              HesbaModalField(
                label: isEdit ? 'كلمة مرور جديدة (اختياري)' : 'كلمة المرور *',
                child: TextField(
                  controller: password,
                  obscureText: true,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  decoration: const InputDecoration(),
                ),
              ),
              const SizedBox(height: 20),
              const Text('الصلاحيات', style: HesbaText.sectionTitle),
              const SizedBox(height: 8),
              for (final item in catalogItems)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: selected.contains('${item['key']}'),
                  title: Text('${item['label']}', style: HesbaText.tableCell),
                  subtitle: Text('${item['note']}', style: HesbaText.panelSub),
                  onChanged: existing?['role'] == 'admin'
                      ? null
                      : (v) => setLocal(() {
                          final key = '${item['key']}';
                          if (v == true) {
                            selected.add(key);
                          } else {
                            selected.remove(key);
                          }
                        }),
                ),
              const SizedBox(height: 12),
              const Text('حدود المبالغ', style: HesbaText.sectionTitle),
              const SizedBox(height: 4),
              const Text(
                'اترك الحقل فارغًا = بدون حد',
                style: HesbaText.panelSub,
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final two = constraints.maxWidth >= 520;
                  final width = two
                      ? (constraints.maxWidth - 16) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 14,
                    children: [
                      SizedBox(
                        width: width,
                        child: HesbaModalField(
                          label: 'حد الاستلام/التحصيل',
                          child: TextField(
                            controller: maxReceive,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              hintText: 'بدون حد',
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: HesbaModalField(
                          label: 'حد الشحن',
                          child: TextField(
                            controller: maxTopUp,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              hintText: 'بدون حد',
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: HesbaModalField(
                          label: 'حد البيع',
                          child: TextField(
                            controller: maxSale,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              hintText: 'بدون حد',
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: HesbaModalField(
                          label: 'حد التحويل الداخلي',
                          child: TextField(
                            controller: maxTransfer,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                            ],
                            decoration: const InputDecoration(
                              hintText: 'بدون حد',
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (ok != true) return;

    if (!isEdit &&
        (username.text.trim().isEmpty || password.text.trim().isEmpty)) {
      if (!mounted) return;
      showAppSnack(context, 'اسم المستخدم وكلمة المرور مطلوبان', error: true);
      return;
    }

    final payload = <String, dynamic>{
      if (!isEdit) 'username': username.text.trim(),
      'displayName': displayName.text.trim().isEmpty
          ? username.text.trim()
          : displayName.text.trim(),
      if (password.text.trim().isNotEmpty) 'password': password.text.trim(),
      if (existing?['role'] != 'admin') 'permissions': selected.toList(),
      'limits': {
        'maxReceiveAmount': _parseLimit(maxReceive.text),
        'maxTopUpAmount': _parseLimit(maxTopUp.text),
        'maxSaleAmount': _parseLimit(maxSale.text),
        'maxTransferAmount': _parseLimit(maxTransfer.text),
      },
    };

    try {
      if (isEdit) {
        await widget.session.api.patch(
          ApiEndpoints.user('${existing['id']}'),
          payload,
        );
      } else {
        await widget.session.api.post(ApiEndpoints.users, payload);
      }
      await load();
      if (mounted) {
        showAppSnack(
          context,
          isEdit ? 'تم تحديث المستخدم' : 'تم إنشاء الحساب بنجاح',
        );
      }
    } catch (e) {
      if (mounted) {
        showAppSnack(context, ApiClient.errorMessage(e), error: true);
      }
    }
  }

  String _limitText(dynamic value) {
    if (value == null) return '';
    return '$value';
  }

  num? _parseLimit(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return num.tryParse(trimmed);
  }
}

const _fallbackCatalog = [
  {
    'key': AppPermissions.viewBalances,
    'label': 'مشاهدة الأرصدة والحركات',
    'note': 'للمتابعة اليومية',
  },
  {
    'key': AppPermissions.receiveCollections,
    'label': 'استلام كاش المندوب وتنفيذ التحصيل',
    'note': 'العمليات اليومية',
  },
  {
    'key': AppPermissions.manageAssets,
    'label': 'إضافة أو تعديل الحسابات والمحافظ والماكينات',
    'note': 'إعدادات الأصول',
  },
  {
    'key': AppPermissions.topUpAssets,
    'label': 'شحن الحسابات والمحافظ وتحميل الماكينات',
    'note': 'من لوحة الإدارة',
  },
  {
    'key': AppPermissions.internalTransfer,
    'label': 'التحويل الداخلي بين أصول المحل',
    'note': 'نقل داخلي بلا ربح أو مصروف',
  },
  {
    'key': AppPermissions.dailyRollover,
    'label': 'إقفال اليوم وترحيل الرصيد',
    'note': 'تثبيت الرصيد الافتتاحي',
  },
  {
    'key': AppPermissions.manageUsers,
    'label': 'إدارة المستخدمين والصلاحيات',
    'note': 'إعدادات النظام',
  },
  {
    'key': AppPermissions.sellInventory,
    'label': 'بيع أصناف من مخزن الموبايلات والإكسسوارات',
    'note': 'فلوس البيع تذهب لخزنة المخزن فقط',
  },
  {
    'key': AppPermissions.manageInventory,
    'label': 'إضافة أصناف وتوريد مخزون للمخزن',
    'note': 'إعدادات مخزن منفصل عن الكاش',
  },
  {
    'key': AppPermissions.useMachines,
    'label': 'استخدام ماكينات شحن الرصيد',
    'note': 'خصم من رصيد الماكينة',
  },
  {
    'key': AppPermissions.reverseOperations,
    'label': 'عكس العمليات المالية',
    'note': 'صلاحية حساسة مع توثيق السبب',
  },
  {
    'key': AppPermissions.reconcileBalances,
    'label': 'تسوية الأرصدة الفعلية',
    'note': 'مطابقة الجرد الفعلي مع النظام',
  },
];

class _UsersCard extends StatelessWidget {
  const _UsersCard({
    required this.users,
    required this.onManage,
    required this.onToggleActive,
  });

  final List<dynamic> users;
  final void Function([Map<String, dynamic>?]) onManage;
  final void Function(Map<String, dynamic>) onToggleActive;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 22, 0, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22),
              child: Text('حسابات النظام', style: HesbaText.sectionTitle),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22),
              child: Text(
                'كل شخص شغال معاك يقدر يدخل بحسابه وحدوده الخاصة.',
                style: HesbaText.panelSub,
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        const Color(0xFFF2F5F8),
                      ),
                      headingRowHeight: 54,
                      horizontalMargin: 22,
                      columnSpacing: 36,
                      dataRowMinHeight: 64,
                      dataRowMaxHeight: 72,
                      columns: const [
                        DataColumn(
                          label: Text('المستخدم', style: _headerStyle),
                        ),
                        DataColumn(label: Text('الدور', style: _headerStyle)),
                        DataColumn(label: Text('الحالة', style: _headerStyle)),
                        DataColumn(
                          label: Text('الصلاحيات', style: _headerStyle),
                        ),
                        DataColumn(label: Text('إجراء', style: _headerStyle)),
                      ],
                      rows: [
                        for (final raw in users)
                          _userRow(
                            Map<String, dynamic>.from(raw as Map),
                            onManage,
                            onToggleActive,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  static DataRow _userRow(
    Map<String, dynamic> user,
    void Function([Map<String, dynamic>?]) onManage,
    void Function(Map<String, dynamic>) onToggleActive,
  ) {
    final perms = (user['permissions'] as List<dynamic>? ?? const []).length;
    final isAdmin = user['role'] == 'admin';
    return DataRow(
      cells: [
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${user['displayName'] ?? user['username']}',
                style: HesbaText.tableEmphasis,
              ),
              Text('${user['username']}', style: HesbaText.panelSub),
            ],
          ),
        ),
        DataCell(Text(isAdmin ? 'أدمن' : 'موظف', style: HesbaText.tableCell)),
        DataCell(SoftBadge.status(active: user['active'] == true)),
        DataCell(
          Text(
            isAdmin ? 'كل الصلاحيات' : '$perms صلاحية',
            style: HesbaText.tableCell,
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => onManage(user),
                child: const Text('إدارة'),
              ),
              if (!isAdmin)
                TextButton(
                  onPressed: () => onToggleActive(user),
                  child: Text(user['active'] == true ? 'تعطيل' : 'تفعيل'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PermissionMatrixCard extends StatelessWidget {
  const _PermissionMatrixCard({required this.catalog});

  final List<dynamic> catalog;

  @override
  Widget build(BuildContext context) {
    final rows = catalog.isNotEmpty ? catalog : _fallbackCatalog;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 22, 0, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22),
              child: Text(
                'مصفوفة الصلاحيات الافتراضية',
                style: HesbaText.sectionTitle,
              ),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22),
              child: Text(
                'الأدمن يملك الكل. الموظف يبدأ بصلاحيات يومية ويمكن تخصيصها لكل حساب.',
                style: HesbaText.panelSub,
              ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      const Color(0xFFF2F5F8),
                    ),
                    headingRowHeight: 54,
                    horizontalMargin: 22,
                    columnSpacing: 36,
                    columns: const [
                      DataColumn(label: Text('العملية', style: _headerStyle)),
                      DataColumn(label: Text('الأدمن', style: _headerStyle)),
                      DataColumn(
                        label: Text('موظف (افتراضي)', style: _headerStyle),
                      ),
                      DataColumn(label: Text('ملاحظة', style: _headerStyle)),
                    ],
                    rows: [
                      for (final item in rows)
                        DataRow(
                          cells: [
                            DataCell(
                              Text(
                                '${item['label']}',
                                style: HesbaText.tableEmphasis.copyWith(
                                  color: const Color(0xFF5A6F7C),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                            const DataCell(SoftBadge.permission(allowed: true)),
                            DataCell(
                              SoftBadge.permission(
                                allowed: _defaultEmployeeKeys.contains(
                                  '${item['key']}',
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '${item['note']}',
                                style: HesbaText.tableCell,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _defaultEmployeeKeys = {
  AppPermissions.viewBalances,
  AppPermissions.receiveCollections,
  AppPermissions.sellInventory,
  AppPermissions.useMachines,
};

const _headerStyle = HesbaText.tableHeader;

class _BackendNotice extends StatelessWidget {
  const _BackendNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE9EEF6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD5DEEA)),
      ),
      child: const Text(
        'الصلاحيات وحدود المبالغ تُطبَّق من الباك إند. إخفاء الأزرار في الواجهة وحده لا يكفي.',
        style: HesbaText.callout,
      ),
    );
  }
}

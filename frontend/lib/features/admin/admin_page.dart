import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/page_frame.dart';
import '../auth/session_controller.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key, required this.session});

  final SessionController session;

  static const _rows = <_PermissionItem>[
    _PermissionItem(
      action: 'مشاهدة الأرصدة والحركات',
      adminAllowed: true,
      staffAllowed: true,
      note: 'للمتابعة اليومية',
    ),
    _PermissionItem(
      action: 'استلام كاش المندوب وتنفيذ التحصيل',
      adminAllowed: true,
      staffAllowed: true,
      note: 'العمليات اليومية',
    ),
    _PermissionItem(
      action: 'إضافة أو تعديل الحسابات والمحافظ والماكينات',
      adminAllowed: true,
      staffAllowed: false,
      note: 'إعدادات الأصول',
    ),
    _PermissionItem(
      action: 'شحن الحسابات والمحافظ وتحميل الماكينات مباشرة',
      adminAllowed: true,
      staffAllowed: false,
      note: 'من لوحة الإدارة',
    ),
    _PermissionItem(
      action: 'التحويل الداخلي بين أصول المحل',
      adminAllowed: true,
      staffAllowed: false,
      note: 'نقل داخلي بلا ربح أو مصروف',
    ),
    _PermissionItem(
      action: 'إقفال اليوم وترحيل الرصيد',
      adminAllowed: true,
      staffAllowed: false,
      note: 'تثبيت الرصيد الافتتاحي',
    ),
    _PermissionItem(
      action: 'إدارة المستخدمين والصلاحيات',
      adminAllowed: true,
      staffAllowed: false,
      note: 'إعدادات النظام',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return PageFrame(
      title: 'المستخدمون والصلاحيات',
      subtitle: 'تحديد ما يستطيع الأدمن وموظف المحل تنفيذه',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _BackendNotice(),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 22, 0, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 22),
                    child: Text(
                      'مصفوفة الصلاحيات',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: HesbaColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 22),
                    child: Text(
                      'الأدمن يملك الإعدادات الحساسة، وموظف المحل ينفذ المهام اليومية فقط.',
                      style: TextStyle(
                        color: HesbaColors.muted,
                        fontSize: 13,
                        height: 1.55,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth,
                        ),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            const Color(0xFFF2F5F8),
                          ),
                          headingRowHeight: 54,
                          horizontalMargin: 22,
                          columnSpacing: 36,
                          dataRowMinHeight: 58,
                          dataRowMaxHeight: 64,
                          columns: const [
                            DataColumn(
                              label: Text(
                                'العملية',
                                style: _headerStyle,
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'الأدمن',
                                style: _headerStyle,
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'موظف المحل',
                                style: _headerStyle,
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'ملاحظة',
                                style: _headerStyle,
                              ),
                            ),
                          ],
                          rows: [
                            for (final item in _rows)
                              DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      item.action,
                                      style: const TextStyle(
                                        color: HesbaColors.ink,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    _PermissionBadge(
                                      allowed: item.adminAllowed,
                                    ),
                                  ),
                                  DataCell(
                                    _PermissionBadge(
                                      allowed: item.staffAllowed,
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      item.note,
                                      style: const TextStyle(
                                        color: HesbaColors.muted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                      ),
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
          ),
        ],
      ),
    );
  }
}

const _headerStyle = TextStyle(
  color: Color(0xFF607480),
  fontSize: 12,
  fontWeight: FontWeight.w600,
);

class _PermissionItem {
  const _PermissionItem({
    required this.action,
    required this.adminAllowed,
    required this.staffAllowed,
    required this.note,
  });

  final String action;
  final bool adminAllowed;
  final bool staffAllowed;
  final String note;
}

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
        'مهم: في التطبيق الحقيقي تُطبَّق الصلاحيات من الباك إند، وليس بمجرد إخفاء الأزرار من الواجهة.',
        style: TextStyle(
          color: Color(0xFF50657D),
          fontSize: 13,
          height: 1.55,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _PermissionBadge extends StatelessWidget {
  const _PermissionBadge({required this.allowed});

  final bool allowed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: allowed ? HesbaColors.tealLight : const Color(0xFFFFEEEE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        allowed ? 'مسموح' : 'غير مسموح',
        style: TextStyle(
          color: allowed ? HesbaColors.teal : const Color(0xFFB42318),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

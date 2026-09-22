import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/page_frame.dart';
import '../auth/session_controller.dart';

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

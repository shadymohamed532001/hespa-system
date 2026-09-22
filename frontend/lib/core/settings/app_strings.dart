import 'package:flutter/widgets.dart';

/// Lightweight chrome strings for AR/EN toggle (shell + common actions).
class AppStrings {
  const AppStrings._(this._ar);

  final bool _ar;

  factory AppStrings.of(Locale locale) =>
      AppStrings._(locale.languageCode != 'en');

  String get brand => _ar ? 'حِسبة' : 'Hesba';
  String get brandSub =>
      _ar ? 'إدارة التحصيل والمدفوعات' : 'Collections & payments';

  String get currentUser => _ar ? 'المستخدم الحالي' : 'Current user';
  String get adminRole => _ar ? 'أدمن' : 'Admin';
  String get staffRole => _ar ? 'موظف محل' : 'Staff';
  String get adminTitle => _ar ? 'مدير النظام' : 'System admin';
  String get staffTitle => _ar ? 'موظف المحل' : 'Branch staff';
  String get adminHint =>
      _ar ? 'صلاحيات كاملة لإدارة النظام' : 'Full system access';
  String get staffHint =>
      _ar ? 'صلاحيات التشغيل اليومية' : 'Day-to-day operations';
  String get logout => _ar ? 'تسجيل الخروج' : 'Log out';

  String get branchPath =>
      _ar ? 'الفرع الرئيسي  /  الإدارة المالية' : 'Main branch  /  Finance';

  String get dashboard => _ar ? 'لوحة المتابعة' : 'Dashboard';
  String get treasury => _ar ? 'الخزنة المركزية' : 'Central treasury';
  String get accounts => _ar ? 'فوري والشركات' : 'Fawry & companies';
  String get topUp => _ar ? 'شحن حساب / محفظة' : 'Top up account / wallet';
  String get wallets => _ar ? 'المحافظ وInstaPay' : 'Wallets & InstaPay';
  String get machines => _ar ? 'ماكينات شحن الرصيد' : 'Balance machines';
  String get collections =>
      _ar ? 'تحصيلات المندوبين / Hold' : 'Agent collections / Hold';
  String get inventory =>
      _ar ? 'مخزن الموبايلات والإكسسوارات' : 'Mobiles & accessories store';
  String get transfer => _ar ? 'تحويل داخلي' : 'Internal transfer';
  String get settlement =>
      _ar ? 'توريد وتسوية شركة' : 'Company settlement';
  String get ledger => _ar ? 'سجل العمليات' : 'Ledger';
  String get reports => _ar ? 'التقارير الشاملة' : 'Reports';
  String get users => _ar ? 'المستخدمون والصلاحيات' : 'Users & permissions';

  String get languageTooltip =>
      _ar ? 'التبديل إلى الإنجليزية' : 'Switch to Arabic';
  String get themeTooltip =>
      _ar ? 'الوضع الداكن' : 'Dark mode';
  String get themeTooltipLight =>
      _ar ? 'الوضع الفاتح' : 'Light mode';
  String get notificationsTooltip =>
      _ar ? 'الإشعارات' : 'Notifications';

  String get notificationsTitle => _ar ? 'الإشعارات' : 'Notifications';
  String get markAllRead =>
      _ar ? 'تعيين الكل كمقروء' : 'Mark all as read';
  String get noNotifications =>
      _ar ? 'لا توجد إشعارات بعد' : 'No notifications yet';
}

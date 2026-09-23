import 'package:flutter/widgets.dart';

/// Lightweight chrome strings for AR/EN toggle (shell + common actions).
class AppStrings {
  const AppStrings._(this._ar);

  final bool _ar;

  factory AppStrings.of(Locale locale) =>
      AppStrings._(locale.languageCode != 'en');

  bool get isArabic => _ar;
  String get localeCode => _ar ? 'ar' : 'en';
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
      _ar ? 'تحصيلات المندوبين / معلّقات' : 'Agent collections / Pending';
  String get inventory =>
      _ar ? 'مخزن الموبايلات والإكسسوارات' : 'Mobiles & accessories store';
  String get transfer => _ar ? 'تحويل داخلي' : 'Internal transfer';
  String get settlement => _ar ? 'توريد وتسوية شركة' : 'Company settlement';
  String get ledger => _ar ? 'سجل العمليات' : 'Ledger';
  String get reports => _ar ? 'التقارير الشاملة' : 'Reports';
  String get users => _ar ? 'المستخدمون والصلاحيات' : 'Users & permissions';

  String get languageTooltip =>
      _ar ? 'التبديل إلى الإنجليزية' : 'Switch to Arabic';
  String get themeTooltip => _ar ? 'الوضع الداكن' : 'Dark mode';
  String get themeTooltipLight => _ar ? 'الوضع الفاتح' : 'Light mode';
  String get notificationsTooltip => _ar ? 'الإشعارات' : 'Notifications';

  String get notificationsTitle => _ar ? 'الإشعارات' : 'Notifications';
  String get markAllRead => _ar ? 'تعيين الكل كمقروء' : 'Mark all as read';
  String get noNotifications =>
      _ar ? 'لا توجد إشعارات بعد' : 'No notifications yet';

  String get retry => _ar ? 'إعادة المحاولة' : 'Retry';
  String get cancel => _ar ? 'إلغاء' : 'Cancel';
  String get save => _ar ? 'حفظ' : 'Save';
  String get delete => _ar ? 'حذف' : 'Delete';
  String get confirm => _ar ? 'تأكيد' : 'Confirm';
  String get loading => _ar ? 'جارٍ التحميل...' : 'Loading...';
  String get unexpectedError =>
      _ar ? 'حدث خطأ غير متوقع' : 'An unexpected error occurred';

  String get choosePortalTitle =>
      _ar ? 'اختر مدخل الدخول' : 'Choose a sign-in portal';
  String get choosePortalSubtitle => _ar
      ? 'كل مدخل مخصص لنوع حساب مختلف. بعد الدخول تظهر لك الصلاحيات المتاحة فقط.'
      : 'Each portal is for a different account type. After sign-in you only see what you are allowed to use.';
  String get securityPortal => _ar ? 'مدخل الأمن' : 'Security portal';
  String get staffPortal => _ar ? 'مدخل الموظفين' : 'Staff portal';
  String get securityPortalSubtitle =>
      _ar ? 'دخول مديري النظام والإدارة' : 'For system admins and management';
  String get staffPortalSubtitle => _ar
      ? 'دخول موظفي المحل والتشغيل اليومي'
      : 'For branch staff and daily operations';
  String get securitySignIn =>
      _ar ? 'دخول مدخل الأمن' : 'Sign in to security portal';
  String get staffSignIn =>
      _ar ? 'دخول مدخل الموظفين' : 'Sign in to staff portal';
  String get username => _ar ? 'اسم المستخدم' : 'Username';
  String get password => _ar ? 'كلمة المرور' : 'Password';
  String get backToPortals =>
      _ar ? 'العودة لاختيار المدخل' : 'Back to portal selection';
  String get demoAccounts =>
      _ar ? 'حسابات النسخة التجريبية' : 'Demo accounts';
  String get demoSecurityAccount =>
      _ar ? 'الأمن: demo / demo' : 'Security: demo / demo';
  String get demoStaffAccount =>
      _ar ? 'موظف المحل: shix / shix' : 'Branch staff: shix / shix';
  String get adminCreated =>
      _ar ? 'تم إنشاء المدير. يمكنك تسجيل الدخول الآن' : 'Admin created. You can sign in now';
  String get recoverAdminTitle =>
      _ar ? 'إنشاء مدير استعادة' : 'Create recovery admin';
  String get recoverAdminSubtitle => _ar
      ? 'سيحصل هذا الحساب على كل صلاحيات النظام'
      : 'This account will receive full system access';
  String get recoverAdminAction =>
      _ar ? 'إنشاء المدير' : 'Create admin';
  String get recoverAdminBusy =>
      _ar ? 'جارٍ الإنشاء...' : 'Creating...';
  String get recoverAdminTooltip =>
      _ar ? 'استعادة حساب مدير' : 'Recover admin account';
  String get recoveryKey =>
      _ar ? 'كود استعادة المدير *' : 'Admin recovery code *';
  String get displayName => _ar ? 'الاسم الظاهر' : 'Display name';
  String get passwordConfirm =>
      _ar ? 'تأكيد كلمة المرور *' : 'Confirm password *';
  String get usernameRequired => _ar ? 'اسم المستخدم *' : 'Username *';
  String get passwordRequired => _ar ? 'كلمة المرور *' : 'Password *';
  String get recoveryRequiredFields => _ar
      ? 'كود الاستعادة واسم المستخدم وكلمة المرور مطلوبة'
      : 'Recovery code, username, and password are required';
  String get passwordTooShort =>
      _ar ? 'كلمة المرور يجب ألا تقل عن 10 أحرف' : 'Password must be at least 10 characters';
  String get passwordsMismatch =>
      _ar ? 'كلمتا المرور غير متطابقتين' : 'Passwords do not match';

  String get systemUnavailableTitle =>
      _ar ? 'النظام غير متاح حالياً' : 'System is currently unavailable';
  String get systemUnavailableBody => _ar
      ? 'يرجى التواصل مع مطور السيستم لحل مشكلة'
      : 'Please contact the system developer to resolve the issue';
  String get systemUnavailableHint => _ar
      ? 'تم إيقاف التشغيل مؤقتاً من لوحة التحكم. بعد حل المشكلة وإعادة تفعيل النظام يمكنك المحاولة مرة أخرى.'
      : 'Operation was temporarily paused from the control panel. After the issue is fixed and the system is re-enabled, you can try again.';

  String connectionTimeout() => _ar
      ? 'انتهت مهلة الاتصال بالخادم.'
      : 'Connection to the server timed out.';
  String sendTimeout() => _ar
      ? 'انتهت مهلة إرسال البيانات إلى الخادم.'
      : 'Sending data to the server timed out.';
  String receiveTimeout() => _ar
      ? 'انتهت مهلة انتظار استجابة الخادم.'
      : 'Waiting for the server response timed out.';
  String connectionError() => _ar
      ? 'تعذر الاتصال بالخادم. تأكد أن الباك إند وقاعدة البيانات يعملان.'
      : 'Could not connect to the server. Make sure the backend and database are running.';
  String badResponse(Object? status) => _ar
      ? 'حدث خطأ في استجابة الخادم ($status).'
      : 'Server response error ($status).';
  String get requestCancelled =>
      _ar ? 'تم إلغاء الطلب.' : 'The request was cancelled.';
  String get badCertificate => _ar
      ? 'حدث خطأ في شهادة الاتصال بالخادم.'
      : 'There was a problem with the server certificate.';
  String get genericNetworkError =>
      _ar ? 'تعذر إكمال الاتصال بالخادم.' : 'Could not complete the server request.';
  String get unknownStatus => _ar ? 'غير معروف' : 'unknown';
}

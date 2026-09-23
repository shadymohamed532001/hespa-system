import 'app_locale_holder.dart';

/// Locale-aware copy without needing BuildContext.
String tr({required String ar, required String en}) =>
    AppLocaleHolder.isArabic ? ar : en;

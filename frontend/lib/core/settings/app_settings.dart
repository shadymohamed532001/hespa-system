import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_locale_holder.dart';

/// Persisted locale + theme preferences for the whole app chrome.
class AppSettings extends ChangeNotifier {
  static const _localeKey = 'app_locale';
  static const _themeKey = 'app_theme_mode';

  Locale locale = const Locale('ar');
  ThemeMode themeMode = ThemeMode.light;
  bool ready = false;

  bool get isArabic => locale.languageCode == 'ar';
  bool get isDark => themeMode == ThemeMode.dark;
  TextDirection get textDirection =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localeKey) ?? 'ar';
    final theme = prefs.getString(_themeKey) ?? 'light';
    locale = Locale(code == 'en' ? 'en' : 'ar');
    AppLocaleHolder.setCode(locale.languageCode);
    themeMode = theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
    ready = true;
    notifyListeners();
  }

  Future<void> toggleLocale() async {
    locale = isArabic ? const Locale('en') : const Locale('ar');
    AppLocaleHolder.setCode(locale.languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    themeMode = isDark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _themeKey,
      themeMode == ThemeMode.dark ? 'dark' : 'light',
    );
    notifyListeners();
  }
}

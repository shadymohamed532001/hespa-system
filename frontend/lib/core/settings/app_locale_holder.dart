/// Process-wide UI/API locale code (`ar` | `en`), kept in sync with AppSettings.
class AppLocaleHolder {
  static String code = 'ar';

  static bool get isArabic => code != 'en';

  static void setCode(String languageCode) {
    code = languageCode == 'en' ? 'en' : 'ar';
  }
}

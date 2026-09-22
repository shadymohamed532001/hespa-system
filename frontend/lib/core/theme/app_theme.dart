import 'package:flutter/material.dart';

/// Colors + type scale mirrored from `hesba-company-settlement.html`.
class HesbaColors {
  static const navy = Color(0xFF102F3E);
  static const navyDark = Color(0xFF173D4D);
  static const ink = Color(0xFF1B3342);
  static const teal = Color(0xFF0B8C7E);
  static const tealDark = Color(0xFF08776B);
  static const tealLight = Color(0xFFE5F4F1);
  static const tealSoft = Color(0xFF287E75);
  static const background = Color(0xFFEDF2F5);
  static const soft = Color(0xFFF6F8FA);
  static const border = Color(0xFFDCE5EA);
  static const muted = Color(0xFF7A8C99);
  static const warning = Color(0xFF9C6A1F);
  static const warningLight = Color(0xFFFFF3D9);
  static const red = Color(0xFFB95050);
  static const redLight = Color(0xFFFBEAEA);
  static const redSoft = Color(0xFFB95050);
  static const tableText = Color(0xFF6F818E);
  static const tableHeader = Color(0xFF607480);
  static const callout = Color(0xFF425C6B);
}

/// Shared text styles — same family/sizes/weights as the HTML prototype.
abstract final class HesbaText {
  static const family = 'IBM Plex Sans Arabic';

  /// body — 14 / 400 / 1.55
  static const body = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.55,
    fontWeight: FontWeight.w400,
    color: HesbaColors.ink,
  );

  /// muted body / context bar — 13 / 400
  static const bodyMuted = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 1.55,
    fontWeight: FontWeight.w400,
    color: HesbaColors.muted,
  );

  /// page title — up to 38 / 400
  static const pageTitle = TextStyle(
    fontFamily: family,
    fontSize: 38,
    height: 1.25,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.5,
    color: HesbaColors.ink,
  );

  /// login title — 27
  static const loginTitle = TextStyle(
    fontFamily: family,
    fontSize: 27,
    height: 1.3,
    fontWeight: FontWeight.w400,
    color: HesbaColors.ink,
  );

  /// panel / section title — 18
  static const sectionTitle = TextStyle(
    fontFamily: family,
    fontSize: 18,
    height: 1.3,
    fontWeight: FontWeight.w400,
    color: HesbaColors.ink,
  );

  /// modal title — 23
  static const modalTitle = TextStyle(
    fontFamily: family,
    fontSize: 23,
    height: 1.3,
    fontWeight: FontWeight.w400,
    color: HesbaColors.ink,
  );

  /// sidebar brand — 35 / 400
  static const brand = TextStyle(
    fontFamily: family,
    fontSize: 35,
    height: 1.15,
    fontWeight: FontWeight.w400,
    color: Colors.white,
  );

  /// login brand — 34
  static const loginBrand = TextStyle(
    fontFamily: family,
    fontSize: 34,
    height: 1.2,
    fontWeight: FontWeight.w400,
    color: Colors.white,
  );

  /// brand subtitle — 12
  static const brandSub = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: Color(0x91FFFFFF),
  );

  /// nav item — 14 / 400 (600 when active)
  static const nav = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w400,
    color: Color(0x96FFFFFF),
  );

  static const navActive = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  /// context bar strong — 15 / 400
  static const contextStrong = TextStyle(
    fontFamily: family,
    fontSize: 15,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: HesbaColors.ink,
  );

  /// KPI label — 13 muted
  static const kpiLabel = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w400,
    color: HesbaColors.muted,
  );

  /// KPI value — 24 / 700
  static const kpiValue = TextStyle(
    fontFamily: family,
    fontSize: 24,
    height: 1.2,
    fontWeight: FontWeight.w700,
    color: HesbaColors.ink,
  );

  /// KPI note — 11 muted
  static const kpiNote = TextStyle(
    fontFamily: family,
    fontSize: 11,
    height: 1.35,
    fontWeight: FontWeight.w400,
    color: HesbaColors.muted,
  );

  /// table header — 12 / 600
  static const tableHeader = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: HesbaColors.tableHeader,
  );

  /// table cell — 12 / 400
  static const tableCell = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 1.35,
    fontWeight: FontWeight.w400,
    color: HesbaColors.tableText,
  );

  /// table emphasis / amounts — 12–13 / 600
  static const tableEmphasis = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: HesbaColors.ink,
  );

  /// badge — 11 / 400
  static const badge = TextStyle(
    fontFamily: family,
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w400,
  );

  /// field label — 14 / 600 (HTML `.field label`)
  static const fieldLabel = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: HesbaColors.ink,
  );

  /// help / footer note — 12 muted
  static const help = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 1.45,
    fontWeight: FontWeight.w400,
    color: HesbaColors.muted,
  );

  /// caption — 11 muted
  static const caption = TextStyle(
    fontFamily: family,
    fontSize: 11,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: HesbaColors.muted,
  );

  /// button — 14 / 500
  static const button = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w500,
  );

  /// callout body — 13
  static const callout = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 1.55,
    fontWeight: FontWeight.w400,
    color: HesbaColors.callout,
  );

  /// panel subtitle — 12 muted
  static const panelSub = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: HesbaColors.muted,
  );

  /// sidebar meta — 12 / 11 / 10
  static const sideMeta = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 1.4,
    fontWeight: FontWeight.w400,
    color: Color(0x99FFFFFF),
  );

  static const sideUser = TextStyle(
    fontFamily: family,
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static const sideTiny = TextStyle(
    fontFamily: family,
    fontSize: 10,
    height: 1.35,
    fontWeight: FontWeight.w400,
    color: Color(0x7AFFFFFF),
  );
}

ThemeData hesbaTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: HesbaColors.teal,
    primary: HesbaColors.teal,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: HesbaColors.soft,
    fontFamily: HesbaText.family,
    textTheme: const TextTheme(
      headlineLarge: HesbaText.pageTitle,
      headlineMedium: HesbaText.loginTitle,
      headlineSmall: HesbaText.modalTitle,
      titleLarge: HesbaText.sectionTitle,
      titleMedium: HesbaText.contextStrong,
      titleSmall: HesbaText.fieldLabel,
      bodyLarge: HesbaText.body,
      bodyMedium: HesbaText.bodyMuted,
      bodySmall: HesbaText.help,
      labelLarge: HesbaText.button,
      labelMedium: HesbaText.tableHeader,
      labelSmall: HesbaText.badge,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      labelStyle: HesbaText.fieldLabel,
      hintStyle: HesbaText.help,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: HesbaColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: HesbaColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(9),
        borderSide: const BorderSide(color: HesbaColors.teal),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: HesbaColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: HesbaColors.teal,
        foregroundColor: Colors.white,
        minimumSize: const Size(130, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        textStyle: HesbaText.button.copyWith(color: Colors.white),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: HesbaColors.ink,
        minimumSize: const Size(110, 46),
        side: const BorderSide(color: HesbaColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        textStyle: HesbaText.button,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(textStyle: HesbaText.button),
    ),
    dataTableTheme: const DataTableThemeData(
      headingTextStyle: HesbaText.tableHeader,
      dataTextStyle: HesbaText.tableCell,
    ),
  );
}

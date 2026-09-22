import 'package:flutter/material.dart';

class HesbaColors {
  static const navy = Color(0xFF102F3E);
  static const navyDark = Color(0xFF173D4D);
  static const ink = Color(0xFF1B3342);
  static const teal = Color(0xFF0B8C7E);
  static const tealDark = Color(0xFF08776B);
  static const tealLight = Color(0xFFE5F4F1);
  static const background = Color(0xFFEDF2F5);
  static const soft = Color(0xFFF6F8FA);
  static const border = Color(0xFFDCE5EA);
  static const muted = Color(0xFF7A8C99);
  static const warning = Color(0xFF9C6A1F);
  static const warningLight = Color(0xFFFFF3D9);
  static const red = Color(0xFFB95050);
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
    fontFamily: 'IBM Plex Sans Arabic',
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 38,
        height: 1.25,
        fontWeight: FontWeight.w700,
        color: HesbaColors.ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: HesbaColors.ink,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: HesbaColors.ink,
      ),
      bodyLarge: TextStyle(fontSize: 14, height: 1.55, color: HesbaColors.ink),
      bodyMedium: TextStyle(
        fontSize: 13,
        height: 1.55,
        color: HesbaColors.muted,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: HesbaColors.ink,
        minimumSize: const Size(110, 46),
        side: const BorderSide(color: HesbaColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
  );
}

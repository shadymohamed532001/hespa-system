import 'package:flutter/material.dart';

class HesbaColors {
  static const navy = Color(0xFF123445);
  static const navyDark = Color(0xFF0C2938);
  static const teal = Color(0xFF0D9284);
  static const tealLight = Color(0xFFE2F3F0);
  static const background = Color(0xFFF4F7F9);
  static const border = Color(0xFFD9E3E9);
  static const muted = Color(0xFF7E919F);
  static const warning = Color(0xFFF2B84B);
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
    scaffoldBackgroundColor: HesbaColors.background,
    fontFamily: 'Arial',
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: HesbaColors.navy,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: HesbaColors.navy,
      ),
      titleLarge: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        color: HesbaColors.navy,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: HesbaColors.navy),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.45,
        color: HesbaColors.muted,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: HesbaColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: HesbaColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: HesbaColors.teal, width: 1.5),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: HesbaColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: HesbaColors.teal,
        foregroundColor: Colors.white,
        minimumSize: const Size(130, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

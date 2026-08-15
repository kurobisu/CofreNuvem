import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF0F172A); // Slate 900
  static const Color accent = Color(0xFF10B981); // Emerald 500
  static const Color backgroundLight = Color(0xFFF8FAFC); // Slate 50
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Color(0xFF1E293B); // Slate 800
  static const Color textLight = Color(0xFF0F172A);
  static const Color textDark = Color(0xFFF8FAFC);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: accent,
        surface: surfaceLight,
        background: backgroundLight,
        onBackground: textLight,
        onSurface: textLight,
      ),
      scaffoldBackgroundColor: backgroundLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textLight),
        titleTextStyle: TextStyle(color: textLight, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
      ),
      textTheme: TextTheme(
        headlineMedium: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: textLight),
        titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textLight),
        bodyLarge: const TextStyle(fontSize: 16, color: textLight),
        bodyMedium: TextStyle(fontSize: 14, color: Colors.grey.shade700),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accent,
        surface: surfaceDark,
        background: backgroundDark,
        onBackground: textDark,
        onSurface: textDark,
      ),
      scaffoldBackgroundColor: backgroundDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textDark),
        titleTextStyle: TextStyle(color: textDark, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
      ),
      textTheme: TextTheme(
        headlineMedium: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: textDark),
        titleLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textDark),
        bodyLarge: const TextStyle(fontSize: 16, color: textDark),
        bodyMedium: TextStyle(fontSize: 14, color: Colors.grey.shade400),
      ),
    );
  }
}

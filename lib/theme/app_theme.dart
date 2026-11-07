import 'package:flutter/material.dart';

class AppTheme {
  // Obsidian Ink Dark Theme (Matching LedgerLens Web Theme)
  static const Color background = Color(0xFF0B0D0C);
  static const Color surface = Color(0xFF131514);
  static const Color surfaceSubtle = Color(0xFF171A18);
  static const Color border = Color(0xFF1E2220);
  static const Color primary = Color(0xFF10B981); // Emerald Green
  static const Color primaryDark = Color(0xFF065F46);
  static const Color textPrimary = Color(0xFFF3F4F3);
  static const Color textMuted = Color(0xFF8A8F8C);
  static const Color textFaint = Color(0xFF717673);
  static const Color expense = Color(0xFFF87171); // Rose
  static const Color income = Color(0xFF34D399); // Emerald
  static const Color warning = Color(0xFFF59E0B); // Amber

  // Category Colors
  static const Color catFood = Color(0xFFF97316);
  static const Color catShopping = Color(0xFFA855F7);
  static const Color catInvestments = Color(0xFF10B981);
  static const Color catTransport = Color(0xFF84CC16);
  static const Color catBills = Color(0xFFEAB308);
  static const Color catEntertainment = Color(0xFFEC4899);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: primary,
        surface: surface,
        error: expense,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: background,
        selectedItemColor: primary,
        unselectedItemColor: textFaint,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
      ),
    );
  }
}


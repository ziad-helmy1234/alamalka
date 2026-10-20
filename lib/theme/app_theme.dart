import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryDark = Color(0xFF0F172A); // Rich Slate Navy
  static const Color cardDark = Color(0xFF1E293B);
  static const Color backgroundDark = Color(0xFF090D16);
  
  static const Color accentBlue = Color(0xFF2563EB); // Electric Indigo
  static const Color greenPositive = Color(0xFF10B981); // Emerald Green
  static const Color redNegative = Color(0xFFEF4444); // Crimson Red
  static const Color goldSharia = Color(0xFFF59E0B); // Amber Gold for Sharia
  
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color borderDark = Color(0xFF334155);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      primaryColor: AppColors.accentBlue,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentBlue,
        surface: AppColors.cardDark,
        background: AppColors.backgroundDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.primaryDark,
        selectedItemColor: AppColors.accentBlue,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 12,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderDark, width: 0.5),
        ),
      ),
    );
  }
}

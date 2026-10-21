import 'package:flutter/material.dart';

class AppColors {
  // Dark Colors
  static const Color primaryDark = Color(0xFF0F172A);
  static const Color cardDark = Color(0xFF1E293B);
  static const Color backgroundDark = Color(0xFF090D16);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color borderDark = Color(0xFF334155);

  // Light Colors
  static const Color primaryLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color backgroundLight = Color(0xFFF1F5F9);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color borderLight = Color(0xFFCBD5E1);

  // Const Fallbacks for compile-time constants
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);

  static Color get cardBg => AppTheme.isDarkMode ? cardDark : cardLight;
  static Color get primaryContainer =>
      AppTheme.isDarkMode ? primaryDark : const Color(0xFFE2E8F0);
  static Color get border => AppTheme.isDarkMode ? borderDark : borderLight;

  // Accent & Trading Indicators
  static const Color accentBlue = Color(0xFF2563EB); // Electric Indigo
  static const Color greenPositive = Color(0xFF10B981); // Emerald Green
  static const Color redNegative = Color(0xFFEF4444); // Crimson Red
  static const Color goldSharia = Color(0xFFD97706); // Amber Gold
}

class AppTheme {
  static final ValueNotifier<ThemeMode> themeNotifier =
      ValueNotifier(ThemeMode.dark);

  static void toggleTheme() {
    themeNotifier.value = themeNotifier.value == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  static bool get isDarkMode => themeNotifier.value == ThemeMode.dark;

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      primaryColor: AppColors.accentBlue,
      cardColor: AppColors.cardDark,
      dividerColor: AppColors.borderDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accentBlue,
        surface: AppColors.cardDark,
        onSurface: AppColors.textPrimaryDark,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: AppColors.accentBlue.withOpacity(0.15),
        iconColor: AppColors.accentBlue,
        textColor: AppColors.textPrimaryDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimaryDark),
        actionsIconTheme: IconThemeData(color: AppColors.accentBlue),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimaryDark,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.primaryDark,
        selectedItemColor: AppColors.accentBlue,
        unselectedItemColor: AppColors.textSecondaryDark,
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

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      primaryColor: AppColors.accentBlue,
      cardColor: AppColors.cardLight,
      dividerColor: AppColors.borderLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.accentBlue,
        surface: AppColors.cardLight,
        onSurface: AppColors.textPrimaryLight,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: AppColors.accentBlue.withOpacity(0.15),
        iconColor: AppColors.accentBlue,
        textColor: AppColors.textPrimaryLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryLight,
        elevation: 1,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimaryLight),
        actionsIconTheme: IconThemeData(color: AppColors.accentBlue),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimaryLight,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.primaryLight,
        selectedItemColor: AppColors.accentBlue,
        unselectedItemColor: AppColors.textSecondaryLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardLight,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderLight, width: 1.0),
        ),
      ),
    );
  }
}

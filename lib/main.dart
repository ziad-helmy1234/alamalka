import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'views/main_navigation_screen.dart';

void main() {
  runApp(const StockTradingApp());
}

class StockTradingApp extends StatelessWidget {
  const StockTradingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'منصة التداول المتقدمة - Stock Trading App',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          home: const Directionality(
            textDirection: TextDirection.rtl, // RTL layout for Arabic
            child: MainNavigationScreen(),
          ),
        );
      },
    );
  }
}

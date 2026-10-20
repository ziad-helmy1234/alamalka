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
    return MaterialApp(
      title: 'منصة التداول المتقدمة - Stock Trading App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const Directionality(
        textDirection: TextDirection.rtl, // RTL layout for Arabic
        child: MainNavigationScreen(),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'theme/app_language.dart';
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
        return ValueListenableBuilder<Locale>(
          valueListenable: AppLanguage.localeNotifier,
          builder: (context, currentLocale, _) {
            final isRtl = currentLocale.languageCode == 'ar';
            return MaterialApp(
              title: 'منصة التداول المتقدمة - Stock Trading App',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: currentMode,
              locale: currentLocale,
              home: Directionality(
                textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
                child: const MainNavigationScreen(),
              ),
            );
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_language.dart';
import 'markets_screen.dart';
import 'watchlist_screen.dart';
import 'ipo_ripple_screen.dart';
import 'portfolio_screen.dart';
import 'orders_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    MarketsScreen(),
    WatchlistScreen(),
    IPORippleScreen(),
    PortfolioScreen(),
    OrdersScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: ValueListenableBuilder<Locale>(
        valueListenable: AppLanguage.localeNotifier,
        builder: (context, _, __) {
          return BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
            unselectedLabelStyle: const TextStyle(fontSize: 9),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.candlestick_chart_outlined),
                activeIcon: const Icon(Icons.candlestick_chart),
                label: AppStrings.marketsTab,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.bookmark_border),
                activeIcon: const Icon(Icons.bookmark),
                label: AppStrings.watchlistTab,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.auto_awesome_outlined),
                activeIcon: const Icon(Icons.auto_awesome, color: AppColors.goldSharia),
                label: AppStrings.iposTab,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.account_balance_wallet_outlined),
                activeIcon: const Icon(Icons.account_balance_wallet),
                label: AppStrings.portfolioTab,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.assignment_outlined),
                activeIcon: const Icon(Icons.assignment),
                label: AppStrings.ordersTab,
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person_outline),
                activeIcon: const Icon(Icons.person),
                label: AppStrings.accountTab,
              ),
            ],
          );
        },
      ),
    );
  }
}

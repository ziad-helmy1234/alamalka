import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../services/stock_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_language.dart';
import 'stock_detail_screen.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  final StockService _stockService = StockService();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: AppLanguage.localeNotifier,
      builder: (context, locale, _) {
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Icon(Icons.bookmark_outline, color: AppColors.accentBlue),
                const SizedBox(width: 8),
                Text(AppStrings.watchlistTab),
              ],
            ),
          ),
          body: StreamBuilder<List<Stock>>(
            stream: _stockService.stocksStream,
            initialData: _stockService.allStocks,
            builder: (context, snapshot) {
              final watchlistedStocks =
                  snapshot.data?.where((s) => s.isWatchlisted).toList() ?? [];

              if (watchlistedStocks.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.bookmark_border, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        AppStrings.emptyWatchlistTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          AppStrings.emptyWatchlistDesc,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                itemCount: watchlistedStocks.length,
                separatorBuilder: (_, __) =>
                    Divider(color: Theme.of(context).dividerColor, height: 1),
                itemBuilder: (context, index) {
                  final stock = watchlistedStocks[index];
                  final color = stock.isPositive
                      ? AppColors.greenPositive
                      : AppColors.redNegative;
                  final sign = stock.isPositive ? '+' : '';

                  return ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StockDetailScreen(stock: stock),
                        ),
                      );
                    },
                    title: Row(
                      children: [
                        Text(stock.symbol,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        if (stock.isShariaCompliant)
                          const Icon(Icons.star,
                              size: 14, color: AppColors.goldSharia),
                        const Spacer(),
                        Text(
                          '${stock.currentPrice.toStringAsFixed(2)} ${stock.currency}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    subtitle: Row(
                      children: [
                        Expanded(
                          child: Text(
                            AppLanguage.isArabic ? stock.nameAr : stock.name,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '$sign${stock.percentChange.toStringAsFixed(2)}%',
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.bookmark_remove,
                          color: AppColors.redNegative),
                      tooltip: AppLanguage.isArabic ? 'إزالة من القائمة' : 'Remove',
                      onPressed: () {
                        setState(() {
                          _stockService.toggleWatchlist(stock.symbol);
                        });
                      },
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

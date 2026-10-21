import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../services/stock_service.dart';
import '../theme/app_theme.dart';
import 'stock_detail_screen.dart';
import 'news_events_screen.dart';
import 'search_screen.dart';

class MarketsScreen extends StatefulWidget {
  const MarketsScreen({super.key});

  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  final StockService _stockService = StockService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.candlestick_chart, color: AppColors.accentBlue),
            SizedBox(width: 8),
            Text('الأسواق والاستكشاف'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.accentBlue),
            tooltip: 'البحث والتصنيفات',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.newspaper, color: AppColors.accentBlue),
            tooltip: 'الأخبار والأحداث',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NewsEventsScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Stock>>(
        stream: _stockService.stocksStream,
        initialData: _stockService.allStocks,
        builder: (context, snapshot) {
          final allStocks = snapshot.data ?? _stockService.allStocks;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              // 1. Index Banner (EGX 30 / EGX 70 / EGX 100 EWI / EGX 35-LV)
              _buildMarketIndicesBanner(context),

              // 2. Biggest Winners Section
              _buildTopGainersRow(),
              const SizedBox(height: 12),

              // 3. Biggest Losers Section
              _buildTopLosersRow(),
              const SizedBox(height: 16),

              // 4. All Listed Stocks Header
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  'جميع الأسهم المقيدة',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              Divider(color: Theme.of(context).dividerColor, height: 1),

              // 5. Stock List Tiles
              ...allStocks.map((stock) => Column(
                    children: [
                      _buildStockTile(stock),
                      Divider(color: Theme.of(context).dividerColor, height: 1),
                    ],
                  )),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMarketIndicesBanner(BuildContext context) {
    final indices = [
      {'name': 'EGX 30', 'value': '30,450.20', 'change': '+1.25%', 'isPositive': true},
      {'name': 'EGX 70 EWI', 'value': '7,210.80', 'change': '-0.40%', 'isPositive': false},
      {'name': 'EGX 100 EWI', 'value': '10,380.50', 'change': '+0.85%', 'isPositive': true},
      {'name': 'EGX 35-LV', 'value': '3,120.40', 'change': '+0.32%', 'isPositive': true},
    ];

    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: indices.asMap().entries.map((entry) {
            final idx = entry.value;
            final isLast = entry.key == indices.length - 1;
            return Row(
              children: [
                _buildIndexItem(
                  context,
                  idx['name'] as String,
                  idx['value'] as String,
                  idx['change'] as String,
                  idx['isPositive'] as bool,
                ),
                if (!isLast)
                  Container(
                    width: 1,
                    height: 28,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    color: Theme.of(context).dividerColor,
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildIndexItem(BuildContext context, String name, String value, String change, bool isPositive) {
    final color = isPositive ? AppColors.greenPositive : AppColors.redNegative;

    return Column(
      children: [
        Text(name, style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 2),
        Row(
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 6),
            Text(change, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  // Section 1: Biggest Winners (Top Gainers)
  Widget _buildTopGainersRow() {
    final gainers = _stockService.getTopGainers(limit: 5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.trending_up, color: AppColors.greenPositive, size: 20),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'أعلى الأسهم ارتفاعاً (Biggest Winners)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.greenPositive,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  );
                },
                child: const Text(
                  'عرض الكل',
                  style: TextStyle(color: AppColors.accentBlue, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: gainers
                .map((stock) => _buildHighlightCard(stock, isGainer: true))
                .toList(),
          ),
        ),
      ],
    );
  }

  // Section 2: Biggest Losers (Top Losers)
  Widget _buildTopLosersRow() {
    final losers = _stockService.getTopLosers(limit: 5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.trending_down, color: AppColors.redNegative, size: 20),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'أكثر الأسهم انخفاضاً (Biggest Losers)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.redNegative,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  );
                },
                child: const Text(
                  'عرض الكل',
                  style: TextStyle(color: AppColors.accentBlue, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: losers
                .map((stock) => _buildHighlightCard(stock, isGainer: false))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildHighlightCard(Stock stock, {required bool isGainer}) {
    final color = isGainer ? AppColors.greenPositive : AppColors.redNegative;
    final sign = stock.isPositive ? '+' : '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StockDetailScreen(stock: stock),
          ),
        );
      },
      child: Container(
        width: 145,
        height: 105,
        margin: const EdgeInsets.only(left: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  stock.symbol,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$sign${stock.percentChange.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              stock.nameAr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
              ),
            ),
            Text(
              '${stock.currentPrice.toStringAsFixed(2)} ${stock.currency}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockTile(Stock stock) {
    final color = stock.isPositive ? AppColors.greenPositive : AppColors.redNegative;
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Row(
        children: [
          Text(stock.symbol, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          if (stock.isShariaCompliant)
            const Icon(Icons.star, size: 14, color: AppColors.goldSharia),
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
              stock.nameAr,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '$sign${stock.percentChange.toStringAsFixed(2)}%',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(
          stock.isWatchlisted ? Icons.bookmark : Icons.bookmark_border,
          color: stock.isWatchlisted ? AppColors.goldSharia : AppColors.accentBlue,
        ),
        onPressed: () {
          setState(() {
            _stockService.toggleWatchlist(stock.symbol);
          });
        },
      ),
    );
  }
}

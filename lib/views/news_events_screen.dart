import 'package:flutter/material.dart';
import '../models/news_event.dart';
import '../services/stock_service.dart';
import '../theme/app_theme.dart';
import 'stock_detail_screen.dart';

class NewsEventsScreen extends StatefulWidget {
  const NewsEventsScreen({super.key});

  @override
  State<NewsEventsScreen> createState() => _NewsEventsScreenState();
}

class _NewsEventsScreenState extends State<NewsEventsScreen>
    with SingleTickerProviderStateMixin {
  final StockService _stockService = StockService();
  late TabController _tabController;
  String _selectedCategory = 'الكل';

  final List<String> _categories = [
    'الكل',
    'نتائج أعمال',
    'اقتصاد كلي',
    'توسع واستثمار',
    'عقود وترسيات',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.newspaper, color: AppColors.accentBlue),
            SizedBox(width: 8),
            Text('الأخبار والأحداث الاقتصادية'),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentBlue,
          labelColor: AppColors.accentBlue,
          tabs: const [
            Tab(text: 'أخبار السوق اللحظية'),
            Tab(text: 'الأجندة الاقتصادية'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMarketNewsTab(),
          _buildEconomicCalendarTab(),
        ],
      ),
    );
  }

  Widget _buildMarketNewsTab() {
    final allNews = _stockService.getMarketNews();
    final newsList = _selectedCategory == 'الكل'
        ? allNews
        : allNews.where((n) => n.categoryAr == _selectedCategory).toList();

    return Column(
      children: [
        // Category Filters
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _selectedCategory = cat;
                      });
                    }
                  },
                ),
              );
            },
          ),
        ),
        Divider(color: Theme.of(context).dividerColor, height: 1),

        // News List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: newsList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = newsList[index];
              return _buildNewsCard(item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNewsCard(NewsItem item) {
    final stock = item.relatedSymbol != null
        ? _stockService.allStocks.firstWhere(
            (s) => s.symbol == item.relatedSymbol,
            orElse: () => _stockService.allStocks.first,
          )
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (item.isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          color: AppColors.redNegative,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'عاجل',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accentBlue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: AppColors.accentBlue, width: 0.6),
                      ),
                      child: Text(
                        item.categoryAr,
                        style: const TextStyle(
                            color: AppColors.accentBlue,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Text(
                  _formatTimeAgo(item.timestamp),
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.titleAr,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.summaryAr,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
              ),
            ),
            Divider(color: Theme.of(context).dividerColor, height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المصدر: ${item.source}',
                  style: TextStyle(fontSize: 11),
                ),
                if (stock != null)
                  ActionChip(
                    avatar: const Icon(Icons.show_chart,
                        size: 14, color: AppColors.accentBlue),
                    label: Text('\$${stock.symbol}'),
                    backgroundColor: Theme.of(context).cardColor,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StockDetailScreen(stock: stock),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEconomicCalendarTab() {
    final events = _stockService.getEconomicEvents();

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final evt = events[index];
        final stock = evt.relatedSymbol != null
            ? _stockService.allStocks.firstWhere(
                (s) => s.symbol == evt.relatedSymbol,
                orElse: () => _stockService.allStocks.first,
              )
            : null;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Column
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${evt.date.day}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentBlue,
                        ),
                      ),
                      Text(
                        _getMonthName(evt.date.month),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.goldSharia.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              evt.eventTypeAr,
                              style: const TextStyle(
                                color: AppColors.goldSharia,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          if (stock != null)
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => StockDetailScreen(stock: stock),
                                  ),
                                );
                              },
                              child: Text(
                                '\$${stock.symbol}',
                                style: const TextStyle(
                                  color: AppColors.accentBlue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        evt.titleAr,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        evt.detailsAr,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return 'منذ ${diff.inMinutes} دقيقة';
    } else if (diff.inHours < 24) {
      return 'منذ ${diff.inHours} ساعة';
    } else {
      return 'منذ ${diff.inDays} يوم';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر'
    ];
    return months[month - 1];
  }
}

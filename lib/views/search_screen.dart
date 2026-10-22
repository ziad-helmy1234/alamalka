import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../services/stock_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_language.dart';
import 'stock_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final StockService _stockService = StockService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _selectedCategory = 'الكل';
  bool _onlySharia = false;

  final List<String> _categoriesAr = [
    'الكل',
    'الأعلى ارتفاعاً',
    'الأكثر انخفاضاً',
    'بنوك وخدمات مالية',
    'عقارات',
    'صناعة وطاقة',
    'تكنولوجيا الاتصالات',
    'سلع استهلاكية',
    'كيماويات وأسمدة',
  ];

  final List<String> _categoriesEn = [
    'All',
    'Top Gainers',
    'Top Losers',
    'Banks & Financials',
    'Real Estate',
    'Industrials & Energy',
    'Telecom & Tech',
    'Consumer Goods',
    'Chemicals & Fertilizers',
  ];

  Widget? _buildClearButton() {
    if (_searchQuery.isEmpty) return null;
    return IconButton(
      icon: const Icon(Icons.clear, size: 18),
      onPressed: () {
        _searchController.clear();
        setState(() {
          _searchQuery = '';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = AppLanguage.isArabic ? _categoriesAr : _categoriesEn;
    if (!categories.contains(_selectedCategory)) {
      _selectedCategory = categories.first;
    }

    return ValueListenableBuilder<Locale>(
      valueListenable: AppLanguage.localeNotifier,
      builder: (context, locale, _) {
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: AppStrings.searchHint,
                  border: InputBorder.none,
                  hintStyle: const TextStyle(fontSize: 14),
                  suffixIcon: _buildClearButton(),
                ),
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ),
          body: Column(
            children: [
              // Filter Chips Container
              Container(
                color: Theme.of(context).cardColor,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    // Sharia Toggle Chip Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          FilterChip(
                            avatar: const Icon(Icons.star, color: AppColors.goldSharia, size: 16),
                            label: Text(AppStrings.shariaFilter),
                            selected: _onlySharia,
                            selectedColor: AppColors.goldSharia.withOpacity(0.2),
                            onSelected: (val) {
                              setState(() {
                                _onlySharia = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Sector Categories Horizontal Scroll
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: categories.map((cat) {
                          final isSelected = _selectedCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: ChoiceChip(
                              label: Text(cat),
                              selected: isSelected,
                              selectedColor: (cat.contains('ارتفاعاً') || cat.contains('Gainers'))
                                  ? AppColors.greenPositive.withOpacity(0.3)
                                  : ((cat.contains('انخفاضاً') || cat.contains('Losers'))
                                      ? AppColors.redNegative.withOpacity(0.3)
                                      : AppColors.accentBlue.withOpacity(0.3)),
                              onSelected: (val) {
                                if (val) {
                                  setState(() {
                                    _selectedCategory = cat;
                                  });
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: Theme.of(context).dividerColor, height: 1),

              // Live Filtered Search Results
              Expanded(
                child: StreamBuilder<List<Stock>>(
                  stream: _stockService.stocksStream,
                  initialData: _stockService.allStocks,
                  builder: (context, snapshot) {
                    List<Stock> filteredStocks = [];

                    if (_selectedCategory == 'الأعلى ارتفاعاً' || _selectedCategory == 'Top Gainers') {
                      filteredStocks = _stockService.getTopGainers(limit: 10);
                    } else if (_selectedCategory == 'الأكثر انخفاضاً' || _selectedCategory == 'Top Losers') {
                      filteredStocks = _stockService.getTopLosers(limit: 10);
                    } else {
                      filteredStocks = _stockService.searchStocks(
                        query: _searchQuery,
                        selectedSectorAr: _selectedCategory,
                        onlySharia: _onlySharia,
                      );
                    }

                    if (filteredStocks.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Center(
                          child: Text(
                            AppStrings.noSearchResults,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filteredStocks.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: Theme.of(context).dividerColor, height: 1),
                      itemBuilder: (context, index) {
                        final stock = filteredStocks[index];
                        return _buildSearchResultTile(stock);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchResultTile(Stock stock) {
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
          Text(
            stock.symbol,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          if (stock.isShariaCompliant) ...[
            const SizedBox(width: 6),
            const Icon(Icons.star, size: 14, color: AppColors.goldSharia),
          ],
          const Spacer(),
          Text(
            '${stock.currentPrice.toStringAsFixed(2)} ${stock.currency}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              AppLanguage.isArabic ? stock.nameAr : stock.name,
              style: const TextStyle(
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$sign${stock.percentChange.toStringAsFixed(2)}%',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(
          stock.isWatchlisted ? Icons.bookmark : Icons.bookmark_border,
          color: stock.isWatchlisted ? AppColors.goldSharia : AppColors.accentBlue,
          size: 20,
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

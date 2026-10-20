import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../models/order.dart';
import '../services/stock_service.dart';
import '../theme/app_theme.dart';
import 'order_modal.dart';

class StockDetailScreen extends StatefulWidget {
  final Stock stock;

  const StockDetailScreen({super.key, required this.stock});

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  final StockService _stockService = StockService();
  String _selectedTimeframe = '1M';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Stock>>(
      stream: _stockService.stocksStream,
      initialData: _stockService.allStocks,
      builder: (context, snapshot) {
        final currentStock = snapshot.data?.firstWhere(
              (s) => s.symbol == widget.stock.symbol,
              orElse: () => widget.stock,
            ) ??
            widget.stock;

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      currentStock.symbol,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    if (currentStock.isShariaCompliant)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.goldSharia.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppColors.goldSharia, width: 0.8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.star,
                                size: 10, color: AppColors.goldSharia),
                            SizedBox(width: 2),
                            Text(
                              'متوافق مع الشريعة',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.goldSharia,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                Text(
                  currentStock.nameAr,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(
                  currentStock.isWatchlisted
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  color: currentStock.isWatchlisted
                      ? AppColors.goldSharia
                      : AppColors.textSecondary,
                ),
                tooltip: currentStock.isWatchlisted
                    ? 'إزالة من قائمة المراقبة'
                    : 'إضافة لقائمة المراقبة',
                onPressed: () {
                  setState(() {
                    _stockService.toggleWatchlist(currentStock.symbol);
                  });
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Price Overview Card
                _buildPriceCard(currentStock),
                const SizedBox(height: 20),

                // Interactive TradingView-Style Chart
                _buildChartSection(currentStock),
                const SizedBox(height: 20),

                // Market Depth & Key Statistics
                _buildKeyStatsSection(currentStock),
              ],
            ),
          ),
          bottomNavigationBar: _buildActionBottomBar(context, currentStock),
        );
      },
    );
  }

  Widget _buildPriceCard(Stock stock) {
    final color =
        stock.isPositive ? AppColors.greenPositive : AppColors.redNegative;
    final sign = stock.isPositive ? '+' : '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${stock.currentPrice.toStringAsFixed(2)} ${stock.currency}',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        stock.isPositive
                            ? Icons.trending_up
                            : Icons.trending_down,
                        color: color,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$sign${stock.change.toStringAsFixed(2)} ($sign${stock.percentChange.toStringAsFixed(2)}%)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.borderDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                stock.sectorAr,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(Stock stock) {
    final history = _getFilteredHistory(stock, _selectedTimeframe);
    final isChartPositive = history.length >= 2
        ? (history.last.price >= history.first.price)
        : stock.isPositive;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.show_chart, color: AppColors.accentBlue, size: 20),
                    SizedBox(width: 6),
                    Text(
                      'الرسم البياني التفاعلي',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary),
                    ),
                  ],
                ),
                Text(
                  _getTimeframeLabel(_selectedTimeframe),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Custom High-Performance Chart Painter
            SizedBox(
              height: 200,
              width: double.infinity,
              child: CustomPaint(
                painter: StockChartPainter(
                  history: history,
                  isPositive: isChartPositive,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Timeframe Toggles: 1D, 1W, 1M, 1Y, 5Y
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['1D', '1W', '1M', '1Y', '5Y'].map((tf) {
                final isSelected = _selectedTimeframe == tf;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTimeframe = tf;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accentBlue
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accentBlue
                            : AppColors.borderDark,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      tf,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeframeLabel(String tf) {
    switch (tf) {
      case '1D':
        return 'يوم واحد (1 Day)';
      case '1W':
        return 'أسبوع (1 Week)';
      case '1M':
        return 'شهر واحد (1 Month)';
      case '1Y':
        return 'سنة (1 Year)';
      case '5Y':
        return '5 سنوات (5 Years)';
      default:
        return '';
    }
  }

  List<PricePoint> _getFilteredHistory(Stock stock, String timeframe) {
    final basePrice = stock.currentPrice;
    final now = DateTime.now();
    List<PricePoint> points = [];

    int count = 20;
    double volatility = 0.01;
    double trendFactor = 0.0;
    Duration step = const Duration(hours: 1);

    switch (timeframe) {
      case '1D':
        count = 24;
        volatility = 0.003;
        step = const Duration(minutes: 20);
        trendFactor = (stock.isPositive ? 0.002 : -0.002);
        break;
      case '1W':
        count = 14;
        volatility = 0.008;
        step = const Duration(hours: 12);
        trendFactor = (stock.isPositive ? 0.004 : -0.004);
        break;
      case '1M':
        return stock.history; // Default 30-day history
      case '1Y':
        count = 30;
        volatility = 0.02;
        step = const Duration(days: 12);
        trendFactor = (stock.isPositive ? 0.012 : -0.012);
        break;
      case '5Y':
        count = 40;
        volatility = 0.035;
        step = const Duration(days: 45);
        trendFactor = (stock.isPositive ? 0.025 : -0.025);
        break;
      default:
        return stock.history;
    }

    double current = basePrice * (1.0 - (trendFactor * count * 0.5));
    for (int i = count; i >= 0; i--) {
      final time = now.subtract(step * i);
      final seed = (stock.symbol.hashCode + i * 37 + timeframe.hashCode) % 1000 / 1000.0;
      final noise = (seed - 0.48) * (basePrice * volatility);
      current = (current + noise + (basePrice * trendFactor * 0.3)).clamp(basePrice * 0.3, basePrice * 3.0);
      points.add(PricePoint(time: time, price: double.parse(current.toStringAsFixed(2))));
    }

    if (points.isNotEmpty) {
      points[points.length - 1] = PricePoint(time: now, price: stock.currentPrice);
    }

    return points;
  }

  Widget _buildKeyStatsSection(Stock stock) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'بيانات السوق والسيولة',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textPrimary),
            ),
            const Divider(color: AppColors.borderDark, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem('أعلى سعر اليوم',
                    '${stock.dayHigh.toStringAsFixed(2)} ${stock.currency}'),
                _buildStatItem('أدنى سعر اليوم',
                    '${stock.dayLow.toStringAsFixed(2)} ${stock.currency}'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatItem('الإغلاق السابق',
                    '${stock.previousClose.toStringAsFixed(2)} ${stock.currency}'),
                _buildStatItem('حجم التداول اليوم',
                    '${(stock.volume / 1000).toStringAsFixed(1)} ألف سهم'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
      ],
    );
  }

  Widget _buildActionBottomBar(BuildContext context, Stock stock) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.primaryDark,
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.greenPositive,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                _showOrderBottomSheet(context, stock, OrderSide.buy);
              },
              child: const Text('شراء',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.redNegative,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                _showOrderBottomSheet(context, stock, OrderSide.sell);
              },
              child: const Text('بيع',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderBottomSheet(
      BuildContext context, Stock stock, OrderSide side) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => OrderModal(stock: stock, initialSide: side),
    );
  }
}

// Chart Custom Painter for Smooth Zero-Latency Stock Graph
class StockChartPainter extends CustomPainter {
  final List<PricePoint> history;
  final bool isPositive;

  StockChartPainter({
    required this.history,
    required this.isPositive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    final prices = history.map((p) => p.price).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final range = (maxPrice - minPrice) == 0 ? 1.0 : (maxPrice - minPrice);

    final color = isPositive ? AppColors.greenPositive : AppColors.redNegative;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    final points = <Offset>[];

    for (int i = 0; i < history.length; i++) {
      final x = (i / (history.length - 1)) * size.width;
      final normalizedY = (history[i].price - minPrice) / range;
      final y = size.height - (normalizedY * (size.height - 20)) - 10;
      points.add(Offset(x, y));

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Gradient Fill
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant StockChartPainter oldDelegate) => true;
}

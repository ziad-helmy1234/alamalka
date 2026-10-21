import 'package:flutter/material.dart';
import '../models/portfolio.dart';
import '../models/stock.dart';
import '../services/stock_service.dart';
import '../theme/app_theme.dart';
import 'add_funds_modal.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen>
    with SingleTickerProviderStateMixin {
  final StockService _stockService = StockService();
  late TabController _tabController;
  String _selectedTimeframe = '1M';

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
    final summary = _stockService.getPortfolioSummary();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet, color: AppColors.accentBlue),
            SizedBox(width: 8),
            Text('المحفظة الاستثمارية والأرباح'),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentBlue,
          labelColor: AppColors.accentBlue,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'محفظة الجنيه المصري (EGP)'),
            Tab(text: 'محفظة الدولار (USD)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCurrencyPortfolioView(
            currency: 'EGP',
            cashBalance: summary.egpCashBalance,
            buyingPower: summary.egpBuyingPower,
            holdingsValue: summary.egpHoldingsValue,
            totalValue: summary.egpTotalValue,
            holdings: summary.egpHoldings,
          ),
          _buildCurrencyPortfolioView(
            currency: 'USD',
            cashBalance: summary.usdCashBalance,
            buyingPower: summary.usdBuyingPower,
            holdingsValue: summary.usdHoldingsValue,
            totalValue: summary.usdTotalValue,
            holdings: summary.usdHoldings,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyPortfolioView({
    required String currency,
    required double cashBalance,
    required double buyingPower,
    required double holdingsValue,
    required double totalValue,
    required List<PortfolioHolding> holdings,
  }) {
    final totalGainLoss =
        holdings.fold(0.0, (sum, h) => sum + h.totalGainLoss);
    final totalInvested =
        holdings.fold(0.0, (sum, h) => sum + h.totalInvested);
    final percentageGainLoss =
        totalInvested == 0 ? 0.0 : (totalGainLoss / totalInvested) * 100;
    final isPositive = totalGainLoss >= 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Valuation Card
          Card(
            color: Theme.of(context).cardColor,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'إجمالي قيمة المحفظة',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accentBlue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.accentBlue, width: 0.8),
                        ),
                        child: Text(
                          'مفصولة بـ $currency',
                          style: const TextStyle(
                              color: AppColors.accentBlue,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${totalValue.toStringAsFixed(2)} $currency',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Divider(color: AppColors.borderDark, height: 24),

                  // Buying Power & Cash Balance
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _buildBalanceItem('القوة الشرائية (Buying Power)',
                            '${buyingPower.toStringAsFixed(2)} $currency'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildBalanceItem('الرصيد النقدي المتاح',
                            '${cashBalance.toStringAsFixed(2)} $currency'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.greenPositive,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.add, color: Colors.white, size: 18),
                      label: Text(
                        'إضافة أموال / إيداع ($currency)',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: AppColors.cardDark,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(24)),
                          ),
                          builder: (_) =>
                              AddFundsModal(initialCurrency: currency),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Portfolio Profit & Loss Performance Graph Card
          _buildPortfolioPerformanceChartCard(
            currency: currency,
            totalGainLoss: totalGainLoss,
            percentageGainLoss: percentageGainLoss,
            isPositive: isPositive,
            totalValue: totalValue,
            holdings: holdings,
          ),
          const SizedBox(height: 20),

          // Holdings Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'الأسهم المملوكة ($currency)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'الإجمالي: ${holdingsValue.toStringAsFixed(2)} $currency',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Holdings List
          if (holdings.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(
                  child: Text(
                    'لا توجد أسهم مملوكة حالياً بهذه العملة ($currency)',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: holdings.length,
              itemBuilder: (context, index) {
                final holding = holdings[index];
                final isHoldingPositive = holding.totalGainLoss >= 0;
                final color = isHoldingPositive
                    ? AppColors.greenPositive
                    : AppColors.redNegative;
                final sign = isHoldingPositive ? '+' : '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                holding.symbol,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${holding.currentValue.toStringAsFixed(2)} $currency',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                holding.stockNameAr,
                                style: const TextStyle(
                                    color: AppColors.textSecondary, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$sign${holding.totalGainLoss.toStringAsFixed(2)} ($sign${holding.percentageGainLoss.toStringAsFixed(2)}%)',
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: AppColors.borderDark, height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('الكمية: ${holding.quantity} سهم',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)),
                            Text(
                                'متوسط الشراء: ${holding.averageBuyPrice.toStringAsFixed(2)} $currency',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPortfolioPerformanceChartCard({
    required String currency,
    required double totalGainLoss,
    required double percentageGainLoss,
    required bool isPositive,
    required double totalValue,
    required List<PortfolioHolding> holdings,
  }) {
    final color = isPositive ? AppColors.greenPositive : AppColors.redNegative;
    final sign = isPositive ? '+' : '';
    final points = _generatePortfolioValuationPoints(totalValue, isPositive);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        isPositive ? Icons.trending_up : Icons.trending_down,
                        color: color,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'أداء المحفظة والأرباح',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$sign${totalGainLoss.toStringAsFixed(2)} $currency ($sign${percentageGainLoss.toStringAsFixed(2)}%)',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Performance Line Chart
            SizedBox(
              height: 160,
              width: double.infinity,
              child: CustomPaint(
                painter: PortfolioChartPainter(
                  history: points,
                  isPositive: isPositive,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Timeframe Toggles
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['1W', '1M', '3M', '1Y', 'ALL'].map((tf) {
                final isSelected = _selectedTimeframe == tf;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTimeframe = tf;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accentBlue
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tf,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
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

  List<PricePoint> _generatePortfolioValuationPoints(
      double currentVal, bool isPositive) {
    final now = DateTime.now();
    List<PricePoint> points = [];
    double base = currentVal * (isPositive ? 0.85 : 1.15);

    for (int i = 20; i >= 0; i--) {
      double factor = 1.0 + (isPositive ? (20 - i) * 0.008 : -(20 - i) * 0.008);
      double val = base * factor;
      points.add(PricePoint(
        time: now.subtract(Duration(days: i)),
        price: val,
      ));
    }
    if (points.isNotEmpty) {
      points[points.length - 1] = PricePoint(time: now, price: currentVal);
    }
    return points;
  }

  Widget _buildBalanceItem(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ),
      ],
    );
  }
}

class PortfolioChartPainter extends CustomPainter {
  final List<PricePoint> history;
  final bool isPositive;

  PortfolioChartPainter({
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

    for (int i = 0; i < history.length; i++) {
      final x = (i / (history.length - 1)) * size.width;
      final normalizedY = (history[i].price - minPrice) / range;
      final y = size.height - (normalizedY * (size.height - 20)) - 10;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.35), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant PortfolioChartPainter oldDelegate) => true;
}

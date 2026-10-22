import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../models/order.dart';
import '../models/price_alert.dart';
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
  final PageController _pageController = PageController();
  int _activePageIndex = 0;
  String _selectedTimeframe = '1D';

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _showSetPriceAlertModal(BuildContext context, Stock stock) {
    final priceController = TextEditingController(
        text: stock.currentPrice.toStringAsFixed(2));
    AlertCondition condition = AlertCondition.risesAbove;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.add_alert,
                          color: AppColors.goldSharia, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'ضبط تنبيه السعر (${stock.symbol})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Divider(color: Theme.of(context).dividerColor, height: 20),
              const Text('اختر شَرط التنبيه:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('ارتفاع إلى أو أعلى من'),
                      selected: condition == AlertCondition.risesAbove,
                      selectedColor: AppColors.greenPositive.withOpacity(0.25),
                      onSelected: (val) {
                        if (val) {
                          setModalState(() => condition = AlertCondition.risesAbove);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('انخفاض إلى أو أقل من'),
                      selected: condition == AlertCondition.fallsBelow,
                      selectedColor: AppColors.redNegative.withOpacity(0.25),
                      onSelected: (val) {
                        if (val) {
                          setModalState(() => condition = AlertCondition.fallsBelow);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'السعر المستهدف للتنبيه (${stock.currency})',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.notifications_active_outlined,
                      color: AppColors.goldSharia),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final targetPrice =
                        double.tryParse(priceController.text) ?? stock.currentPrice;
                    final alert = PriceAlert(
                      id: 'ALT-${DateTime.now().millisecondsSinceEpoch}',
                      symbol: stock.symbol,
                      stockNameAr: stock.nameAr,
                      targetPrice: targetPrice,
                      condition: condition,
                      currency: stock.currency,
                      createdAt: DateTime.now(),
                    );
                    _stockService.addPriceAlert(alert);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'تم ضبط تنبيه السعر لـ ${stock.symbol} عند ${targetPrice.toStringAsFixed(2)} ${stock.currency}!',
                        ),
                        backgroundColor: AppColors.greenPositive,
                      ),
                    );
                  },
                  child: const Text('تأكيد ضبط التنبيه',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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

        final color = currentStock.isPositive
            ? AppColors.greenPositive
            : AppColors.redNegative;
        final sign = currentStock.isPositive ? '+' : '';

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
                              'شريعة',
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
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_alert_outlined,
                    color: AppColors.goldSharia),
                tooltip: 'ضبط تنبيه سعر السهم',
                onPressed: () => _showSetPriceAlertModal(context, currentStock),
              ),
              IconButton(
                icon: Icon(
                  currentStock.isWatchlisted
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  color: currentStock.isWatchlisted
                      ? AppColors.goldSharia
                      : AppColors.accentBlue,
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
          body: Column(
            children: [
              // Header Summary Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${currentStock.currentPrice.toStringAsFixed(3)} ${currentStock.currency}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text('آخر سعر', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$sign${currentStock.change.toStringAsFixed(3)} ($sign${currentStock.percentChange.toStringAsFixed(2)}%)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        const Text('قيمة التغير', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),

              // Carousel Page Title Indicator
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text(
                  _getPageTitle(_activePageIndex),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.accentBlue),
                ),
              ),

              // Page Dots Indicator •••••
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return Container(
                    width: _activePageIndex == index ? 10 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: _activePageIndex == index
                          ? AppColors.accentBlue
                          : Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),

              // Swipeable Carousel PageView
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _activePageIndex = index;
                    });
                  },
                  children: [
                    // Page 1: الرسم البياني وأداء السهم الأساسي (First Page)
                    _buildPerformanceAndPricePage(currentStock),

                    // Page 2: تفاصيل جدول بيانات السيولة ورأس المال
                    _buildBasicStatsPage(currentStock),

                    // Page 3: السوق بالسعر
                    _buildMarketDepthByPricePage(currentStock),

                    // Page 4: السوق بالأوامر
                    _buildMarketDepthByOrdersPage(currentStock),

                    // Page 5: إجمالي التنفيذات
                    _buildExecutionsPage(currentStock),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildActionBottomBar(context, currentStock),
        );
      },
    );
  }

  String _getPageTitle(int index) {
    switch (index) {
      case 0:
        return 'أداء السهم والرسم البياني';
      case 1:
        return 'بيانات السوق الأساسية';
      case 2:
        return 'السوق بالسعر';
      case 3:
        return 'السوق بالأوامر';
      case 4:
        return 'إجمالي التنفيذات';
      default:
        return '';
    }
  }

  // PAGE 1: Stock Performance Chart, Volume Histogram & Key Stats Overview (First Page)
  Widget _buildPerformanceAndPricePage(Stock stock) {
    final history = _getFilteredHistory(stock, _selectedTimeframe);
    final isChartPositive = history.length >= 2
        ? (history.last.price >= history.first.price)
        : stock.isPositive;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Separate Stock Price Line Chart Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.show_chart,
                              color: AppColors.accentBlue, size: 20),
                          SizedBox(width: 6),
                          Text('الرسم البياني لأداء سعر السهم',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Text(_getTimeframeLabel(_selectedTimeframe),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Dedicated Stock Price Line Chart Painter
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: StockPriceLinePainter(
                        history: history,
                        isPositive: isChartPositive,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Timeframe Buttons
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
                                  : Theme.of(context).dividerColor,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            tf,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.accentBlue,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
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
          ),
          const SizedBox(height: 16),

          // 2. Separate Volume Spikes Histogram Chart Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bar_chart_rounded,
                          color: AppColors.goldSharia, size: 20),
                      SizedBox(width: 6),
                      Text('رسم أحجام التداول والسيولة (Volume Histogram)',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Separate Volume Histogram Painter
                  SizedBox(
                    height: 110,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: StockVolumeHistogramPainter(
                        history: history,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Time Markers Row (10:00, 10:41, 11:21, 12:01, 12:42, 13:24, 14:06)
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('10:00', style: TextStyle(fontSize: 10)),
                      Text('10:41', style: TextStyle(fontSize: 10)),
                      Text('11:21', style: TextStyle(fontSize: 10)),
                      Text('12:01', style: TextStyle(fontSize: 10)),
                      Text('12:42', style: TextStyle(fontSize: 10)),
                      Text('13:24', style: TextStyle(fontSize: 10)),
                      Text('14:06', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Quick Key Stats Overview Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ملخص أداء وتداول اليوم',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  Divider(color: Theme.of(context).dividerColor, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatCol('سعر الفتح',
                          '${stock.openPrice.toStringAsFixed(3)} ${stock.currency}'),
                      _buildStatCol('الإغلاق السابق',
                          '${stock.previousClose.toStringAsFixed(3)} ${stock.currency}'),
                      _buildStatCol('مضاعف الربحية P/E',
                          '${stock.peRatio.toStringAsFixed(2)}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatCol('أعلى سعر اليوم',
                          '${stock.dayHigh.toStringAsFixed(3)} ${stock.currency}'),
                      _buildStatCol('أدنى سعر اليوم',
                          '${stock.dayLow.toStringAsFixed(3)} ${stock.currency}'),
                      _buildStatCol('حجم التداول اليوم',
                          '${_formatNum(stock.volume.toInt())}'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // PAGE 2: Basic Stats Table (Images 5 & 6)
  Widget _buildBasicStatsPage(Stock stock) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildTableRow('حجم أفضل طلب',
                  '${stock.bidsByPrice.first.quantity} × ${stock.bidsByPrice.first.price.toStringAsFixed(3)}'),
              _buildTableRow('حجم أفضل عرض',
                  '${stock.asksByPrice.first.quantity} × ${stock.asksByPrice.first.price.toStringAsFixed(3)}'),
              _buildTableRow('إجمالي الطلبات', _formatNum(stock.totalBidsVolume)),
              _buildTableRow('إجمالي العروض', _formatNum(stock.totalAsksVolume)),
              _buildTableRow('كمية التداول', '${_formatNum(stock.volume.toInt())} سهم'),
              _buildTableRow('عدد العمليات', '${_formatNum(stock.numberOfTrades)} عملية'),
              _buildTableRow('قيمة التداول', '${_formatNum(stock.totalTradeValue.toInt())} ${stock.currency}'),
              _buildTableRow('سعر الفتح - سعر الإغلاق',
                  '${stock.openPrice.toStringAsFixed(3)} - ${stock.previousClose.toStringAsFixed(3)}'),
              _buildTableRow('أقل سعر - أعلى سعر',
                  '${stock.dayLow.toStringAsFixed(3)} - ${stock.dayHigh.toStringAsFixed(3)}'),
              _buildTableRow('الحد الأدنى - الحد الأقصى للجلسة',
                  '${stock.circuitBreakerMin.toStringAsFixed(3)} - ${stock.circuitBreakerMax.toStringAsFixed(3)}'),
              _buildTableRow('52 أسبوع (الأدنى - الأقصى)',
                  '${stock.week52Min.toStringAsFixed(3)} - ${stock.week52Max.toStringAsFixed(3)}'),
              _buildTableRow('رأس المال السوقي', '${_formatNum(stock.marketCap.toInt())} ${stock.currency}'),
              _buildTableRow('مضاعف الربحية (P/E Ratio)', stock.peRatio.toStringAsFixed(2)),
            ],
          ),
        ),
      ),
    );
  }

  // PAGE 3: Market Depth By Price (Image 3)
  Widget _buildMarketDepthByPricePage(Stock stock) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Dual Histogram Bars (Bids vs Asks)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('طلب (Bids)',
                          style: TextStyle(
                              color: AppColors.greenPositive,
                              fontWeight: FontWeight.bold)),
                      Text('عرض (Asks)',
                          style: TextStyle(
                              color: AppColors.redNegative,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: 0.65,
                          backgroundColor: Theme.of(context).cardColor,
                          color: AppColors.greenPositive,
                          minHeight: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: 0.85,
                          backgroundColor: Theme.of(context).cardColor,
                          color: AppColors.redNegative,
                          minHeight: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Depth Table
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(1.5),
                  2: FlexColumnWidth(1.5),
                  3: FlexColumnWidth(1.5),
                  4: FlexColumnWidth(1.5),
                  5: FlexColumnWidth(1),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: Theme.of(context).dividerColor)),
                    ),
                    children: const [
                      Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('#',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('الكمية',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('السعر',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('السعر',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('الكمية',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('#',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    ],
                  ),
                  for (int i = 0; i < 5; i++)
                    TableRow(
                      children: [
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text('${stock.bidsByPrice[i].count}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12))),
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(_formatNum(stock.bidsByPrice[i].quantity),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppColors.greenPositive, fontSize: 12))),
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                                stock.bidsByPrice[i].price.toStringAsFixed(3),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                                stock.asksByPrice[i].price.toStringAsFixed(3),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(_formatNum(stock.asksByPrice[i].quantity),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppColors.redNegative, fontSize: 12))),
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text('${stock.asksByPrice[i].count}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // PAGE 4: Market Depth By Orders (Image 2)
  Widget _buildMarketDepthByOrdersPage(Stock stock) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text('طلب (Bids Order Book)',
                      style: TextStyle(
                          color: AppColors.greenPositive,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                  Text('عرض (Asks Order Book)',
                      style: TextStyle(
                          color: AppColors.redNegative,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
              Divider(color: Theme.of(context).dividerColor, height: 16),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1),
                },
                children: [
                  TableRow(
                    children: const [
                      Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('الكمية',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('السعر',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('السعر',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('الكمية',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    ],
                  ),
                  for (int i = 0; i < stock.bidsByOrder.length; i++)
                    TableRow(
                      children: [
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(_formatNum(stock.bidsByOrder[i].quantity),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppColors.greenPositive, fontSize: 12))),
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                                stock.bidsByOrder[i].price.toStringAsFixed(3),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                                stock.asksByOrder[i].price.toStringAsFixed(3),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12))),
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(_formatNum(stock.asksByOrder[i].quantity),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppColors.redNegative, fontSize: 12))),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // PAGE 5: Executions Stream (Image 1)
  Widget _buildExecutionsPage(Stock stock) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('أجمالي التنفيذات (Time & Sales Stream)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Divider(color: Theme.of(context).dividerColor, height: 16),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(1.5),
                  2: FlexColumnWidth(1.5),
                  3: FlexColumnWidth(1.5),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: Theme.of(context).dividerColor)),
                    ),
                    children: const [
                      Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('العدد',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('القيمة',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('الكمية',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text('السعر',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    ],
                  ),
                  for (final ex in stock.recentExecutions)
                    TableRow(
                      children: [
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text('${ex.count}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12))),
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(_formatNum(ex.value.toInt()),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12))),
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(_formatNum(ex.quantity),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12))),
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(ex.price.toStringAsFixed(3),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12))),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCol(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 2),
        Text(val,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  Widget _buildTableRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
      final volume = 50000 + (seed * 800000);
      points.add(PricePoint(time: time, price: double.parse(current.toStringAsFixed(2)), volume: volume));
    }

    if (points.isNotEmpty) {
      points[points.length - 1] = PricePoint(time: now, price: stock.currentPrice, volume: 950000);
    }

    return points;
  }

  String _formatNum(int num) {
    if (num >= 1000000) {
      return '${(num / 1000000).toStringAsFixed(2)} M';
    } else if (num >= 1000) {
      return '${(num / 1000).toStringAsFixed(1)} K';
    }
    return num.toString();
  }

  Widget _buildActionBottomBar(BuildContext context, Stock stock) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).cardColor,
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
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => OrderModal(stock: stock, initialSide: side),
    );
  }
}

// Dedicated Stock Price Line Chart Painter (Card 1 on Page 1)
class StockPriceLinePainter extends CustomPainter {
  final List<PricePoint> history;
  final bool isPositive;

  StockPriceLinePainter({
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

    final color = AppColors.accentBlue;

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
        colors: [color.withOpacity(0.4), color.withOpacity(0.02)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant StockPriceLinePainter oldDelegate) => true;
}

// Dedicated Separate Volume Histogram Painter (Card 2 on Page 1)
class StockVolumeHistogramPainter extends CustomPainter {
  final List<PricePoint> history;

  StockVolumeHistogramPainter({required this.history});

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    final volumes = history.map((p) => p.volume).toList();
    final maxVol = volumes.reduce((a, b) => a > b ? a : b);

    final color = AppColors.accentBlue.withOpacity(0.85);
    final volPaint = Paint()..color = color;
    final barWidth = (size.width / history.length) * 0.65;

    for (int i = 0; i < history.length; i++) {
      final x = (i / (history.length - 1)) * size.width;
      final volNorm = maxVol == 0 ? 0.0 : (history[i].volume / maxVol);
      final barH = volNorm * size.height;
      final top = size.height - barH;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - (barWidth / 2), top, barWidth, barH),
          const Radius.circular(2),
        ),
        volPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant StockVolumeHistogramPainter oldDelegate) => true;
}

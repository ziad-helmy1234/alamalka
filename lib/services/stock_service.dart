import 'dart:async';
import 'dart:math';
import '../models/stock.dart';
import '../models/order.dart';
import '../models/portfolio.dart';
import '../models/ipo.dart';
import '../models/news_event.dart';
import '../models/user_profile.dart';

class StockService {
  static final StockService _instance = StockService._internal();
  factory StockService() => _instance;
  StockService._internal() {
    _initMockData();
    _startLivePriceTicker();
  }

  final _random = Random();
  final _stocksStreamController = StreamController<List<Stock>>.broadcast();
  Stream<List<Stock>> get stocksStream => _stocksStreamController.stream;

  List<Stock> _allStocks = [];
  List<Order> _orders = [];
  
  // Portfolio state with separated EGP & USD
  double _egpCash = 150000.0;
  double _egpBuyingPower = 150000.0;
  List<PortfolioHolding> _egpHoldings = [];

  double _usdCash = 12500.0;
  double _usdBuyingPower = 12500.0;
  List<PortfolioHolding> _usdHoldings = [];

  Timer? _tickerTimer;

  List<Stock> get allStocks => List.unmodifiable(_allStocks);
  List<Order> get orders => List.unmodifiable(_orders);

  void _initMockData() {
    final now = DateTime.now();

    List<PricePoint> generateHistory(double base) {
      List<PricePoint> points = [];
      double current = base * 0.92;
      for (int i = 30; i >= 0; i--) {
        current += (_random.nextDouble() - 0.48) * (base * 0.02);
        points.add(PricePoint(
          time: now.subtract(Duration(days: i)),
          price: double.parse(current.toStringAsFixed(2)),
        ));
      }
      return points;
    }

    _allStocks = [
      Stock(
        symbol: 'COMI',
        name: 'Commercial International Bank',
        nameAr: 'البنك التجاري الدولي',
        sector: 'Banking',
        sectorAr: 'بنوك وخدمات مالية',
        currentPrice: 84.50,
        previousClose: 82.10,
        dayHigh: 85.20,
        dayLow: 82.00,
        volume: 4250000,
        isShariaCompliant: false,
        currency: 'EGP',
        isWatchlisted: true,
        history: generateHistory(84.50),
      ),
      Stock(
        symbol: 'EAST',
        name: 'Eastern Company',
        nameAr: 'إيسترن كومباني',
        sector: 'Consumer Goods',
        sectorAr: 'سلع استهلاكية',
        currentPrice: 28.75,
        previousClose: 29.10,
        dayHigh: 29.30,
        dayLow: 28.50,
        volume: 1850000,
        isShariaCompliant: false,
        currency: 'EGP',
        isWatchlisted: false,
        history: generateHistory(28.75),
      ),
      Stock(
        symbol: 'SWDY',
        name: 'Elsewedy Electric',
        nameAr: 'السويدى إليكتريك',
        sector: 'Industrial',
        sectorAr: 'صناعة وطاقة',
        currentPrice: 42.10,
        previousClose: 40.50,
        dayHigh: 42.80,
        dayLow: 40.20,
        volume: 3100000,
        isShariaCompliant: true,
        currency: 'EGP',
        isWatchlisted: true,
        history: generateHistory(42.10),
      ),
      Stock(
        symbol: 'TMGH',
        name: 'Talaat Moustafa Group',
        nameAr: 'مجموعة طلعت مصطفى',
        sector: 'Real Estate',
        sectorAr: 'عقارات',
        currentPrice: 61.20,
        previousClose: 59.80,
        dayHigh: 62.00,
        dayLow: 59.50,
        volume: 5400000,
        isShariaCompliant: true,
        currency: 'EGP',
        isWatchlisted: true,
        history: generateHistory(61.20),
      ),
      Stock(
        symbol: 'HRHO',
        name: 'EFG Holding',
        nameAr: 'إي إف جي القابضة',
        sector: 'Financial Services',
        sectorAr: 'خدمات مالية غير مصرفية',
        currentPrice: 21.40,
        previousClose: 21.80,
        dayHigh: 22.10,
        dayLow: 21.20,
        volume: 2900000,
        isShariaCompliant: true,
        currency: 'EGP',
        isWatchlisted: false,
        history: generateHistory(21.40),
      ),
      Stock(
        symbol: 'FWRY',
        name: 'Fawry for Banking & Tech',
        nameAr: 'فوري تكنولوجيا البنوك',
        sector: 'Technology',
        sectorAr: 'تكنولوجيا الاتصالات',
        currentPrice: 7.85,
        previousClose: 7.60,
        dayHigh: 7.95,
        dayLow: 7.55,
        volume: 8700000,
        isShariaCompliant: true,
        currency: 'EGP',
        isWatchlisted: true,
        history: generateHistory(7.85),
      ),
      Stock(
        symbol: 'ORAS',
        name: 'Orascom Construction',
        nameAr: 'أوراسكوم للإنشاءات',
        sector: 'Construction',
        sectorAr: 'مقاولات وإنشاءات',
        currentPrice: 245.00,
        previousClose: 240.00,
        dayHigh: 248.00,
        dayLow: 239.00,
        volume: 820000,
        isShariaCompliant: true,
        currency: 'USD',
        isWatchlisted: false,
        history: generateHistory(245.00),
      ),
      Stock(
        symbol: 'ABUK',
        name: 'Abu Qir Fertilizers',
        nameAr: 'أبو قير للأساد',
        sector: 'Chemicals',
        sectorAr: 'كيماويات وأسمدة',
        currentPrice: 68.90,
        previousClose: 69.50,
        dayHigh: 70.20,
        dayLow: 68.50,
        volume: 1400000,
        isShariaCompliant: true,
        currency: 'EGP',
        isWatchlisted: false,
        history: generateHistory(68.90),
      ),
    ];

    // Initialize mock portfolio holdings
    _egpHoldings = [
      PortfolioHolding(
        symbol: 'TMGH',
        stockName: 'Talaat Moustafa Group',
        stockNameAr: 'مجموعة طلعت مصطفى',
        quantity: 1200,
        averageBuyPrice: 52.00,
        currentPrice: 61.20,
        currency: 'EGP',
      ),
      PortfolioHolding(
        symbol: 'SWDY',
        stockName: 'Elsewedy Electric',
        stockNameAr: 'السويدى إليكتريك',
        quantity: 800,
        averageBuyPrice: 38.50,
        currentPrice: 42.10,
        currency: 'EGP',
      ),
      PortfolioHolding(
        symbol: 'FWRY',
        stockName: 'Fawry',
        stockNameAr: 'فوري',
        quantity: 5000,
        averageBuyPrice: 6.90,
        currentPrice: 7.85,
        currency: 'EGP',
      ),
    ];

    _usdHoldings = [
      PortfolioHolding(
        symbol: 'ORAS',
        stockName: 'Orascom Construction',
        stockNameAr: 'أوراسكوم للإنشاءات',
        quantity: 40,
        averageBuyPrice: 220.00,
        currentPrice: 245.00,
        currency: 'USD',
      ),
    ];

    // Mock initial orders
    _orders = [
      Order(
        id: 'ORD-101',
        symbol: 'TMGH',
        stockName: 'مجموعة طلعت مصطفى',
        type: OrderType.limit,
        side: OrderSide.buy,
        targetPrice: 60.00,
        quantity: 500,
        validity: OrderValidity.gtc,
        custodianBank: 'البنك التجاري الدولي (CIB)',
        currency: 'EGP',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        status: OrderStatus.pending,
      ),
      Order(
        id: 'ORD-102',
        symbol: 'COMI',
        stockName: 'البنك التجاري الدولي',
        type: OrderType.market,
        side: OrderSide.buy,
        targetPrice: 84.50,
        quantity: 200,
        validity: OrderValidity.day,
        custodianBank: 'البنك الأهلي المصري (NBE)',
        currency: 'EGP',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        status: OrderStatus.executed,
      ),
    ];
  }

  void _startLivePriceTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      for (int i = 0; i < _allStocks.length; i++) {
        final stock = _allStocks[i];
        final delta = (_random.nextDouble() - 0.49) * (stock.currentPrice * 0.005);
        final newPrice = double.parse((stock.currentPrice + delta).toStringAsFixed(2));
        final newHigh = max(stock.dayHigh, newPrice);
        final newLow = min(stock.dayLow, newPrice);

        final updatedHistory = List<PricePoint>.from(stock.history);
        updatedHistory.add(PricePoint(time: DateTime.now(), price: newPrice));
        if (updatedHistory.length > 50) updatedHistory.removeAt(0);

        _allStocks[i] = Stock(
          symbol: stock.symbol,
          name: stock.name,
          nameAr: stock.nameAr,
          sector: stock.sector,
          sectorAr: stock.sectorAr,
          currentPrice: newPrice,
          previousClose: stock.previousClose,
          dayHigh: newHigh,
          dayLow: newLow,
          volume: stock.volume + _random.nextInt(1500),
          isShariaCompliant: stock.isShariaCompliant,
          currency: stock.currency,
          isWatchlisted: stock.isWatchlisted,
          history: updatedHistory,
        );
      }
      _stocksStreamController.add(_allStocks);
    });
  }

  // Stock search and filters (Decoupled from Watchlist)
  List<Stock> searchStocks({
    String query = '',
    String? selectedSectorAr,
    bool onlySharia = false,
  }) {
    return _allStocks.where((s) {
      final matchesQuery = query.isEmpty ||
          s.symbol.toLowerCase().contains(query.toLowerCase()) ||
          s.name.toLowerCase().contains(query.toLowerCase()) ||
          s.nameAr.contains(query);

      final matchesSector = selectedSectorAr == null ||
          selectedSectorAr == 'الكل' ||
          s.sectorAr == selectedSectorAr;

      final matchesSharia = !onlySharia || s.isShariaCompliant;

      return matchesQuery && matchesSector && matchesSharia;
    }).toList();
  }

  void toggleWatchlist(String symbol) {
    final index = _allStocks.indexWhere((s) => s.symbol == symbol);
    if (index != -1) {
      final stock = _allStocks[index];
      stock.isWatchlisted = !stock.isWatchlisted;
      _stocksStreamController.add(_allStocks);
    }
  }

  // Top Gainers & Losers
  List<Stock> getTopGainers({int limit = 5}) {
    final list = List<Stock>.from(_allStocks);
    list.sort((a, b) => b.percentChange.compareTo(a.percentChange));
    return list.take(limit).toList();
  }

  List<Stock> getTopLosers({int limit = 5}) {
    final list = List<Stock>.from(_allStocks);
    list.sort((a, b) => a.percentChange.compareTo(b.percentChange));
    return list.take(limit).toList();
  }

  // News & Events
  List<NewsItem> getMarketNews({String? symbolFilter}) {
    final news = [
      NewsItem(
        id: 'NEWS-1',
        titleAr: 'البنك التجاري الدولي (COMI) يحقق أرباحاً قياسية بزيادة 38% في النصف الأول',
        summaryAr: 'أعلن البنك التجاري الدولي عن نتائجه المالية التي أظهرت صافي أرباح قدره 14.2 مليار جنيه بفضل نمو صافي دخل العائد.',
        categoryAr: 'نتائج أعمال',
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
        relatedSymbol: 'COMI',
        source: 'إفصاحات البورصة المصرية',
        isUrgent: true,
      ),
      NewsItem(
        id: 'NEWS-2',
        titleAr: 'البنك المركزي المصري يبقي على أسعار الفائدة الرئيسية دون تغيير في اجتماعه اليوم',
        summaryAr: 'قررت لجنة السياسة النقدية الإبقاء على سعر عائد الإيداع والإقراض لليلة واحدة عند مستوياته الحالية لدعم استقرار الأسعار.',
        categoryAr: 'اقتصاد كلي',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        source: 'البنك المركزي المصري',
        isUrgent: true,
      ),
      NewsItem(
        id: 'NEWS-3',
        titleAr: 'مجموعة طلعت مصطفى (TMGH) تطلق مشروعاً فندقياً ضخماً باستثمارات تتجاوز 1.5 مليار دولار',
        summaryAr: 'وقعت المجموعة اتفاقية تطوير مشروع سياحي وفندقي فاخر على الساحل الشمالي بالتعاون مع مجموعات عالمية.',
        categoryAr: 'توسع واستثمار',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        relatedSymbol: 'TMGH',
        source: 'بيان إعلامي للشركة',
      ),
      NewsItem(
        id: 'NEWS-4',
        titleAr: 'شركة فوري (FWRY) تتوسع في خدمات التمويل متناهي الصغر وتفتح 50 فرعاً جديداً',
        summaryAr: 'أعلنت فوري لتكنولوجيا البنوك عن استراتيجيتها للتوسع التمويلي في المحافظات مع زيادة حجم العمليات الرقمية بنسبة 45%.',
        categoryAr: 'نتائج أعمال',
        timestamp: DateTime.now().subtract(const Duration(hours: 9)),
        relatedSymbol: 'FWRY',
        source: 'العربية بزنس',
      ),
      NewsItem(
        id: 'NEWS-5',
        titleAr: 'السويدى إليكتريك (SWDY) تفوز بعقد إنشاء محطة طاقة شمسية بقيمة 320 مليون دولار',
        summaryAr: 'وقع تحالف السويدي إليكتريك اتفاقية إنشاء وتوريد محطة توليد طاقة متجددة في المنطقة الاقتصادية لقناة السويس.',
        categoryAr: 'عقود وترسيات',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        relatedSymbol: 'SWDY',
        source: 'إفصاح البورصة',
      ),
    ];

    if (symbolFilter != null && symbolFilter.isNotEmpty) {
      return news.where((n) => n.relatedSymbol == symbolFilter).toList();
    }
    return news;
  }

  List<MarketEvent> getEconomicEvents() {
    final now = DateTime.now();
    return [
      MarketEvent(
        id: 'EVT-1',
        titleAr: 'توزيع كوبون نقدي بقيمة 2.50 جنيه لكل سهم',
        date: now.add(const Duration(days: 3)),
        eventType: 'dividend',
        eventTypeAr: 'توزيعات أرباح',
        relatedSymbol: 'COMI',
        detailsAr: 'تاريخ استحقاق الكوبون النقدي للمساهمين المقيدين بجدول البورصة.',
      ),
      MarketEvent(
        id: 'EVT-2',
        titleAr: 'اجتماع الجمعية العمومية العادية لشركة طلعت مصطفى',
        date: now.add(const Duration(days: 6)),
        eventType: 'agm',
        eventTypeAr: 'جمعية عمومية',
        relatedSymbol: 'TMGH',
        detailsAr: 'اعتماد نتائج الأعمال السنوية والموافقة على خطة التوزيعات الاستثمارية.',
      ),
      MarketEvent(
        id: 'EVT-3',
        titleAr: 'اجتماع لجنة السياسة النقدية بالبنك المركزي لتحديد أسعار الفائدة',
        date: now.add(const Duration(days: 14)),
        eventType: 'macro',
        eventTypeAr: 'قرارات الفائدة',
        detailsAr: 'الاجتماع الدوري الخامس للجنة السياسة النقدية لعام 2024.',
      ),
      MarketEvent(
        id: 'EVT-4',
        titleAr: 'الإعلان عن أرباح الربع الثالث لشركة السويدي إليكتريك',
        date: now.add(const Duration(days: 18)),
        eventType: 'earnings',
        eventTypeAr: 'نتائج أعمال',
        relatedSymbol: 'SWDY',
        detailsAr: 'إفصاح القوائم المالية المستقلة والمجمعة للربع الثالث.',
      ),
    ];
  }

  // Portfolio & Wallet
  List<TransferRecord> _transferHistory = [
    TransferRecord(
      id: 'TRF-9021',
      amount: 50000.0,
      currency: 'EGP',
      typeAr: 'إيداع نقدي',
      methodAr: 'InstaPay',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      statusAr: 'مكتمل بنجاح',
    ),
    TransferRecord(
      id: 'TRF-8840',
      amount: 2500.0,
      currency: 'USD',
      typeAr: 'إيداع نقدي',
      methodAr: 'تحويل بنكي',
      timestamp: DateTime.now().subtract(const Duration(days: 10)),
      statusAr: 'مكتمل بنجاح',
    ),
  ];

  List<InboxMessage> _inboxMessages = [
    InboxMessage(
      id: 'MSG-1',
      titleAr: 'تأكيد إيداع مبلغ 50,000 ج.م عبر InstaPay',
      bodyAr: 'تمت إضافة المبلغ بنجاح إلى رصيد محفظتك الجاري والقوة الشرائية.',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      isRead: false,
    ),
    InboxMessage(
      id: 'MSG-2',
      titleAr: 'تأكيد تنفيذ أمر شراء سهم TMGH',
      bodyAr: 'تم تنفيذ أمر الشراء لعدد 500 سهم بسعر 60.00 ج.م للسهم.',
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      isRead: true,
    ),
  ];

  List<StatementDoc> _statements = [
    StatementDoc(
      id: 'ST-2024-Q2',
      titleAr: 'كشف الحساب الربع سنوي - الربع الثاني 2024',
      periodAr: 'أبريل - يونيو 2024',
      date: DateTime.now().subtract(const Duration(days: 15)),
      fileSize: '1.4 MB (PDF)',
    ),
    StatementDoc(
      id: 'ST-2024-06',
      titleAr: 'كشف الحساب الشهري - يونيو 2024',
      periodAr: 'يونيو 2024',
      date: DateTime.now().subtract(const Duration(days: 30)),
      fileSize: '850 KB (PDF)',
    ),
  ];

  List<FormDoc> _forms = [
    FormDoc(
      id: 'FORM-KYC',
      titleAr: 'نموذج اعرف عميلك (KYC) المحدث',
      descriptionAr: 'بيانات الهوية والبيانات المالية المعتمدة لدى الهيئة العامة للرقابة المالية.',
      statusAr: 'مكتمل ومعتمد',
    ),
    FormDoc(
      id: 'FORM-W8',
      titleAr: 'نموذج W-8BEN لتداول الأسهم بالدولار (USD)',
      descriptionAr: 'الإقرار الضريبي المعتمد لتداول الأسهم والشهادات المقومة بالدولار.',
      statusAr: 'مكتمل ومعتمد',
    ),
    FormDoc(
      id: 'FORM-PWR',
      titleAr: 'طلب رفع حدود القوة الشرائية المباشرة',
      descriptionAr: 'نموذج طلب زيادة التسهيلات والقوة الشرائية اللحظية.',
      statusAr: 'متاح للتقديم',
    ),
  ];

  List<TransferRecord> get transferHistory => List.unmodifiable(_transferHistory);
  List<InboxMessage> get inboxMessages => List.unmodifiable(_inboxMessages);
  List<StatementDoc> get statements => List.unmodifiable(_statements);
  List<FormDoc> get forms => List.unmodifiable(_forms);

  void addFunds(String currency, double amount, String methodAr) {
    if (currency == 'EGP') {
      _egpCash += amount;
      _egpBuyingPower += amount;
    } else {
      _usdCash += amount;
      _usdBuyingPower += amount;
    }

    _transferHistory.insert(
      0,
      TransferRecord(
        id: 'TRF-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        amount: amount,
        currency: currency,
        typeAr: 'إيداع نقدي',
        methodAr: methodAr,
        timestamp: DateTime.now(),
        statusAr: 'مكتمل بنجاح',
      ),
    );

    _inboxMessages.insert(
      0,
      InboxMessage(
        id: 'MSG-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        titleAr: 'تأكيد إيداع $amount $currency عبر $methodAr',
        bodyAr: 'تمت إضافة المبلغ بنجاح إلى محفظتك والقوة الشرائية المتاحة.',
        timestamp: DateTime.now(),
        isRead: false,
      ),
    );

    _stocksStreamController.add(_allStocks);
  }

  PortfolioSummary getPortfolioSummary() {
    return PortfolioSummary(
      egpCashBalance: _egpCash,
      egpBuyingPower: _egpBuyingPower,
      egpHoldings: _egpHoldings,
      usdCashBalance: _usdCash,
      usdBuyingPower: _usdBuyingPower,
      usdHoldings: _usdHoldings,
    );
  }

  // Place Order
  bool placeOrder(Order order) {
    if (order.currency == 'EGP') {
      if (order.totalValue > _egpBuyingPower && order.side == OrderSide.buy) {
        return false; // Insufficient buying power
      }
      if (order.side == OrderSide.buy) {
        _egpBuyingPower -= order.totalValue;
      }
    } else {
      if (order.totalValue > _usdBuyingPower && order.side == OrderSide.buy) {
        return false;
      }
      if (order.side == OrderSide.buy) {
        _usdBuyingPower -= order.totalValue;
      }
    }

    _orders.insert(0, order);
    return true;
  }

  // Cancel Pending Order
  bool cancelOrder(String orderId) {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx == -1) return false;

    final order = _orders[idx];
    if (order.status != OrderStatus.pending) return false;

    // Refund buying power if it was a pending buy order
    if (order.side == OrderSide.buy) {
      if (order.currency == 'EGP') {
        _egpBuyingPower += order.totalValue;
      } else {
        _usdBuyingPower += order.totalValue;
      }
    }

    order.status = OrderStatus.cancelled;

    _inboxMessages.insert(
      0,
      InboxMessage(
        id: 'MSG-${DateTime.now().millisecondsSinceEpoch}',
        titleAr: 'إلغاء أمر ${order.symbol}',
        bodyAr: 'تم إلغاء الأمر ${order.id} بنجاح وإعادة القوة الشرائية المتبقية إلى محفظتك.',
        timestamp: DateTime.now(),
        isRead: false,
      ),
    );

    return true;
  }

  // Edit Pending Order
  bool editOrder(Order editedOrder) {
    final idx = _orders.indexWhere((o) => o.id == editedOrder.id);
    if (idx == -1) return false;

    final oldOrder = _orders[idx];
    if (oldOrder.status != OrderStatus.pending) return false;

    // Calculate difference in buying power if buy order
    if (editedOrder.side == OrderSide.buy) {
      final diff = editedOrder.totalValue - oldOrder.totalValue;
      if (editedOrder.currency == 'EGP') {
        if (_egpBuyingPower < diff) return false; // Not enough power for increase
        _egpBuyingPower -= diff;
      } else {
        if (_usdBuyingPower < diff) return false;
        _usdBuyingPower -= diff;
      }
    }

    _orders[idx] = editedOrder;

    _inboxMessages.insert(
      0,
      InboxMessage(
        id: 'MSG-${DateTime.now().millisecondsSinceEpoch}',
        titleAr: 'تعديل أمر ${editedOrder.symbol}',
        bodyAr: 'تم تعديل بيانات الأمر ${editedOrder.id} بنجاح بنظام البورصة المصرية.',
        timestamp: DateTime.now(),
        isRead: false,
      ),
    );

    return true;
  }

  // IPO Ripple Effect analysis
  List<IPORippleEffect> getUpcomingIPORippleEffects() {
    return [
      IPORippleEffect(
        ipoSymbol: 'VALU',
        companyName: 'Valu Consumer Finance',
        companyNameAr: 'فاليو للتكنولوجيا المالية والتسهيلات الائتمانية',
        sector: 'FinTech',
        sectorAr: 'تكنولوجيا مالية وتمويل استهلاكي',
        expectedPriceRangeMin: 12.50,
        expectedPriceRangeMax: 14.00,
        targetFundingEgp: 2500000000, // 2.5 Billion EGP
        subscriptionStartDate: DateTime.now().add(const Duration(days: 5)),
        subscriptionEndDate: DateTime.now().add(const Duration(days: 12)),
        liquiditySiphonImpactScore: 8.4,
        marketImpactSummaryAr:
            'طرح ضخم بقيمة 2.5 مليار جنيه سيؤدي لسحب سيولة مؤقتة من أسهم التكنولوجيا المالية والعقارات (مثل FWRY و TMGH) بنسبة متوقعة 3-5% خلال فترة الاكتتاب.',
        affectedSectorsAr: ['تكنولوجيا الاتصالات', 'خدمات مالية غير مصرفية', 'عقارات'],
        affectedPortfolioStocks: ['FWRY', 'TMGH'],
        actionableInsightAr:
            'توقع فرص شراء جيدة عند انخفاض أسعار FWRY و HRHO المؤقت أثناء تحويل المستثمرين لسيولهم لتغطية اكتتاب فاليو.',
      ),
      IPORippleEffect(
        ipoSymbol: 'CHMI',
        companyName: 'Chedid Capital Petrochemicals',
        companyNameAr: 'شديد بتروكيماويات',
        sector: 'Chemicals',
        sectorAr: 'كيماويات وأسمدة',
        expectedPriceRangeMin: 35.00,
        expectedPriceRangeMax: 38.50,
        targetFundingEgp: 1800000000,
        subscriptionStartDate: DateTime.now().add(const Duration(days: 20)),
        subscriptionEndDate: DateTime.now().add(const Duration(days: 27)),
        liquiditySiphonImpactScore: 6.2,
        marketImpactSummaryAr:
            'طرح متخصص قد يرفع تقييم مضاعفات ربحية قطاع البتروكيماويات والسماد ككل، مما ينعكس إيجابياً على سهم ABUK.',
        affectedSectorsAr: ['كيماويات وأسمدة', 'صناعة وطاقة'],
        affectedPortfolioStocks: ['ABUK'],
        actionableInsightAr:
            'إعادة تقييم قطاع الأسمدة والكيماويات قد تحفز صعود ABUK بنسبة 6-8% مع قرب إعلان تقييم الطرح النهائي.',
      ),
    ];
  }

  void dispose() {
    _tickerTimer?.cancel();
    _stocksStreamController.close();
  }
}

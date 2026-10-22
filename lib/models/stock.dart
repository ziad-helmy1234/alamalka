class PricePoint {
  final DateTime time;
  final double price;
  final double volume;

  PricePoint({required this.time, required this.price, this.volume = 1000});
}

class OrderBookLevel {
  final int count; // عدد الأوامر
  final int quantity; // الكمية
  final double price; // السعر

  OrderBookLevel({
    required this.count,
    required this.quantity,
    required this.price,
  });
}

class TradeExecution {
  final int count;
  final double value;
  final int quantity;
  final double price;

  TradeExecution({
    required this.count,
    required this.value,
    required this.quantity,
    required this.price,
  });
}

class Stock {
  final String symbol;
  final String name;
  final String nameAr;
  final String sector;
  final String sectorAr;
  final double currentPrice;
  final double previousClose;
  final double openPrice;
  final double dayHigh;
  final double dayLow;
  final double volume;
  final bool isShariaCompliant;
  final String currency; // 'EGP' or 'USD'
  final List<PricePoint> history;
  bool isWatchlisted;

  // EGX Market Stats & Level 2 Depth
  final double marketCap;
  final double peRatio;
  final int totalBidsVolume;
  final int totalAsksVolume;
  final int numberOfTrades;
  final double totalTradeValue;
  final double circuitBreakerMin;
  final double circuitBreakerMax;
  final double week52Min;
  final double week52Max;

  final List<OrderBookLevel> bidsByPrice;
  final List<OrderBookLevel> asksByPrice;
  final List<OrderBookLevel> bidsByOrder;
  final List<OrderBookLevel> asksByOrder;
  final List<TradeExecution> recentExecutions;

  Stock({
    required this.symbol,
    required this.name,
    required this.nameAr,
    required this.sector,
    required this.sectorAr,
    required this.currentPrice,
    required this.previousClose,
    required this.dayHigh,
    required this.dayLow,
    required this.volume,
    required this.isShariaCompliant,
    required this.currency,
    required this.history,
    this.isWatchlisted = false,
    double? openPrice,
    double? marketCap,
    double? peRatio,
    int? totalBidsVolume,
    int? totalAsksVolume,
    int? numberOfTrades,
    double? totalTradeValue,
    double? circuitBreakerMin,
    double? circuitBreakerMax,
    double? week52Min,
    double? week52Max,
    List<OrderBookLevel>? bidsByPrice,
    List<OrderBookLevel>? asksByPrice,
    List<OrderBookLevel>? bidsByOrder,
    List<OrderBookLevel>? asksByOrder,
    List<TradeExecution>? recentExecutions,
  })  : openPrice = openPrice ?? (previousClose * 1.002),
        marketCap = marketCap ?? (currentPrice * 3500000000),
        peRatio = peRatio ?? 5.21,
        totalBidsVolume = totalBidsVolume ?? 89400,
        totalAsksVolume = totalAsksVolume ?? 677333,
        numberOfTrades = numberOfTrades ?? 2555,
        totalTradeValue = totalTradeValue ?? (volume * currentPrice * 0.95),
        circuitBreakerMin = circuitBreakerMin ?? (previousClose * 0.9),
        circuitBreakerMax = circuitBreakerMax ?? (previousClose * 1.1),
        week52Min = week52Min ?? (previousClose * 0.75),
        week52Max = week52Max ?? (previousClose * 1.25),
        bidsByPrice = bidsByPrice ?? _generateMockBids(currentPrice),
        asksByPrice = asksByPrice ?? _generateMockAsks(currentPrice),
        bidsByOrder = bidsByOrder ?? _generateMockBids(currentPrice),
        asksByOrder = asksByOrder ?? _generateMockAsks(currentPrice),
        recentExecutions = recentExecutions ?? _generateMockExecutions(currentPrice);

  static List<OrderBookLevel> _generateMockBids(double basePrice) {
    return [
      OrderBookLevel(count: 10, quantity: 4843, price: double.parse((basePrice * 1.0).toStringAsFixed(3))),
      OrderBookLevel(count: 1, quantity: 12, price: double.parse((basePrice * 0.999).toStringAsFixed(3))),
      OrderBookLevel(count: 38, quantity: 3571, price: double.parse((basePrice * 0.998).toStringAsFixed(3))),
      OrderBookLevel(count: 1, quantity: 40, price: double.parse((basePrice * 0.997).toStringAsFixed(3))),
      OrderBookLevel(count: 1, quantity: 10, price: double.parse((basePrice * 0.996).toStringAsFixed(3))),
      OrderBookLevel(count: 22, quantity: 1000, price: double.parse((basePrice * 0.995).toStringAsFixed(3))),
      OrderBookLevel(count: 5, quantity: 2000, price: double.parse((basePrice * 0.994).toStringAsFixed(3))),
    ];
  }

  static List<OrderBookLevel> _generateMockAsks(double basePrice) {
    return [
      OrderBookLevel(count: 1, quantity: 87, price: double.parse((basePrice * 1.006).toStringAsFixed(3))),
      OrderBookLevel(count: 1, quantity: 96, price: double.parse((basePrice * 1.008).toStringAsFixed(3))),
      OrderBookLevel(count: 1, quantity: 350, price: double.parse((basePrice * 1.010).toStringAsFixed(3))),
      OrderBookLevel(count: 4, quantity: 8519, price: double.parse((basePrice * 1.012).toStringAsFixed(3))),
      OrderBookLevel(count: 2, quantity: 160, price: double.parse((basePrice * 1.014).toStringAsFixed(3))),
      OrderBookLevel(count: 8, quantity: 500, price: double.parse((basePrice * 1.016).toStringAsFixed(3))),
      OrderBookLevel(count: 12, quantity: 1200, price: double.parse((basePrice * 1.018).toStringAsFixed(3))),
    ];
  }

  static List<TradeExecution> _generateMockExecutions(double basePrice) {
    return [
      TradeExecution(count: 55, value: 797687, quantity: 6199, price: double.parse((basePrice * 1.028).toStringAsFixed(3))),
      TradeExecution(count: 4, value: 64814, quantity: 504, price: double.parse((basePrice * 1.027).toStringAsFixed(3))),
      TradeExecution(count: 1, value: 193656, quantity: 1506, price: double.parse((basePrice * 1.026).toStringAsFixed(3))),
      TradeExecution(count: 1, value: 385, quantity: 3, price: double.parse((basePrice * 1.025).toStringAsFixed(3))),
      TradeExecution(count: 26, value: 779352, quantity: 6065, price: double.parse((basePrice * 1.024).toStringAsFixed(3))),
      TradeExecution(count: 2, value: 5011, quantity: 39, price: double.parse((basePrice * 1.023).toStringAsFixed(3))),
      TradeExecution(count: 5, value: 364270, quantity: 2837, price: double.parse((basePrice * 1.022).toStringAsFixed(3))),
      TradeExecution(count: 1, value: 2952, quantity: 23, price: double.parse((basePrice * 1.021).toStringAsFixed(3))),
      TradeExecution(count: 1, value: 1026, quantity: 8, price: double.parse((basePrice * 1.020).toStringAsFixed(3))),
      TradeExecution(count: 9, value: 66946, quantity: 522, price: double.parse((basePrice * 1.019).toStringAsFixed(3))),
      TradeExecution(count: 1, value: 9872, quantity: 77, price: double.parse((basePrice * 1.018).toStringAsFixed(3))),
      TradeExecution(count: 7, value: 358988, quantity: 2800, price: double.parse((basePrice * 1.017).toStringAsFixed(3))),
    ];
  }

  double get change => currentPrice - previousClose;
  double get percentChange =>
      previousClose == 0 ? 0 : (change / previousClose) * 100;
  bool get isPositive => change >= 0;
}

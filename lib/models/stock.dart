class PricePoint {
  final DateTime time;
  final double price;

  PricePoint({required this.time, required this.price});
}

class Stock {
  final String symbol;
  final String name;
  final String nameAr;
  final String sector;
  final String sectorAr;
  final double currentPrice;
  final double previousClose;
  final double dayHigh;
  final double dayLow;
  final double volume;
  final bool isShariaCompliant;
  final String currency; // 'EGP' or 'USD'
  final List<PricePoint> history;
  bool isWatchlisted;

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
  });

  double get change => currentPrice - previousClose;
  double get percentChange =>
      previousClose == 0 ? 0 : (change / previousClose) * 100;
  bool get isPositive => change >= 0;
}

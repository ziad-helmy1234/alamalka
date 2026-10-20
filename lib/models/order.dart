enum OrderType { market, limit, stopLoss }
enum OrderSide { buy, sell }
enum OrderValidity { day, gtc } // GTC = Good Till Cancelled
enum OrderStatus { pending, executed, cancelled }

class Order {
  final String id;
  final String symbol;
  final String stockName;
  final OrderType type;
  final OrderSide side;
  final double targetPrice;
  final int quantity;
  final OrderValidity validity;
  final String currency;
  final DateTime timestamp;
  OrderStatus status;

  Order({
    required this.id,
    required this.symbol,
    required this.stockName,
    required this.type,
    required this.side,
    required this.targetPrice,
    required this.quantity,
    required this.validity,
    required this.currency,
    required this.timestamp,
    this.status = OrderStatus.pending,
  });

  double get totalValue => targetPrice * quantity;
}

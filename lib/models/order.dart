enum OrderType { market, limit, stopLoss }
enum OrderSide { buy, sell }
enum OrderValidity { day, gtc, gtd } // Day, Good Till Cancelled, Good Till Date
enum OrderStatus { pending, executed, cancelled }

class Order {
  final String id;
  final String symbol;
  final String stockName;
  final OrderType type;
  final OrderSide side;
  final double targetPrice;
  final int quantity;
  final int? minimumBlockQuantity; // شرطي - الحد الأدنى لكمية الدفعة
  final OrderValidity validity;
  final DateTime? validUntilDate;
  final String custodianBank; // أمين الحفظ
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
    this.minimumBlockQuantity,
    required this.validity,
    this.validUntilDate,
    this.custodianBank = 'البنك التجاري الدولي (CIB)',
    required this.currency,
    required this.timestamp,
    this.status = OrderStatus.pending,
  });

  bool get isConditional => minimumBlockQuantity != null && minimumBlockQuantity! > 0;
  double get totalValue => targetPrice * quantity;
}

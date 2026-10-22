enum OrderType { market, limit, stopLoss }
enum OrderSide { buy, sell }
enum OrderValidity { day, gtc, gtd } // Day, Good Till Cancelled, Good Till Date
enum OrderStatus { pending, executed, cancelled }
enum ExecutionRule { regular, mf, fok, fak, aon } // عادي، MF، FOK، FAK، AON

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
  final ExecutionRule executionRule; // قاعدة التنفيذ (Regular, MF, FOK, FAK, AON)
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
    this.executionRule = ExecutionRule.regular,
    this.custodianBank = 'البنك التجاري الدولي (CIB)',
    required this.currency,
    required this.timestamp,
    this.status = OrderStatus.pending,
  });

  bool get isConditional => minimumBlockQuantity != null && minimumBlockQuantity! > 0;
  double get totalValue => targetPrice * quantity;

  String get executionRuleAr {
    switch (executionRule) {
      case ExecutionRule.regular:
        return 'عادي (Regular)';
      case ExecutionRule.mf:
        return 'الحد الأدنى للتنفيذ (MF)';
      case ExecutionRule.fok:
        return 'تنفيذ فوري بالكامل أو إلغاء (FOK)';
      case ExecutionRule.fak:
        return 'تنفيذ المتاح وإلغاء الباقي (FAK)';
      case ExecutionRule.aon:
        return 'الكل أو لا شيء (AON)';
    }
  }

  String get executionRuleShort {
    switch (executionRule) {
      case ExecutionRule.regular:
        return 'Regular';
      case ExecutionRule.mf:
        return 'MF';
      case ExecutionRule.fok:
        return 'FOK';
      case ExecutionRule.fak:
        return 'FAK';
      case ExecutionRule.aon:
        return 'AON';
    }
  }
}

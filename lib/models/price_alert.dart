enum AlertCondition { risesAbove, fallsBelow }

class PriceAlert {
  final String id;
  final String symbol;
  final String stockNameAr;
  final double targetPrice;
  final AlertCondition condition;
  final String currency;
  final DateTime createdAt;
  bool isTriggered;

  PriceAlert({
    required this.id,
    required this.symbol,
    required this.stockNameAr,
    required this.targetPrice,
    required this.condition,
    required this.currency,
    required this.createdAt,
    this.isTriggered = false,
  });

  String get conditionTextAr {
    return condition == AlertCondition.risesAbove
        ? 'عند ارتفاع السعر إلى أو أعلى من'
        : 'عند انخفاض السعر إلى أو أقل من';
  }
}

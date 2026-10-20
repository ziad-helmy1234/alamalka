class PortfolioHolding {
  final String symbol;
  final String stockName;
  final String stockNameAr;
  final int quantity;
  final double averageBuyPrice;
  final double currentPrice;
  final String currency; // 'EGP' or 'USD'

  PortfolioHolding({
    required this.symbol,
    required this.stockName,
    required this.stockNameAr,
    required this.quantity,
    required this.averageBuyPrice,
    required this.currentPrice,
    required this.currency,
  });

  double get totalInvested => quantity * averageBuyPrice;
  double get currentValue => quantity * currentPrice;
  double get totalGainLoss => currentValue - totalInvested;
  double get percentageGainLoss =>
      totalInvested == 0 ? 0 : (totalGainLoss / totalInvested) * 100;
}

class PortfolioSummary {
  final double egpCashBalance;
  final double egpBuyingPower;
  final List<PortfolioHolding> egpHoldings;

  final double usdCashBalance;
  final double usdBuyingPower;
  final List<PortfolioHolding> usdHoldings;

  PortfolioSummary({
    required this.egpCashBalance,
    required this.egpBuyingPower,
    required this.egpHoldings,
    required this.usdCashBalance,
    required this.usdBuyingPower,
    required this.usdHoldings,
  });

  double get egpHoldingsValue =>
      egpHoldings.fold(0.0, (sum, h) => sum + h.currentValue);
  double get egpTotalValue => egpCashBalance + egpHoldingsValue;

  double get usdHoldingsValue =>
      usdHoldings.fold(0.0, (sum, h) => sum + h.currentValue);
  double get usdTotalValue => usdCashBalance + usdHoldingsValue;
}

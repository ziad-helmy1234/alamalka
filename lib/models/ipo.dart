class IPORippleEffect {
  final String ipoSymbol;
  final String companyName;
  final String companyNameAr;
  final String sector;
  final String sectorAr;
  final double expectedPriceRangeMin;
  final double expectedPriceRangeMax;
  final double targetFundingEgp;
  final DateTime subscriptionStartDate;
  final DateTime subscriptionEndDate;
  
  // Ripple Effect Analysis
  final double liquiditySiphonImpactScore; // 0.0 to 10.0
  final String marketImpactSummaryAr;
  final String marketImpactSummaryEn;
  final List<String> affectedSectorsAr;
  final List<String> affectedPortfolioStocks; // Symbols in portfolio that might experience liquidity dip
  final String actionableInsightAr;
  final String actionableInsightEn;

  IPORippleEffect({
    required this.ipoSymbol,
    required this.companyName,
    required this.companyNameAr,
    required this.sector,
    required this.sectorAr,
    required this.expectedPriceRangeMin,
    required this.expectedPriceRangeMax,
    required this.targetFundingEgp,
    required this.subscriptionStartDate,
    required this.subscriptionEndDate,
    required this.liquiditySiphonImpactScore,
    required this.marketImpactSummaryAr,
    required this.marketImpactSummaryEn,
    required this.affectedSectorsAr,
    required this.affectedPortfolioStocks,
    required this.actionableInsightAr,
    required this.actionableInsightEn,
  });
}

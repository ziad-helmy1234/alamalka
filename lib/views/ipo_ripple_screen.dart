import 'package:flutter/material.dart';
import '../models/ipo.dart';
import '../services/stock_service.dart';
import '../theme/app_theme.dart';

class IPORippleScreen extends StatelessWidget {
  const IPORippleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final StockService stockService = StockService();
    final ipoEffects = stockService.getUpcomingIPORippleEffects();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: AppColors.goldSharia),
            SizedBox(width: 8),
            Text('تتبع تأثير الطروحات (IPO Ripple Effect)'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // USP Header Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentBlue.withOpacity(0.3),
                    AppColors.cardDark,
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.accentBlue.withOpacity(0.5),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.stars, color: AppColors.goldSharia, size: 22),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'خاصية استباقية حصرية (Market Gap USP)',
                          style: TextStyle(
                            color: AppColors.goldSharia,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'تحليل تأثير الطروحات الأولية الجديدة (IPO Ripple Effect) على سيولة السوق وتعديل أسعار الأسهم والقطاعات المتأثرة في محفظتك.',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'الطروحات الأولية القادمة والتحليل الاستباقي',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // IPO Ripple Effect Cards
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ipoEffects.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final ipo = ipoEffects[index];
                return _buildIPORippleCard(ipo);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIPORippleCard(IPORippleEffect ipo) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IPO Company Info
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.accentBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          ipo.ipoSymbol,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ipo.companyNameAr,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ipo.sectorAr,
                              style: const TextStyle(
                                  color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.waves, color: Colors.orange, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'مؤشر السحب: ${ipo.liquiditySiphonImpactScore}/10',
                        style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: AppColors.borderDark, height: 24),

            // Target Funding & Price Range
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildInfoCol('الحجم المستهدف للطرح',
                      '${(ipo.targetFundingEgp / 1000000000).toStringAsFixed(1)} مليار جنيه'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoCol('نطاق السعر المتوقع',
                      '${ipo.expectedPriceRangeMin} - ${ipo.expectedPriceRangeMax} EGP'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Market Impact Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: AppColors.accentBlue, size: 16),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'تحليل تأثير السيولة (Market Liquidity Impact):',
                          style: TextStyle(
                              color: AppColors.accentBlue,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ipo.marketImpactSummaryAr,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Affected Portfolio Stocks Alert
            if (ipo.affectedPortfolioStocks.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.redNegative.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.redNegative.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.redNegative, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تنبيه محفظتك: الأسهم المتأثرة مؤقتاً بالسيولة لديك: ${ipo.affectedPortfolioStocks.join(', ')}',
                        style: const TextStyle(
                          color: AppColors.redNegative,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),

            // Actionable Trading Insight
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.greenPositive.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.greenPositive.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline,
                      color: AppColors.greenPositive, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'توصية المستشار الاستراتيجي: ${ipo.actionableInsightAr}',
                      style: const TextStyle(
                        color: AppColors.greenPositive,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCol(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      ],
    );
  }
}

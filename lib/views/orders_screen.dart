import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/stock_service.dart';
import '../theme/app_theme.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final StockService stockService = StockService();
    final orders = stockService.orders;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.assignment_outlined, color: AppColors.accentBlue),
            SizedBox(width: 8),
            Text('سجل قائمة الأوامر (Orders)'),
          ],
        ),
      ),
      body: orders.isEmpty
          ? const Center(
              child: Text('لا توجد أوامر منفذة أو معلقة حالياً'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final order = orders[index];
                final isBuy = order.side == OrderSide.buy;
                final sideColor = isBuy
                    ? AppColors.greenPositive
                    : AppColors.redNegative;

                String validityText = 'أمر يومي (Day)';
                if (order.validity == OrderValidity.gtc) {
                  validityText = 'حتى الإلغاء (GTC)';
                } else if (order.validity == OrderValidity.gtd &&
                    order.validUntilDate != null) {
                  validityText =
                      'صالح حتى: ${order.validUntilDate!.day}/${order.validUntilDate!.month}/${order.validUntilDate!.year} (GTD)';
                }

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: sideColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isBuy ? 'شراء' : 'بيع',
                                      style: TextStyle(
                                        color: sideColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      order.symbol,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusBadge(order.status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          order.stockName,
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.account_balance,
                                size: 14, color: AppColors.accentBlue),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'أمين الحفظ: ${order.custodianBank}',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.accentBlue),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Divider(color: Theme.of(context).dividerColor, height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'الكمية: ${order.quantity} سهم',
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text(
                              'السعر: ${order.targetPrice.toStringAsFixed(2)} ${order.currency}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'نوع السعر: ${order.type == OrderType.limit ? "سعر حد (Limit)" : "سعر السوق (Market)"}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              'الصلاحية: $validityText',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    Color bg = AppColors.borderDark;
    String text = 'معلق';
    Color textColor = AppColors.textPrimaryDark;

    switch (status) {
      case OrderStatus.pending:
        bg = Colors.amber.withOpacity(0.2);
        text = 'قيد التنفيذ (معلق)';
        textColor = Colors.amber;
        break;
      case OrderStatus.executed:
        bg = AppColors.greenPositive.withOpacity(0.2);
        text = 'تم التنفيذ';
        textColor = AppColors.greenPositive;
        break;
      case OrderStatus.cancelled:
        bg = AppColors.redNegative.withOpacity(0.2);
        text = 'ملغى';
        textColor = AppColors.redNegative;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: textColor, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}

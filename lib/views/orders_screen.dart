import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/stock_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_language.dart';
import 'order_modal.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final StockService _stockService = StockService();

  void _cancelOrder(Order order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.redNegative),
            const SizedBox(width: 8),
            Text(AppStrings.cancelOrder),
          ],
        ),
        content: Text(AppLanguage.isArabic
            ? 'هل أنت مؤكد من إلغاء الأمر ${order.id} لشراء/بيع سهم ${order.symbol}؟ سيتم إعادة القوة الشرائية المتبقية إلى محفظتك.'
            : 'Are you sure you want to cancel order ${order.id} for ${order.symbol}? Remaining buying power will be refunded.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.back),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.redNegative),
            onPressed: () {
              Navigator.pop(ctx);
              final success = _stockService.cancelOrder(order.id);
              if (success) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLanguage.isArabic
                        ? 'تم إلغاء الأمر ${order.id} بنجاح وإعادة القوة الشرائية!'
                        : 'Order ${order.id} cancelled successfully!'),
                    backgroundColor: AppColors.greenPositive,
                  ),
                );
              }
            },
            child: Text(AppLanguage.isArabic ? 'تأكيد الإلغاء' : 'Confirm Cancel',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _editOrder(Order order) {
    final stock = _stockService.allStocks.firstWhere(
      (s) => s.symbol == order.symbol,
      orElse: () => _stockService.allStocks.first,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => OrderModal(
        stock: stock,
        initialSide: order.side,
        existingOrder: order,
      ),
    ).then((_) {
      setState(() {});
    });
  }

  void _showOrderDetailsSheet(Order order) {
    final isBuy = order.side == OrderSide.buy;
    final sideColor = isBuy ? AppColors.greenPositive : AppColors.redNegative;

    String validityText = AppStrings.dayOrder;
    if (order.validity == OrderValidity.gtc) {
      validityText = AppStrings.gtcOrder;
    } else if (order.validity == OrderValidity.gtd &&
        order.validUntilDate != null) {
      validityText = AppLanguage.isArabic
          ? 'صالح حتى: ${order.validUntilDate!.day}/${order.validUntilDate!.month}/${order.validUntilDate!.year}'
          : 'Valid until: ${order.validUntilDate!.day}/${order.validUntilDate!.month}/${order.validUntilDate!.year}';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sheet Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: sideColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isBuy ? AppStrings.buy : AppStrings.sell,
                        style: TextStyle(
                          color: sideColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${order.symbol} (${order.id})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                _buildStatusBadge(order.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(AppLanguage.isArabic ? order.stockName : order.symbol,
                style: const TextStyle(fontSize: 13)),
            Divider(color: Theme.of(context).dividerColor, height: 24),

            // Parameters Grid
            _buildDetailRow(
                AppLanguage.isArabic ? 'اسم السهم والرمز' : 'Symbol & Stock',
                '${AppLanguage.isArabic ? order.stockName : order.symbol} (${order.symbol})'),
            _buildDetailRow(
                AppStrings.pricingMode,
                order.type == OrderType.limit
                    ? AppStrings.limitPrice
                    : AppStrings.marketPrice),
            _buildDetailRow(AppStrings.executionRule,
                AppLanguage.isArabic ? order.executionRuleAr : order.executionRuleShort),
            _buildDetailRow(AppStrings.targetPriceLabel,
                '${order.targetPrice.toStringAsFixed(2)} ${order.currency}'),
            _buildDetailRow(AppStrings.quantityLabel, '${order.quantity}'),
            if (order.isConditional)
              _buildDetailRow(AppStrings.fillBlockSize,
                  '${order.minimumBlockQuantity} ${AppLanguage.isArabic ? "سهم" : "shares"}'),
            _buildDetailRow(AppStrings.totalOrderValue,
                '${order.totalValue.toStringAsFixed(2)} ${order.currency}'),
            _buildDetailRow(AppStrings.custodianBank, order.custodianBank),
            _buildDetailRow(AppStrings.orderDuration, validityText),
            _buildDetailRow(
                AppLanguage.isArabic ? 'وقت إنشاء الأمر' : 'Created Time',
                '${order.timestamp.hour}:${order.timestamp.minute.toString().padLeft(2, '0')} - ${order.timestamp.day}/${order.timestamp.month}/${order.timestamp.year}'),

            const SizedBox(height: 16),

            // Action Buttons for Pending Orders
            if (order.status == OrderStatus.pending) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.accentBlue),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.edit_note, color: AppColors.accentBlue),
                      label: Text(AppStrings.editOrder,
                          style: const TextStyle(
                              color: AppColors.accentBlue,
                              fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _editOrder(order);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.redNegative,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.cancel_outlined, color: Colors.white),
                      label: Text(AppStrings.cancelOrder,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _cancelOrder(order);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = _stockService.orders;

    return ValueListenableBuilder<Locale>(
      valueListenable: AppLanguage.localeNotifier,
      builder: (context, locale, _) {
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Icon(Icons.assignment_outlined, color: AppColors.accentBlue),
                const SizedBox(width: 8),
                Text(AppStrings.orderHistoryTitle),
              ],
            ),
          ),
          body: orders.isEmpty
              ? Center(
                  child: Text(AppStrings.noOrders),
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

                    String validityText = AppStrings.dayOrder;
                    if (order.validity == OrderValidity.gtc) {
                      validityText = AppStrings.gtcOrder;
                    } else if (order.validity == OrderValidity.gtd &&
                        order.validUntilDate != null) {
                      validityText = AppLanguage.isArabic
                          ? 'صالح حتى: ${order.validUntilDate!.day}/${order.validUntilDate!.month}/${order.validUntilDate!.year}'
                          : 'Valid: ${order.validUntilDate!.day}/${order.validUntilDate!.month}/${order.validUntilDate!.year}';
                    }

                    return Card(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _showOrderDetailsSheet(order),
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
                                            isBuy ? AppStrings.buy : AppStrings.sell,
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
                                            '${order.symbol} (${order.id})',
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
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    AppLanguage.isArabic ? order.stockName : order.symbol,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentBlue.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${AppLanguage.isArabic ? "قاعدة" : "Rule"}: ${order.executionRuleShort}',
                                          style: const TextStyle(
                                              color: AppColors.accentBlue,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      if (order.isConditional) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.goldSharia.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${AppLanguage.isArabic ? "دفعة" : "Block"} ${order.minimumBlockQuantity}',
                                            style: const TextStyle(
                                                color: AppColors.goldSharia,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.account_balance,
                                      size: 14, color: AppColors.accentBlue),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${AppStrings.custodianBank}: ${order.custodianBank}',
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
                                    '${AppLanguage.isArabic ? "الكمية" : "Qty"}: ${order.quantity}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  Text(
                                    '${AppLanguage.isArabic ? "السعر" : "Price"}: ${order.targetPrice.toStringAsFixed(2)} ${order.currency}',
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
                                    '${AppStrings.pricingMode}: ${order.type == OrderType.limit ? AppStrings.limitPrice : AppStrings.marketPrice}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  Text(
                                    '${AppStrings.orderDuration}: $validityText',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),

                              // Quick Action Buttons for Pending Orders on Card
                              if (order.status == OrderStatus.pending) ...[
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      icon: const Icon(Icons.edit_note,
                                          size: 16, color: AppColors.accentBlue),
                                      label: Text(AppStrings.editOrder,
                                          style: const TextStyle(
                                              color: AppColors.accentBlue,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold)),
                                      onPressed: () => _editOrder(order),
                                    ),
                                    const SizedBox(width: 12),
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      icon: const Icon(Icons.cancel_outlined,
                                          size: 16, color: AppColors.redNegative),
                                      label: Text(AppStrings.cancelOrder,
                                          style: const TextStyle(
                                              color: AppColors.redNegative,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold)),
                                      onPressed: () => _cancelOrder(order),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildStatusBadge(OrderStatus status) {
    Color bg = AppColors.borderDark;
    String text = AppStrings.orderPending;
    Color textColor = AppColors.textPrimaryDark;

    switch (status) {
      case OrderStatus.pending:
        bg = Colors.amber.withOpacity(0.2);
        text = AppStrings.orderPending;
        textColor = Colors.amber;
        break;
      case OrderStatus.executed:
        bg = AppColors.greenPositive.withOpacity(0.2);
        text = AppStrings.orderExecuted;
        textColor = AppColors.greenPositive;
        break;
      case OrderStatus.cancelled:
        bg = AppColors.redNegative.withOpacity(0.2);
        text = AppStrings.orderCancelled;
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

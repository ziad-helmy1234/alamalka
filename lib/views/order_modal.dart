import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../models/order.dart';
import '../services/stock_service.dart';
import '../theme/app_theme.dart';

class OrderModal extends StatefulWidget {
  final Stock stock;
  final OrderSide initialSide;

  const OrderModal({
    super.key,
    required this.stock,
    required this.initialSide,
  });

  @override
  State<OrderModal> createState() => _OrderModalState();
}

class _OrderModalState extends State<OrderModal> {
  final StockService _stockService = StockService();
  late OrderSide _side;
  OrderType _orderType = OrderType.limit;
  OrderValidity _validity = OrderValidity.gtc;

  final TextEditingController _quantityController =
      TextEditingController(text: '100');
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _side = widget.initialSide;
    _priceController = TextEditingController(
      text: widget.stock.currentPrice.toStringAsFixed(2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final portfolio = _stockService.getPortfolioSummary();
    final buyingPower = widget.stock.currency == 'EGP'
        ? portfolio.egpBuyingPower
        : portfolio.usdBuyingPower;

    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final price = _orderType == OrderType.market
        ? widget.stock.currentPrice
        : (double.tryParse(_priceController.text) ?? 0.0);
    final totalCost = quantity * price;
    final hasEnoughPower =
        _side == OrderSide.sell || totalCost <= buyingPower;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تنفيذ امر ${_side == OrderSide.buy ? "شراء" : "بيع"} (${widget.stock.symbol})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Side Selector (Buy / Sell Toggle)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _side = OrderSide.buy),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _side == OrderSide.buy
                          ? AppColors.greenPositive
                          : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: const Center(
                      child: Text('شراء',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _side = OrderSide.sell),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _side == OrderSide.sell
                          ? AppColors.redNegative
                          : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: const Center(
                      child: Text('بيع',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Order Type Selector (Market Price vs Limit Price)
          const Text('نوع السعر (Pricing Mode)',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('سعر حد (Limit Price)'),
                  selected: _orderType == OrderType.limit,
                  onSelected: (val) {
                    if (val) setState(() => _orderType = OrderType.limit);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text('سعر السوق (Market Price)'),
                  selected: _orderType == OrderType.market,
                  onSelected: (val) {
                    if (val) setState(() => _orderType = OrderType.market);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Quantity & Price Inputs
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'الكمية (عدد الأسهم)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              if (_orderType == OrderType.limit) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'السعر المستهدف (${widget.stock.currency})',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Order Validity (Day vs GTC)
          const Text('صلاحية الأمر (Order Duration)',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              ChoiceChip(
                label: const Text('حتى الإلغاء (GTC)'),
                selected: _validity == OrderValidity.gtc,
                onSelected: (val) {
                  if (val) setState(() => _validity = OrderValidity.gtc);
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('أمر يومي (Day Order)'),
                selected: _validity == OrderValidity.day,
                onSelected: (val) {
                  if (val) setState(() => _validity = OrderValidity.day);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Summary & Buying Power Check
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('القوة الشرائية المتاحة:'),
                    Text(
                      '${buyingPower.toStringAsFixed(2)} ${widget.stock.currency}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('إجمالي قيمة الأمر:'),
                    Text(
                      '${totalCost.toStringAsFixed(2)} ${widget.stock.currency}',
                      style: TextStyle(
                        color: hasEnoughPower
                            ? AppColors.greenPositive
                            : AppColors.redNegative,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _side == OrderSide.buy
                    ? AppColors.greenPositive
                    : AppColors.redNegative,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: !hasEnoughPower && _side == OrderSide.buy
                  ? null
                  : () {
                      final order = Order(
                        id: 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                        symbol: widget.stock.symbol,
                        stockName: widget.stock.nameAr,
                        type: _orderType,
                        side: _side,
                        targetPrice: price,
                        quantity: quantity,
                        validity: _validity,
                        currency: widget.stock.currency,
                        timestamp: DateTime.now(),
                      );

                      final success = _stockService.placeOrder(order);
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? 'تم إرسال الأمر بنجاح!'
                                : 'عذراً، القوة الشرائية غير كافية لتنفيذ الأمر.',
                          ),
                          backgroundColor: success
                              ? AppColors.greenPositive
                              : AppColors.redNegative,
                        ),
                      );
                    },
              child: Text(
                'تأكيد أمر ${_side == OrderSide.buy ? "الشراء" : "البيع"}',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

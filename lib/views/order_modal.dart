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
  DateTime? _selectedGtdDate;

  final List<String> _custodianBanks = [
    'البنك التجاري الدولي (CIB Custody)',
    'البنك الأهلي المصري (NBE Custody)',
    'بنك مصر (Banque Misr Custody)',
    'إي إف جي هيرميس للحفظ (EFG Hermes)',
    'بنك قطر الوطني (QNB Alahli)',
    'الأهلي كابيتال للحفظ (Al Ahli Capital)',
  ];

  late String _selectedCustodianBank;

  final TextEditingController _quantityController =
      TextEditingController(text: '100');
  late TextEditingController _priceController;

  @override
  void initState() {
    super.initState();
    _side = widget.initialSide;
    _selectedCustodianBank = _custodianBanks.first;
    _priceController = TextEditingController(
      text: widget.stock.currentPrice.toStringAsFixed(2),
    );
    _selectedGtdDate = DateTime.now().add(const Duration(days: 14));
  }

  Future<void> _pickGtdDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedGtdDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      builder: (context, child) {
        return Theme(
          data: AppTheme.isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme,
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedGtdDate = picked;
      });
    }
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

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تنفيذ أمر ${_side == OrderSide.buy ? "شراء" : "بيع"} (${widget.stock.symbol})',
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

          // Scrollable Body for Vertical Safety
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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

                  // 1. Custodian Bank Selector (أمين الحفظ)
                  const Text('أمين الحفظ (Custodian Bank)',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedCustodianBank,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.account_balance,
                          color: AppColors.accentBlue, size: 20),
                    ),
                    items: _custodianBanks.map((bank) {
                      return DropdownMenuItem<String>(
                        value: bank,
                        child: Text(
                          bank,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedCustodianBank = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // 2. Pricing Mode (Limit Price vs Market Price)
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
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              labelText:
                                  'السعر المستهدف (${widget.stock.currency})',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3. Order Duration / Validity (Day, GTC, GTD - صالح حتى)
                  const Text('صلاحية الأمر (Order Duration)',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('أمر يومي (Day)'),
                          selected: _validity == OrderValidity.day,
                          onSelected: (val) {
                            if (val) setState(() => _validity = OrderValidity.day);
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('حتى الإلغاء (GTC)'),
                          selected: _validity == OrderValidity.gtc,
                          onSelected: (val) {
                            if (val) setState(() => _validity = OrderValidity.gtc);
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('صالح حتى تاريخ (GTD)'),
                          selected: _validity == OrderValidity.gtd,
                          onSelected: (val) {
                            if (val) {
                              setState(() => _validity = OrderValidity.gtd);
                              _pickGtdDate(context);
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  // GTD Selected Date Display
                  if (_validity == OrderValidity.gtd) ...[
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _pickGtdDate(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.accentBlue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.accentBlue, width: 0.8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.calendar_month,
                                    color: AppColors.accentBlue, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'صالح حتى تاريخ: ${_selectedGtdDate!.day}/${_selectedGtdDate!.month}/${_selectedGtdDate!.year}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accentBlue,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'تغيير التاريخ',
                              style: TextStyle(
                                  fontSize: 11,
                                  decoration: TextDecoration.underline,
                                  color: AppColors.accentBlue),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                                validUntilDate: _validity == OrderValidity.gtd
                                    ? _selectedGtdDate
                                    : null,
                                custodianBank: _selectedCustodianBank,
                                currency: widget.stock.currency,
                                timestamp: DateTime.now(),
                              );

                              final success = _stockService.placeOrder(order);
                              Navigator.pop(context);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? 'تم إرسال الأمر بنجاح بنك الحفظ: $_selectedCustodianBank!'
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
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

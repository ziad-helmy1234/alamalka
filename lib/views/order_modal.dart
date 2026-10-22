import 'package:flutter/material.dart';
import '../models/stock.dart';
import '../models/order.dart';
import '../services/stock_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_language.dart';

class OrderModal extends StatefulWidget {
  final Stock stock;
  final OrderSide initialSide;
  final Order? existingOrder;

  const OrderModal({
    super.key,
    required this.stock,
    required this.initialSide,
    this.existingOrder,
  });

  @override
  State<OrderModal> createState() => _OrderModalState();
}

class _OrderModalState extends State<OrderModal> {
  final StockService _stockService = StockService();
  late OrderSide _side;
  OrderType _orderType = OrderType.limit;
  OrderValidity _validity = OrderValidity.gtc;
  ExecutionRule _executionRule = ExecutionRule.regular;
  DateTime? _selectedGtdDate;
  bool _isConditional = false;

  final List<String> _custodianBanksAr = [
    'البنك التجاري الدولي',
    'البنك الأهلي المصري',
    'بنك مصر',
    'إي إف جي هيرميس للحفظ',
    'بنك قطر الوطني',
    'الأهلي كابيتال للحفظ',
  ];

  final List<String> _custodianBanksEn = [
    'Commercial International Bank (CIB)',
    'National Bank of Egypt (NBE)',
    'Banque Misr',
    'EFG Hermes Custody',
    'QNB Alahli Custody',
    'Al Ahli Capital Custody',
  ];

  late String _selectedCustodianBank;
  late TextEditingController _quantityController;
  late TextEditingController _priceController;
  late TextEditingController _minBlockController;

  @override
  void initState() {
    super.initState();
    final banks = AppLanguage.isArabic ? _custodianBanksAr : _custodianBanksEn;
    if (widget.existingOrder != null) {
      final o = widget.existingOrder!;
      _side = o.side;
      _orderType = o.type;
      _validity = o.validity;
      _executionRule = o.executionRule;
      _selectedGtdDate = o.validUntilDate ?? DateTime.now().add(const Duration(days: 14));
      _selectedCustodianBank = banks.contains(o.custodianBank)
          ? o.custodianBank
          : banks.first;
      _quantityController = TextEditingController(text: o.quantity.toString());
      _priceController = TextEditingController(text: o.targetPrice.toStringAsFixed(2));
      _isConditional = o.isConditional;
      _minBlockController = TextEditingController(
        text: o.minimumBlockQuantity?.toString() ?? '1000',
      );
    } else {
      _side = widget.initialSide;
      _selectedCustodianBank = banks.first;
      _quantityController = TextEditingController(text: '2000');
      _priceController = TextEditingController(
        text: widget.stock.currentPrice.toStringAsFixed(2),
      );
      _selectedGtdDate = DateTime.now().add(const Duration(days: 14));
      _isConditional = false;
      _executionRule = ExecutionRule.regular;
      _minBlockController = TextEditingController(text: '1000');
    }
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

  Widget _buildExecutionRuleExplanationBanner(ExecutionRule rule) {
    String text = '';
    if (AppLanguage.isArabic) {
      switch (rule) {
        case ExecutionRule.regular:
          text = 'تنفيذ عادي: ينفذ النظام الصفقات المتاحة فوراً ويقبل الصفقات الجزئية بأي كمية.';
          break;
        case ExecutionRule.mf:
          text = 'الحد الأدنى للتنفيذ: يشترط تنفيذ حد أدنى من الكمية فور دخول الأمر أو يلغى الأمر فوراً.';
          break;
        case ExecutionRule.fok:
          text = 'تنفيذ بالكامل فوراً أو إلغاء: ينفذ كامل كمية الأمر فوراً بالكامل، أو يلغى بالكامل فوراً.';
          break;
        case ExecutionRule.fak:
          text = 'تنفيذ المتاح وإلغاء الباقي: ينفذ أقصى كمية متاحة بالسعر المستهدف فوراً ويلغي أي كمية متبقية.';
          break;
        case ExecutionRule.aon:
          text = 'الكل أو لا شيء: ينفذ كامل كمية الأمر فقط بدون تنفيذ جزئي، ويسمح بالانتظار في دفتر الأوامر.';
          break;
      }
    } else {
      switch (rule) {
        case ExecutionRule.regular:
          text = 'Regular Fill: Executes available shares immediately and allows partial fills.';
          break;
        case ExecutionRule.mf:
          text = 'Minimum Fill (MF): Requires executing a minimum fill volume immediately or cancels order.';
          break;
        case ExecutionRule.fok:
          text = 'Fill or Kill (FOK): Executes total quantity immediately or cancels completely.';
          break;
        case ExecutionRule.fak:
          text = 'Fill and Kill (FAK): Fills available shares immediately and cancels remaining quantity.';
          break;
        case ExecutionRule.aon:
          text = 'All or None (AON): Requires total order quantity fill with no partial fills.';
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune_outlined, color: AppColors.accentBlue, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11, color: AppColors.accentBlue, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: AppLanguage.localeNotifier,
      builder: (context, locale, _) {
        final banks = AppLanguage.isArabic ? _custodianBanksAr : _custodianBanksEn;
        if (!banks.contains(_selectedCustodianBank)) {
          _selectedCustodianBank = banks.first;
        }

        final isEditing = widget.existingOrder != null;
        final portfolio = _stockService.getPortfolioSummary();
        final buyingPower = widget.stock.currency == 'EGP'
            ? portfolio.egpBuyingPower
            : portfolio.usdBuyingPower;

        final quantity = int.tryParse(_quantityController.text) ?? 0;
        final price = _orderType == OrderType.market
            ? widget.stock.currentPrice
            : (double.tryParse(_priceController.text) ?? 0.0);
        final totalCost = quantity * price;

        final double effectiveRequiredPower = isEditing
            ? totalCost - widget.existingOrder!.totalValue
            : totalCost;

        final hasEnoughPower =
            _side == OrderSide.sell || effectiveRequiredPower <= buyingPower;

        final minBlockVal = _isConditional
            ? (int.tryParse(_minBlockController.text) ?? 1000)
            : null;

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
                    isEditing
                        ? (AppLanguage.isArabic
                            ? 'تعديل أمر ${_side == OrderSide.buy ? "شراء" : "بيع"} (${widget.stock.symbol})'
                            : 'Edit ${_side == OrderSide.buy ? "Buy" : "Sell"} Order (${widget.stock.symbol})')
                        : (AppLanguage.isArabic
                            ? 'تنفيذ أمر ${_side == OrderSide.buy ? "شراء" : "بيع"} (${widget.stock.symbol})'
                            : 'Place ${_side == OrderSide.buy ? "Buy" : "Sell"} Order (${widget.stock.symbol})'),
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
                                child: Center(
                                  child: Text(AppStrings.buy,
                                      style: const TextStyle(
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
                                child: Center(
                                  child: Text(AppStrings.sell,
                                      style: const TextStyle(
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
                      Text(AppStrings.custodianBank,
                          style: const TextStyle(
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
                        items: banks.map((bank) {
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
                      Text(AppStrings.pricingMode,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: Text(AppStrings.limitPrice),
                              selected: _orderType == OrderType.limit,
                              onSelected: (val) {
                                if (val) setState(() => _orderType = OrderType.limit);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: Text(AppStrings.marketPrice),
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
                              decoration: InputDecoration(
                                labelText: AppStrings.quantityLabel,
                                border: const OutlineInputBorder(),
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
                                  labelText: '${AppStrings.targetPriceLabel} (${widget.stock.currency})',
                                  border: const OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 3. Execution Rule Selector (قاعدة التنفيذ)
                      Text(AppStrings.executionRule,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: Text(AppLanguage.isArabic ? 'عادي' : 'Regular'),
                              selected: _executionRule == ExecutionRule.regular,
                              onSelected: (val) {
                                if (val) setState(() => _executionRule = ExecutionRule.regular);
                              },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('MF'),
                              selected: _executionRule == ExecutionRule.mf,
                              onSelected: (val) {
                                if (val) setState(() => _executionRule = ExecutionRule.mf);
                              },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('FOK'),
                              selected: _executionRule == ExecutionRule.fok,
                              onSelected: (val) {
                                if (val) setState(() => _executionRule = ExecutionRule.fok);
                              },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('FAK'),
                              selected: _executionRule == ExecutionRule.fak,
                              onSelected: (val) {
                                if (val) setState(() => _executionRule = ExecutionRule.fak);
                              },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('AON'),
                              selected: _executionRule == ExecutionRule.aon,
                              onSelected: (val) {
                                if (val) setState(() => _executionRule = ExecutionRule.aon);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildExecutionRuleExplanationBanner(_executionRule),
                      const SizedBox(height: 16),

                      // 4. Conditional Order - Minimum Fill Quantity / Block Size (أمر شرطي)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          AppStrings.fillBlockSize,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          AppLanguage.isArabic
                              ? 'يشترط عدم تنفيذ أي صفقات جزئية تقل عن الحد الأدنى لكمية الدفعة.'
                              : 'Disallows partial fills below the minimum specified batch quantity.',
                          style: const TextStyle(fontSize: 11),
                        ),
                        value: _isConditional,
                        activeThumbColor: AppColors.accentBlue,
                        onChanged: (val) {
                          setState(() {
                            _isConditional = val;
                          });
                        },
                      ),
                      if (_isConditional) ...[
                        const SizedBox(height: 6),
                        TextField(
                          controller: _minBlockController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: AppStrings.minBlockQuantity,
                            hintText: '1000',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.filter_alt_outlined,
                                color: AppColors.accentBlue),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accentBlue.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  color: AppColors.accentBlue, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  AppLanguage.isArabic
                                      ? 'تنبيه البورصة: لن يمنحك النظام صفقات صغيرة أقل من ${minBlockVal ?? 1000} سهم. يُنفذ الأمر فقط بهذه الدفعة كحد أدنى أو بالكامل ($quantity سهم).'
                                      : 'Minimum Fill Notice: Partial fills below ${minBlockVal ?? 1000} shares will be rejected.',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.accentBlue,
                                      height: 1.3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),

                      // 5. Order Duration / Validity (Day, GTC, GTD)
                      Text(AppStrings.orderDuration,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: Text(AppStrings.dayOrder),
                              selected: _validity == OrderValidity.day,
                              onSelected: (val) {
                                if (val) setState(() => _validity = OrderValidity.day);
                              },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: Text(AppStrings.gtcOrder),
                              selected: _validity == OrderValidity.gtc,
                              onSelected: (val) {
                                if (val) setState(() => _validity = OrderValidity.gtc);
                              },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: Text(AppStrings.gtdOrder),
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
                                      AppLanguage.isArabic
                                          ? 'صالح حتى تاريخ: ${_selectedGtdDate!.day}/${_selectedGtdDate!.month}/${_selectedGtdDate!.year}'
                                          : 'Valid until: ${_selectedGtdDate!.day}/${_selectedGtdDate!.month}/${_selectedGtdDate!.year}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.accentBlue,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  AppLanguage.isArabic ? 'تغيير التاريخ' : 'Change Date',
                                  style: const TextStyle(
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
                                Text(AppStrings.buyingPower),
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
                                Text(AppStrings.totalOrderValue),
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
                                  if (isEditing) {
                                    final updatedOrder = Order(
                                      id: widget.existingOrder!.id,
                                      symbol: widget.stock.symbol,
                                      stockName: widget.stock.nameAr,
                                      type: _orderType,
                                      side: _side,
                                      targetPrice: price,
                                      quantity: quantity,
                                      minimumBlockQuantity: minBlockVal,
                                      validity: _validity,
                                      validUntilDate: _validity == OrderValidity.gtd
                                          ? _selectedGtdDate
                                          : null,
                                      executionRule: _executionRule,
                                      custodianBank: _selectedCustodianBank,
                                      currency: widget.stock.currency,
                                      timestamp: widget.existingOrder!.timestamp,
                                      status: OrderStatus.pending,
                                    );

                                    final success = _stockService.editOrder(updatedOrder);
                                    Navigator.pop(context);

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          success
                                              ? (AppLanguage.isArabic
                                                  ? 'تم حفظ تعديلات الأمر بنجاح!'
                                                  : 'Order changes saved successfully!')
                                              : (AppLanguage.isArabic
                                                  ? 'عذراً، القوة الشرائية غير كافية لزيادة قيمة الأمر.'
                                                  : 'Insufficient buying power.'),
                                        ),
                                        backgroundColor: success
                                            ? AppColors.greenPositive
                                            : AppColors.redNegative,
                                      ),
                                    );
                                  } else {
                                    final order = Order(
                                      id: 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                                      symbol: widget.stock.symbol,
                                      stockName: widget.stock.nameAr,
                                      type: _orderType,
                                      side: _side,
                                      targetPrice: price,
                                      quantity: quantity,
                                      minimumBlockQuantity: minBlockVal,
                                      validity: _validity,
                                      validUntilDate: _validity == OrderValidity.gtd
                                          ? _selectedGtdDate
                                          : null,
                                      executionRule: _executionRule,
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
                                              ? (AppLanguage.isArabic
                                                  ? 'تم إرسال الأمر بنجاح!'
                                                  : 'Order placed successfully!')
                                              : (AppLanguage.isArabic
                                                  ? 'عذراً، القوة الشرائية غير كافية لتنفيذ الأمر.'
                                                  : 'Insufficient buying power.'),
                                        ),
                                        backgroundColor: success
                                            ? AppColors.greenPositive
                                            : AppColors.redNegative,
                                      ),
                                    );
                                  }
                                },
                          child: Text(
                            isEditing
                                ? AppStrings.saveChanges
                                : (AppLanguage.isArabic
                                    ? 'تأكيد أمر ${_side == OrderSide.buy ? "الشراء" : "البيع"}'
                                    : 'Confirm ${_side == OrderSide.buy ? "Buy" : "Sell"} Order'),
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
      },
    );
  }
}

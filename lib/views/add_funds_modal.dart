import 'package:flutter/material.dart';
import '../services/stock_service.dart';
import '../theme/app_theme.dart';

class AddFundsModal extends StatefulWidget {
  final String initialCurrency;

  const AddFundsModal({super.key, this.initialCurrency = 'EGP'});

  @override
  State<AddFundsModal> createState() => _AddFundsModalState();
}

class _AddFundsModalState extends State<AddFundsModal> {
  final StockService _stockService = StockService();
  late String _currency;
  String _selectedMethod = 'InstaPay';
  final TextEditingController _amountController =
      TextEditingController(text: '25000');

  final List<Map<String, String>> _methods = [
    {'name': 'InstaPay', 'desc': 'إيداع لحظي بدون رسوم'},
    {'name': 'تحويل بنكي مباشر', 'desc': 'تحويل لحساب الشركة بالبنك الأهلي/CIB'},
    {'name': 'بطاقة مصرفية (Card)', 'desc': 'خصم مباشر / بطاقة ائتمان'},
    {'name': 'فودافون كاش / محفظة ذكية', 'desc': 'تحويل سريع عبر المحفظة'},
  ];

  @override
  void initState() {
    super.initState();
    _currency = widget.initialCurrency;
  }

  @override
  Widget build(BuildContext context) {
    final double amount = double.tryParse(_amountController.text) ?? 0.0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.add_card, color: AppColors.greenPositive, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'إضافة أموال للمحفظة (Deposit)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Divider(color: Theme.of(context).dividerColor, height: 16),

          // Scrollable Body for Vertical Safety
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Currency Toggle
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(
                            child: Text('الجنيه المصري (EGP)',
                                style: TextStyle(fontSize: 12)),
                          ),
                          selected: _currency == 'EGP',
                          selectedColor: AppColors.accentBlue.withOpacity(0.3),
                          onSelected: (val) {
                            if (val) setState(() => _currency = 'EGP');
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(
                            child: Text('الدولار الأمريكي (USD)',
                                style: TextStyle(fontSize: 12)),
                          ),
                          selected: _currency == 'USD',
                          selectedColor: AppColors.accentBlue.withOpacity(0.3),
                          onSelected: (val) {
                            if (val) setState(() => _currency = 'USD');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quick Amount Chips
                  const Text('اختر المبلغ أو أدخل القيمة:',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: (_currency == 'EGP'
                              ? ['10000', '25000', '50000', '100000']
                              : ['500', '1000', '2500', '5000'])
                          .map((val) => Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: ActionChip(
                                  label: Text(
                                    '+${double.parse(val).toStringAsFixed(0)} $_currency',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  backgroundColor: AppColors.accentBlue.withOpacity(0.15),
                                  onPressed: () {
                                    setState(() {
                                      _amountController.text = val;
                                    });
                                  },
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Custom Amount TextField
                  TextField(
                    controller: _amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      labelText: 'قيمة الإيداع ($_currency)',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.attach_money,
                          color: AppColors.greenPositive),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Payment Method Selector
                  const Text('طريقة الإيداع المفضلة:',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._methods.map(
                    (m) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: _selectedMethod == m['name']
                            ? AppColors.accentBlue.withOpacity(0.15)
                            : Theme.of(context).cardColor,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: _selectedMethod == m['name']
                                ? AppColors.accentBlue
                                : Theme.of(context).dividerColor,
                          ),
                        ),
                        child: RadioListTile<String>(
                          value: m['name']!,
                          groupValue: _selectedMethod,
                          dense: true,
                          title: Text(
                            m['name']!,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            m['desc']!,
                            style: const TextStyle(
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          activeColor: AppColors.accentBlue,
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedMethod = val);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.greenPositive,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: amount <= 0
                          ? null
                          : () {
                              _stockService.addFunds(
                                  _currency, amount, _selectedMethod);
                              Navigator.pop(context);

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'تم إيداع $amount $_currency بنجاح في محفظتك عبر $_selectedMethod!',
                                  ),
                                  backgroundColor: AppColors.greenPositive,
                                ),
                              );
                            },
                      child: Text(
                        'تأكيد إيداع ${amount.toStringAsFixed(2)} $_currency',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                        overflow: TextOverflow.ellipsis,
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

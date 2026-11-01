import 'package:flutter/material.dart';
import '../services/stock_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_language.dart';

class CardPaymentScreen extends StatefulWidget {
  final double amount;
  final String currency;
  final String method;

  const CardPaymentScreen({
    super.key,
    required this.amount,
    required this.currency,
    required this.method,
  });

  @override
  State<CardPaymentScreen> createState() => _CardPaymentScreenState();
}

class _CardPaymentScreenState extends State<CardPaymentScreen> {
  final StockService _stockService = StockService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _cardNumberController =
      TextEditingController(text: '4532 8910 2341 8920');
  final TextEditingController _expiryController =
      TextEditingController(text: '08/28');
  final TextEditingController _cvvController =
      TextEditingController(text: '382');
  final TextEditingController _nameController =
      TextEditingController(text: 'Ziad Ahmed');

  bool _isProcessing = false;

  void _processCardPayment() {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isProcessing = true;
    });

    // Show 3D Secure Bank Verification Modal (NBE / CIB / Banque Misr 3DS)
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _show3DSecureOtpModal();
    });
  }

  void _show3DSecureOtpModal() {
    final otpController = TextEditingController(text: '892104');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setOtpState) => ValueListenableBuilder<ThemeMode>(
          valueListenable: AppTheme.themeNotifier,
          builder: (context, mode, _) {
            final isDark = mode == ThemeMode.dark;
            final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
            final onSurface = isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight;

            return Material(
              color: cardBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
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
                        Row(
                          children: [
                            const Icon(Icons.verified_user,
                                color: AppColors.accentBlue, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              AppLanguage.isArabic
                                  ? 'تأكيد الحماية الثلاثية (3D Secure OTP)'
                                  : '3D Secure Bank Verification',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: onSurface,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: onSurface),
                          onPressed: () {
                            setState(() => _isProcessing = false);
                            Navigator.pop(ctx);
                          },
                        ),
                      ],
                    ),
                    Divider(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accentBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance,
                              color: AppColors.accentBlue, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              AppLanguage.isArabic
                                  ? 'تم إرسال كود التأكيد OTP عبر الرسائل القصيرة إلى هاتفك المسجل ببنك الإصدار لخصم ${widget.amount.toStringAsFixed(2)} ${widget.currency}.'
                                  : 'An OTP security code was sent to your registered bank mobile to authorize ${widget.amount.toStringAsFixed(2)} ${widget.currency}.',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.accentBlue,
                                  height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: otpController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                      ),
                      decoration: InputDecoration(
                        labelText: AppLanguage.isArabic
                            ? 'أدخل كود التأكيد OTP'
                            : 'Enter 6-Digit Bank OTP',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.pin),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.greenPositive,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          // Complete deposit!
                          _stockService.addFunds(
                              widget.currency, widget.amount, widget.method);

                          Navigator.pop(ctx); // close OTP modal
                          Navigator.pop(context, true); // return success

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppLanguage.isArabic
                                    ? 'تم خصم وتأكيد إيداع ${widget.amount.toStringAsFixed(2)} ${widget.currency} بنجاح بكارتك المصرفي!'
                                    : 'Successfully deposited ${widget.amount.toStringAsFixed(2)} ${widget.currency} via Card!',
                              ),
                              backgroundColor: AppColors.greenPositive,
                            ),
                          );
                        },
                        child: Text(
                          AppLanguage.isArabic
                              ? 'تأكيد ودفع ${widget.amount.toStringAsFixed(2)} ${widget.currency}'
                              : 'Confirm & Authorize ${widget.amount.toStringAsFixed(2)} ${widget.currency}',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: AppLanguage.localeNotifier,
      builder: (context, locale, _) {
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Icon(Icons.credit_card, color: AppColors.accentBlue),
                const SizedBox(width: 8),
                Text(
                  AppLanguage.isArabic
                      ? 'الدفع المباشر بالبطاقة المصرفية'
                      : 'Card Payment Checkout',
                ),
              ],
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Payment Summary Banner Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLanguage.isArabic
                                    ? 'المبلغ المطلوب إيداعه'
                                    : 'Deposit Amount',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.amount.toStringAsFixed(2)} ${widget.currency}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.greenPositive,
                                ),
                              ),
                            ],
                          ),
                          const Row(
                            children: [
                              Icon(Icons.payment,
                                  size: 28, color: AppColors.accentBlue),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    AppLanguage.isArabic
                        ? 'إدخال بيانات البطاقة المصرفية'
                        : 'Enter Card Details',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Card Number
                  TextFormField(
                    controller: _cardNumberController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: AppLanguage.isArabic
                          ? 'رقم البطاقة (16 رقم)'
                          : 'Card Number (16 digits)',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.credit_card),
                      suffixIcon: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.verified, color: AppColors.accentBlue),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().length < 12) {
                        return AppLanguage.isArabic
                            ? 'يرجى إدخال رقم بطاقة صحيح'
                            : 'Enter a valid card number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Expiry Date & CVV
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _expiryController,
                          keyboardType: TextInputType.datetime,
                          decoration: InputDecoration(
                            labelText: AppLanguage.isArabic
                                ? 'تاريخ الانتهاء (MM/YY)'
                                : 'Expiry Date (MM/YY)',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.calendar_today),
                          ),
                          validator: (val) {
                            if (val == null || !val.contains('/')) {
                              return AppLanguage.isArabic
                                  ? 'صيغة خاطئة (MM/YY)'
                                  : 'Invalid format (MM/YY)';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _cvvController,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: AppLanguage.isArabic
                                ? 'رمز الأمان (CVV)'
                                : 'Security Code (CVV)',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock_outline),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().length < 3) {
                              return AppLanguage.isArabic
                                  ? 'رمز CVV خاطئ'
                                  : 'Invalid CVV';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Cardholder Name
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: AppLanguage.isArabic
                          ? 'اسم صاحب البطاقة'
                          : 'Cardholder Name',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return AppLanguage.isArabic
                            ? 'يرجى إدخال اسم صاحب البطاقة'
                            : 'Enter cardholder name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Submit Payment Button
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
                      onPressed: _isProcessing ? null : _processCardPayment,
                      child: _isProcessing
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              AppLanguage.isArabic
                                  ? 'دفع ${widget.amount.toStringAsFixed(2)} ${widget.currency} وإكمال الإيداع'
                                  : 'Pay ${widget.amount.toStringAsFixed(2)} ${widget.currency} & Complete Deposit',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bank Encryption Trust Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock, size: 14, color: AppColors.accentBlue),
                      const SizedBox(width: 6),
                      Text(
                        AppLanguage.isArabic
                            ? 'معاملة مالية مشفرة بدقة 256-bit بواسطة البنك المركزي'
                            : '256-bit SSL Bank Encrypted Transaction',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.accentBlue),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

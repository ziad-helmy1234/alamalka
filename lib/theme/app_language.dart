import 'package:flutter/material.dart';

class AppLanguage {
  static final ValueNotifier<Locale> localeNotifier =
      ValueNotifier(const Locale('ar'));

  static bool get isArabic => localeNotifier.value.languageCode == 'ar';

  static void toggleLanguage() {
    localeNotifier.value = isArabic
        ? const Locale('en')
        : const Locale('ar');
  }

  static void setLanguage(String code) {
    localeNotifier.value = Locale(code);
  }
}

class AppStrings {
  // Navigation Tabs
  static String get marketsTab => AppLanguage.isArabic ? 'الأسواق' : 'Markets';
  static String get watchlistTab => AppLanguage.isArabic ? 'المراقبة' : 'Watchlist';
  static String get iposTab => AppLanguage.isArabic ? 'الطروحات' : 'IPOs';
  static String get portfolioTab => AppLanguage.isArabic ? 'المحفظة' : 'Portfolio';
  static String get ordersTab => AppLanguage.isArabic ? 'الأوامر' : 'Orders';
  static String get accountTab => AppLanguage.isArabic ? 'الحساب' : 'Account';

  // Markets Screen
  static String get marketsTitle => AppLanguage.isArabic ? 'الأسواق والاستكشاف' : 'Markets & Discovery';
  static String get searchTooltip => AppLanguage.isArabic ? 'البحث والتصنيفات' : 'Search & Sectors';
  static String get newsTooltip => AppLanguage.isArabic ? 'الأخبار والأحداث' : 'News & Events';
  static String get topGainers => AppLanguage.isArabic ? 'أعلى الأسهم ارتفاعاً' : 'Top Gainers';
  static String get topLosers => AppLanguage.isArabic ? 'أكثر الأسهم انخفاضاً' : 'Top Losers';
  static String get viewAll => AppLanguage.isArabic ? 'عرض الكل' : 'View All';
  static String get allListedStocks => AppLanguage.isArabic ? 'جميع الأسهم المقيدة' : 'All Listed Stocks';

  // Actions
  static String get buy => AppLanguage.isArabic ? 'شراء' : 'Buy';
  static String get sell => AppLanguage.isArabic ? 'بيع' : 'Sell';
  static String get deposit => AppLanguage.isArabic ? 'إضافة أموال / إيداع' : 'Deposit Funds';
  static String get cancelOrder => AppLanguage.isArabic ? 'إلغاء الأمر' : 'Cancel Order';
  static String get editOrder => AppLanguage.isArabic ? 'تعديل الأمر' : 'Edit Order';
  static String get saveChanges => AppLanguage.isArabic ? 'حفظ التعديلات' : 'Save Changes';

  // Settings
  static String get settingsTitle => AppLanguage.isArabic ? 'الإعدادات والأمان' : 'Settings & Security';
  static String get appLanguageLabel => AppLanguage.isArabic ? 'لغة التطبيق' : 'App Language';
  static String get appLanguageSubtitle => AppLanguage.isArabic ? 'التبديل بين العربية والإنجليزية' : 'Switch between Arabic and English';
  static String get lightModeLabel => AppLanguage.isArabic ? 'الوضع الفاتح' : 'Light Mode';
  static String get lightModeSubtitle => AppLanguage.isArabic ? 'التبديل بين الثيم الداكن والفاتح للتطبيق' : 'Switch between Dark and Light Theme';
  static String get biometricsLabel => AppLanguage.isArabic ? 'التسجيل بالبصمة / Face ID' : 'Biometrics / Face ID';
  static String get notificationsLabel => AppLanguage.isArabic ? 'إشعارات تنفيذ الأوامر اللحظية' : 'Real-time Notifications';
  static String get changePasswordLabel => AppLanguage.isArabic ? 'تغيير كلمة المرور' : 'Change Password';

  // Portfolio
  static String get portfolioTitle => AppLanguage.isArabic ? 'المحفظة الاستثمارية والأرباح' : 'Portfolio & Profits';
  static String get totalValuation => AppLanguage.isArabic ? 'إجمالي قيمة المحفظة' : 'Total Portfolio Value';
  static String get buyingPower => AppLanguage.isArabic ? 'القوة الشرائية المتاحة' : 'Available Buying Power';
  static String get cashBalance => AppLanguage.isArabic ? 'الرصيد النقدي المتاح' : 'Available Cash Balance';
  static String get ownedHoldings => AppLanguage.isArabic ? 'الأسهم المملوكة' : 'Owned Holdings';
  static String get portfolioPerformance => AppLanguage.isArabic ? 'أداء المحفظة والأرباح' : 'Portfolio Performance';

  // Order Details
  static String get orderHistoryTitle => AppLanguage.isArabic ? 'سجل قائمة الأوامر' : 'Order History';
  static String get custodianBank => AppLanguage.isArabic ? 'أمين الحفظ' : 'Custodian Bank';
  static String get executionRule => AppLanguage.isArabic ? 'قاعدة التنفيذ' : 'Execution Rule';
  static String get orderDuration => AppLanguage.isArabic ? 'صلاحية الأمر' : 'Order Duration';
  static String get fillBlockSize => AppLanguage.isArabic ? 'أمر شرطي (تنفيذ بالدفعات)' : 'Conditional Fill Block Size';

  // Search Screen
  static String get searchHint => AppLanguage.isArabic ? 'ابحث بالاسم أو الرمز...' : 'Search by name or symbol...';
  static String get shariaFilter => AppLanguage.isArabic ? 'أسهم الشريعة الإسلامية' : 'Sharia Compliant Stocks';
}

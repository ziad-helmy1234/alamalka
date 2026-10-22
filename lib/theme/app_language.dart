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

  // Actions & Buttons
  static String get buy => AppLanguage.isArabic ? 'شراء' : 'Buy';
  static String get sell => AppLanguage.isArabic ? 'بيع' : 'Sell';
  static String get deposit => AppLanguage.isArabic ? 'إضافة أموال / إيداع' : 'Deposit Funds';
  static String get depositNow => AppLanguage.isArabic ? 'إيداع الآن' : 'Deposit Now';
  static String get confirmDeposit => AppLanguage.isArabic ? 'تأكيد الإيداع' : 'Confirm Deposit';
  static String get cancelOrder => AppLanguage.isArabic ? 'إلغاء الأمر' : 'Cancel Order';
  static String get editOrder => AppLanguage.isArabic ? 'تعديل الأمر' : 'Edit Order';
  static String get saveChanges => AppLanguage.isArabic ? 'حفظ التعديلات' : 'Save Changes';
  static String get confirm => AppLanguage.isArabic ? 'تأكيد' : 'Confirm';
  static String get back => AppLanguage.isArabic ? 'تراجع' : 'Cancel';

  // Profile Header & Banner
  static String get userName => AppLanguage.isArabic ? 'زياد أحمد (مستثمر معتمد)' : 'Ziad Ahmed (Accredited Investor)';
  static String get unifiedId => AppLanguage.isArabic ? 'رقم الحساب الموحد: #EGX-892104' : 'Unified Account ID: #EGX-892104';
  static String get fraAccount => AppLanguage.isArabic ? 'حساب مفعل - الهيئة العامة للرقابة المالية' : 'Active Account - Financial Regulatory Authority';
  static String get depositBannerTitle => AppLanguage.isArabic ? 'إضافة أموال للمحفظة' : 'Add Funds to Portfolio';
  static String get depositBannerSubtitle => AppLanguage.isArabic ? 'إيداع فوري عبر انستا باي والبطاقات المصرفية' : 'Instant deposit via InstaPay & Bank Cards';

  // Settings & Profile
  static String get accountManagement => AppLanguage.isArabic ? 'إدارة الحساب والمعاملات' : 'Account & Transaction Management';
  static String get inboxTitle => AppLanguage.isArabic ? 'الرسائل والإشعارات' : 'Inbox & Notifications';
  static String get inboxSubtitle => AppLanguage.isArabic ? 'تأكيدات الأوامر والإيداعات والإشعارات الهامة' : 'Order confirmations, deposits & notices';
  static String get transferHistoryTitle => AppLanguage.isArabic ? 'سجل التحويلات والإيداعات' : 'Transfer & Deposit History';
  static String get transferHistorySubtitle => AppLanguage.isArabic ? 'سجل جميع عمليات الإيداع والسحب البنكي' : 'All bank deposit and withdrawal history';
  static String get statementsTitle => AppLanguage.isArabic ? 'كشوف الحساب والتقارير' : 'Account Statements & Reports';
  static String get statementsSubtitle => AppLanguage.isArabic ? 'تحميل كشوف الحساب الشهرية والربع سنوية' : 'Download monthly and quarterly PDF statements';
  static String get formsTitle => AppLanguage.isArabic ? 'النماذج والمستندات' : 'Forms & Documents';
  static String get formsSubtitle => AppLanguage.isArabic ? 'نماذج اعرف عميلك والقرارات الضريبية' : 'KYC forms & W-8BEN tax declarations';
  static String get settingsTitle => AppLanguage.isArabic ? 'الإعدادات والأمان' : 'Settings & Security';
  static String get settingsSubtitle => AppLanguage.isArabic ? 'تغيير كلمة المرور، البصمة، وتفضيلات التطبيق' : 'Change password, biometrics & app preferences';
  static String get aboutAppTitle => AppLanguage.isArabic ? 'عن التطبيق والمعلومات القانونية' : 'About App & Legal Info';
  static String get aboutAppSubtitle => AppLanguage.isArabic ? 'تراخيص الهيئة العامة للرقابة المالية والشروط' : 'FRA licenses, terms & regulatory disclosures';

  // Settings Items
  static String get appLanguageLabel => AppLanguage.isArabic ? 'لغة التطبيق' : 'App Language';
  static String get appLanguageSubtitle => AppLanguage.isArabic ? 'التبديل بين العربية والإنجليزية' : 'Switch between Arabic and English';
  static String get lightModeLabel => AppLanguage.isArabic ? 'الوضع الفاتح' : 'Light Mode';
  static String get lightModeSubtitle => AppLanguage.isArabic ? 'التبديل بين الثيم الداكن والفاتح للتطبيق' : 'Switch between Dark and Light Theme';
  static String get biometricsLabel => AppLanguage.isArabic ? 'التسجيل بالبصمة' : 'Biometrics / Face ID';
  static String get biometricsSubtitle => AppLanguage.isArabic ? 'تسجيل الدخول السريع والأمن للبيانات المالية' : 'Fast and secure biometric login for financial data';
  static String get notificationsLabel => AppLanguage.isArabic ? 'إشعارات تنفيذ الأوامر اللحظية' : 'Real-time Notifications';
  static String get notificationsSubtitle => AppLanguage.isArabic ? 'تنبيهات أسعار وتأكيد تنفيذ أوامر البيع والشراء' : 'Price alerts and trade execution confirmations';
  static String get changePasswordLabel => AppLanguage.isArabic ? 'تغيير كلمة المرور' : 'Change Password';
  static String get changePasswordSubtitle => AppLanguage.isArabic ? 'إدخال كلمة المرور القديمة وتأكيد الجديدة' : 'Enter old password and confirm new password';
  static String get changePinLabel => AppLanguage.isArabic ? 'تغيير رمز PIN للتداول' : 'Change Trading PIN';
  static String get changePinSubtitle => AppLanguage.isArabic ? 'تعديل رمز الأمان القصير لتنفيذ الصفقات' : 'Modify short security PIN for placing trades';

  // Deposit Modal
  static String get addFundsHeader => AppLanguage.isArabic ? 'إضافة أموال للمحفظة' : 'Deposit Funds to Portfolio';
  static String get egpCurrencyLabel => AppLanguage.isArabic ? 'الجنيه المصري' : 'Egyptian Pound (EGP)';
  static String get usdCurrencyLabel => AppLanguage.isArabic ? 'الدولار الأمريكي' : 'US Dollar (USD)';
  static String get selectAmountLabel => AppLanguage.isArabic ? 'اختر المبلغ أو أدخل القيمة:' : 'Select amount or enter value:';
  static String get depositAmountLabel => AppLanguage.isArabic ? 'قيمة الإيداع' : 'Deposit Amount';
  static String get preferredDepositMethod => AppLanguage.isArabic ? 'طريقة الإيداع المفضلة:' : 'Preferred Payment Method:';

  static String get methodInstaPay => AppLanguage.isArabic ? 'انستا باي (InstaPay)' : 'InstaPay Transfer';
  static String get methodInstaPayDesc => AppLanguage.isArabic ? 'إيداع لحظي بدون رسوم' : 'Instant fee-free deposit';
  static String get methodBankTransfer => AppLanguage.isArabic ? 'تحويل بنكي مباشر' : 'Direct Bank Transfer';
  static String get methodBankTransferDesc => AppLanguage.isArabic ? 'تحويل لحساب الشركة بالبنك الأهلي/CIB' : 'Transfer to CIB or NBE company account';
  static String get methodCard => AppLanguage.isArabic ? 'بطاقة مصرفية' : 'Bank Debit / Credit Card';
  static String get methodCardDesc => AppLanguage.isArabic ? 'خصم مباشر / بطاقة ائتمان' : 'Direct debit or credit card charge';
  static String get methodSmartWallet => AppLanguage.isArabic ? 'فودافون كاش / محفظة ذكية' : 'Vodafone Cash / Smart Wallet';
  static String get methodSmartWalletDesc => AppLanguage.isArabic ? 'تحويل سريع عبر المحفظة الذكية' : 'Fast mobile wallet transfer';

  // Portfolio
  static String get portfolioTitle => AppLanguage.isArabic ? 'المحفظة الاستثمارية والأرباح' : 'Portfolio & Profits';
  static String get egpPortfolioTab => AppLanguage.isArabic ? 'محفظة الجنيه المصري' : 'EGP Portfolio';
  static String get usdPortfolioTab => AppLanguage.isArabic ? 'محفظة الدولار الأمريكي' : 'USD Portfolio';
  static String get totalValuation => AppLanguage.isArabic ? 'إجمالي قيمة المحفظة' : 'Total Portfolio Value';
  static String get buyingPower => AppLanguage.isArabic ? 'القوة الشرائية المتاحة' : 'Available Buying Power';
  static String get cashBalance => AppLanguage.isArabic ? 'الرصيد النقدي المتاح' : 'Available Cash Balance';
  static String get ownedHoldings => AppLanguage.isArabic ? 'الأسهم المملوكة' : 'Owned Holdings';
  static String get portfolioPerformance => AppLanguage.isArabic ? 'أداء المحفظة والأرباح' : 'Portfolio Performance';
  static String get noHoldings => AppLanguage.isArabic ? 'لا توجد أسهم مملوكة حالياً بهذه العملة' : 'No holdings currently in this currency';

  // Order Modal & Trading Terms
  static String get custodianBank => AppLanguage.isArabic ? 'أمين الحفظ' : 'Custodian Bank';
  static String get pricingMode => AppLanguage.isArabic ? 'نوع السعر' : 'Pricing Mode';
  static String get limitPrice => AppLanguage.isArabic ? 'سعر حد' : 'Limit Price';
  static String get marketPrice => AppLanguage.isArabic ? 'سعر السوق' : 'Market Price';
  static String get quantityLabel => AppLanguage.isArabic ? 'الكمية (عدد الأسهم)' : 'Quantity (Shares)';
  static String get targetPriceLabel => AppLanguage.isArabic ? 'السعر المستهدف' : 'Target Price';
  static String get executionRule => AppLanguage.isArabic ? 'قاعدة التنفيذ' : 'Execution Rule';
  static String get fillBlockCondition => AppLanguage.isArabic ? 'أمر شرطي (تنفيذ بالدفعات)' : 'Fill Block Condition';
  static String get fillBlockSize => AppLanguage.isArabic ? 'أمر شرطي (تنفيذ بالدفعات)' : 'Conditional Fill Block Size';
  static String get minBlockQuantity => AppLanguage.isArabic ? 'الحد الأدنى لكمية الدفعة' : 'Minimum Fill Block Quantity';
  static String get orderDuration => AppLanguage.isArabic ? 'صلاحية الأمر' : 'Order Duration';
  static String get dayOrder => AppLanguage.isArabic ? 'أمر يومي' : 'Day Order';
  static String get gtcOrder => AppLanguage.isArabic ? 'حتى الإلغاء' : 'Good-Till-Cancel (GTC)';
  static String get gtdOrder => AppLanguage.isArabic ? 'صالح حتى تاريخ' : 'Good-Till-Date (GTD)';
  static String get totalOrderValue => AppLanguage.isArabic ? 'إجمالي قيمة الأمر' : 'Total Order Value';

  // Order Details & History
  static String get orderHistoryTitle => AppLanguage.isArabic ? 'سجل قائمة الأوامر' : 'Order History';
  static String get noOrders => AppLanguage.isArabic ? 'لا توجد أوامر منفذة أو معلقة حالياً' : 'No pending or executed orders currently';
  static String get orderPending => AppLanguage.isArabic ? 'قيد التنفيذ (معلق)' : 'Pending Execution';
  static String get orderExecuted => AppLanguage.isArabic ? 'تم التنفيذ' : 'Executed';
  static String get orderCancelled => AppLanguage.isArabic ? 'ملغى' : 'Cancelled';

  // Stock Detail Pages & Headers
  static String get stockPerformanceTitle => AppLanguage.isArabic ? 'أداء السهم والرسم البياني' : 'Stock Performance & Chart';
  static String get volumeSpikesTitle => AppLanguage.isArabic ? 'أحجام التداول والسيولة' : 'Trading Volume & Liquidity';
  static String get basicStatsTitle => AppLanguage.isArabic ? 'بيانات السوق الأساسية' : 'Key Market Statistics';
  static String get depthByPriceTitle => AppLanguage.isArabic ? 'السوق بالسعر' : 'Market Depth by Price';
  static String get depthByOrdersTitle => AppLanguage.isArabic ? 'السوق بالأوامر' : 'Market Depth by Orders';
  static String get executionsStreamTitle => AppLanguage.isArabic ? 'إجمالي التنفيذات اللحظية' : 'Real-time Trades Stream';

  static String get bidsHeader => AppLanguage.isArabic ? 'طلبات الشراء' : 'Bids';
  static String get asksHeader => AppLanguage.isArabic ? 'عروض البيع' : 'Asks';
  static String get bidsOrderBook => AppLanguage.isArabic ? 'دفتر طلبات الشراء' : 'Bids Order Book';
  static String get asksOrderBook => AppLanguage.isArabic ? 'دفتر عروض البيع' : 'Asks Order Book';

  static String get lastPrice => AppLanguage.isArabic ? 'آخر سعر' : 'Last Price';
  static String get changeValue => AppLanguage.isArabic ? 'قيمة التغير' : 'Price Change';
  static String get openPrice => AppLanguage.isArabic ? 'سعر الفتح' : 'Open Price';
  static String get previousClose => AppLanguage.isArabic ? 'الإغلاق السابق' : 'Previous Close';
  static String get dayHigh => AppLanguage.isArabic ? 'أعلى سعر اليوم' : 'Day High';
  static String get dayLow => AppLanguage.isArabic ? 'أدنى سعر اليوم' : 'Day Low';
  static String get volume => AppLanguage.isArabic ? 'كمية التداول' : 'Trading Volume';
  static String get numberOfTrades => AppLanguage.isArabic ? 'عدد العمليات' : 'Trade Count';
  static String get totalTradeValue => AppLanguage.isArabic ? 'قيمة التداول' : 'Total Trade Value';
  static String get marketCap => AppLanguage.isArabic ? 'رأس المال السوقي' : 'Market Cap';
  static String get peRatio => AppLanguage.isArabic ? 'مضاعف الربحية' : 'P/E Ratio';

  // IPO Ripple Effect
  static String get ipoTrackerTitle => AppLanguage.isArabic ? 'تتبع تأثير الطروحات الأولية' : 'IPO Ripple Effect Tracker';
  static String get ipoUspBadge => AppLanguage.isArabic ? 'تحليل الفجوة السعرية للسيولة' : 'Market Gap Liquidity Analysis';
  static String get ipoHeaderDesc => AppLanguage.isArabic
      ? 'تحليل تأثير الطروحات الأولية الجديدة على سيولة السوق وتعديل أسعار الأسهم والقطاعات المتأثرة في محفظتك.'
      : 'Analyze the impact of new IPOs on market liquidity and portfolio stock pricing.';

  // Search Screen
  static String get searchHint => AppLanguage.isArabic ? 'ابحث بالاسم أو الرمز...' : 'Search by name or symbol...';
  static String get shariaFilter => AppLanguage.isArabic ? 'أسهم الشريعة الإسلامية' : 'Sharia Compliant Stocks';
  static String get noSearchResults => AppLanguage.isArabic ? 'لا توجد أسهم تطابق نتائج البحث والتصنيف' : 'No stocks matching search or category filters';

  // Watchlist
  static String get emptyWatchlistTitle => AppLanguage.isArabic ? 'قائمة المراقبة فارغة حالياً' : 'Watchlist is currently empty';
  static String get emptyWatchlistDesc => AppLanguage.isArabic
      ? 'يمكنك إضافة أي سهم إلى قائمة المراقبة بالنقر على أيقونة الإشارة المرجعية في الشاشة الرئيسية أو شاشة البحث.'
      : 'You can add any stock to your watchlist by tapping the bookmark icon on the markets or search page.';
}

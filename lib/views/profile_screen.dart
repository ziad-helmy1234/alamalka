import 'package:flutter/material.dart';
import '../services/stock_service.dart';
import '../theme/app_theme.dart';
import 'add_funds_modal.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final StockService _stockService = StockService();

  @override
  Widget build(BuildContext context) {
    final portfolio = _stockService.getPortfolioSummary();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.person, color: AppColors.accentBlue),
            SizedBox(width: 8),
            Text('صفحة المستخدم والحساب'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header Card
            _buildUserHeaderCard(portfolio.egpTotalValue),
            const SizedBox(height: 20),

            // Quick Deposit Button Card
            _buildDepositBannerCard(context),
            const SizedBox(height: 20),

            // Menu Section Title
            const Text(
              'إدارة الحساب والمعاملات',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Menu Options Grid / List
            _buildMenuItem(
              icon: Icons.inbox,
              iconColor: AppColors.accentBlue,
              title: 'الرسائل والإشعارات (Inbox)',
              subtitle: 'تأكيدات الأوامر والإيداعات والإشعارات الهامة',
              badgeCount: _stockService.inboxMessages.where((m) => !m.isRead).length,
              onTap: () => _showInboxSheet(context),
            ),
            _buildMenuItem(
              icon: Icons.history_toggle_off,
              iconColor: AppColors.greenPositive,
              title: 'سجل التحويلات والإيداعات (Transfer History)',
              subtitle: 'سجل جميع عمليات الإيداع والسحب البنكي',
              onTap: () => _showTransferHistorySheet(context),
            ),
            _buildMenuItem(
              icon: Icons.receipt_long,
              iconColor: Colors.purpleAccent,
              title: 'كشوف الحساب والتقارير (Statements)',
              subtitle: 'تحميل كشوف الحساب الشهرية والربع سنوية (PDF)',
              onTap: () => _showStatementsSheet(context),
            ),
            _buildMenuItem(
              icon: Icons.description_outlined,
              iconColor: Colors.amber,
              title: 'النماذج والمستندات (Forms & Docs)',
              subtitle: 'نماذج KYC والقرارات الضريبية W-8BEN',
              onTap: () => _showFormsSheet(context),
            ),
            _buildMenuItem(
              icon: Icons.settings,
              iconColor: AppColors.accentBlue,
              title: 'الإعدادات والأمان (Settings)',
              subtitle: 'تغيير رمز PIN، البصمة (Biometrics)، وتفضيلات التطبيق',
              onTap: () => _showSettingsSheet(context),
            ),
            _buildMenuItem(
              icon: Icons.info_outline,
              iconColor: Colors.cyan,
              title: 'عن التطبيق والمعلومات القانونية (About App)',
              subtitle: 'تراخيص الهيئة العامة للرقابة المالية (FRA) والشروط',
              onTap: () => _showAboutAppSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserHeaderCard(double egpBalance) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppColors.accentBlue.withOpacity(0.2),
              child: const Icon(Icons.person, size: 36, color: AppColors.accentBlue),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'زياد أحمد (مستثمر معتمد)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'رقم الحساب الموحد (Unified ID): #EGX-892104',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.greenPositive.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'حساب مفعل - الهيئة العامة للرقابة المالية (FRA)',
                      style: TextStyle(
                          color: AppColors.greenPositive,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
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

  Widget _buildDepositBannerCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.greenPositive.withOpacity(0.25),
            Theme.of(context).cardColor,
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.greenPositive.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'إضافة أموال للمحفظة',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'إيداع فوري عبر InstaPay والبطاقات المصرفية',
                  style: TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.greenPositive,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.add, color: Colors.white, size: 16),
            label: const Text('إيداع الآن',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Theme.of(context).cardColor,
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) => const AddFundsModal(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 6),
              CircleAvatar(
                radius: 9,
                backgroundColor: AppColors.redNegative,
                child: Text('$badgeCount',
                    style: const TextStyle(fontSize: 10, color: Colors.white)),
              ),
            ],
          ],
        ),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 11),
            overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      ),
    );
  }

  // Sheets for menu options
  void _showInboxSheet(BuildContext context) {
    final messages = _stockService.inboxMessages;
    _showCustomBottomSheet(
      context,
      'الرسائل والإشعارات (Inbox)',
      ListView.separated(
        shrinkWrap: true,
        itemCount: messages.length,
        separatorBuilder: (_, __) => const Divider(color: AppColors.borderDark),
        itemBuilder: (context, index) {
          final msg = messages[index];
          return ListTile(
            leading: const Icon(Icons.mark_email_unread, color: AppColors.accentBlue),
            title: Text(msg.titleAr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text(msg.bodyAr, style: const TextStyle(fontSize: 12)),
          );
        },
      ),
    );
  }

  void _showTransferHistorySheet(BuildContext context) {
    final transfers = _stockService.transferHistory;
    _showCustomBottomSheet(
      context,
      'سجل التحويلات والإيداعات (Transfer History)',
      ListView.separated(
        shrinkWrap: true,
        itemCount: transfers.length,
        separatorBuilder: (_, __) => const Divider(color: AppColors.borderDark),
        itemBuilder: (context, index) {
          final trf = transfers[index];
          return ListTile(
            leading: const Icon(Icons.arrow_downward, color: AppColors.greenPositive),
            title: Text('${trf.typeAr} - ${trf.amount.toStringAsFixed(2)} ${trf.currency}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('طريقة الإيداع: ${trf.methodAr} • الحالة: ${trf.statusAr}',
                style: const TextStyle(fontSize: 12)),
          );
        },
      ),
    );
  }

  void _showStatementsSheet(BuildContext context) {
    final statements = _stockService.statements;
    _showCustomBottomSheet(
      context,
      'كشوف الحساب الشهرية (Statements)',
      ListView.separated(
        shrinkWrap: true,
        itemCount: statements.length,
        separatorBuilder: (_, __) => const Divider(color: AppColors.borderDark),
        itemBuilder: (context, index) {
          final st = statements[index];
          return ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: AppColors.redNegative),
            title: Text(st.titleAr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('${st.periodAr} • ${st.fileSize}',
                style: const TextStyle(fontSize: 12)),
            trailing: IconButton(
              icon: const Icon(Icons.download, color: AppColors.accentBlue),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('جاري تحميل ${st.titleAr}...')),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showFormsSheet(BuildContext context) {
    final forms = _stockService.forms;
    _showCustomBottomSheet(
      context,
      'النماذج والمستندات (Forms)',
      ListView.separated(
        shrinkWrap: true,
        itemCount: forms.length,
        separatorBuilder: (_, __) => const Divider(color: AppColors.borderDark),
        itemBuilder: (context, index) {
          final f = forms[index];
          return ListTile(
            leading: const Icon(Icons.assignment_turned_in, color: Colors.amber),
            title: Text(f.titleAr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text(f.descriptionAr, style: const TextStyle(fontSize: 12)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.greenPositive.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(f.statusAr, style: const TextStyle(color: AppColors.greenPositive, fontSize: 10)),
            ),
          );
        },
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    _showCustomBottomSheet(
      context,
      'الإعدادات والأمان (Settings)',
      ValueListenableBuilder<ThemeMode>(
        valueListenable: AppTheme.themeNotifier,
        builder: (context, mode, _) {
          final isDark = mode == ThemeMode.dark;
          return Column(
            children: [
              SwitchListTile(
                title: const Text('الوضع الفاتح (Light Mode)'),
                subtitle: const Text('التبديل بين الثيم الداكن والفاتح للتطبيق'),
                secondary: Icon(
                  isDark ? Icons.dark_mode : Icons.light_mode,
                  color: isDark ? Colors.amber : AppColors.accentBlue,
                ),
                value: !isDark,
                activeColor: AppColors.accentBlue,
                onChanged: (val) {
                  AppTheme.toggleTheme();
                },
              ),
              const Divider(color: AppColors.borderDark),
              SwitchListTile(
                title: const Text('التسجيل بالبصمة / Face ID'),
                subtitle: const Text('تسجيل الدخول السريع والآمن للبيانات المالية'),
                value: true,
                activeColor: AppColors.accentBlue,
                onChanged: (val) {},
              ),
              SwitchListTile(
                title: const Text('إشعارات تنفيذ الأوامر اللحظية'),
                subtitle: const Text('تنبيهات أسعار وتأكيد تنفيذ أوامر البيع والشراء'),
                value: true,
                activeColor: AppColors.accentBlue,
                onChanged: (val) {},
              ),
              ListTile(
                title: const Text('تغيير رمز PIN للتداول'),
                trailing: const Icon(Icons.lock_outline),
                onTap: () {},
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAboutAppSheet(BuildContext context) {
    _showCustomBottomSheet(
      context,
      'عن التطبيق (About App)',
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تطبيق التداول المتقدم v2.4.0', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          SizedBox(height: 8),
          Text(
            'مرخص ومُعتمد رسمياً من الهيئة العامة للرقابة المالية (FRA) برقم ترخيص #782 للوساطة في الأوراق المالية بالبورصة المصرية.',
            style: TextStyle(height: 1.4),
          ),
          SizedBox(height: 12),
          Text('جميع حقوق الملكية والتشفير محفوظة © 2024', style: TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  void _showCustomBottomSheet(BuildContext context, String title, Widget body) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Divider(color: Theme.of(context).dividerColor),
            Flexible(
              child: SingleChildScrollView(
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

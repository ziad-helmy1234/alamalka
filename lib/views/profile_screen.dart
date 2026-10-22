import 'package:flutter/material.dart';
import '../services/stock_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_language.dart';
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
    final egpBalance = _stockService.getPortfolioSummary().egpTotalValue;

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
            // User Verified Account Header Card
            _buildUserHeaderCard(egpBalance),
            const SizedBox(height: 16),

            // Quick Deposit Banner
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
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            if (badgeCount > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.redNegative,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
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
      AppStrings.settingsTitle,
      ValueListenableBuilder<ThemeMode>(
        valueListenable: AppTheme.themeNotifier,
        builder: (context, mode, _) {
          final isDark = mode == ThemeMode.dark;
          return ValueListenableBuilder<Locale>(
            valueListenable: AppLanguage.localeNotifier,
            builder: (context, locale, _) {
              final isEn = locale.languageCode == 'en';
              return Column(
                children: [
                  SwitchListTile(
                    title: Text(AppStrings.appLanguageLabel),
                    subtitle: Text(AppStrings.appLanguageSubtitle),
                    secondary: const Icon(
                      Icons.language,
                      color: AppColors.accentBlue,
                    ),
                    value: isEn,
                    activeThumbColor: AppColors.accentBlue,
                    onChanged: (val) {
                      AppLanguage.toggleLanguage();
                    },
                  ),
                  Divider(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight),
                  SwitchListTile(
                    title: Text(AppStrings.lightModeLabel),
                    subtitle: Text(AppStrings.lightModeSubtitle),
                    secondary: Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode,
                      color: isDark ? Colors.amber : AppColors.accentBlue,
                    ),
                    value: !isDark,
                    activeThumbColor: AppColors.accentBlue,
                    onChanged: (val) {
                      AppTheme.toggleTheme();
                    },
                  ),
                  Divider(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight),
                  SwitchListTile(
                    title: Text(AppStrings.biometricsLabel),
                    subtitle: const Text(
                        'تسجيل الدخول السريع والآمن للبيانات المالية'),
                    value: true,
                    activeThumbColor: AppColors.accentBlue,
                    onChanged: (val) {},
                  ),
                  SwitchListTile(
                    title: Text(AppStrings.notificationsLabel),
                    subtitle: const Text(
                        'تنبيهات أسعار وتأكيد تنفيذ أوامر البيع والشراء'),
                    value: true,
                    activeThumbColor: AppColors.accentBlue,
                    onChanged: (val) {},
                  ),
                  ListTile(
                    title: Text(AppStrings.changePasswordLabel),
                    subtitle:
                        const Text('إدخال كلمة المرور القديمة وتأكيد الجديدة'),
                    leading: const Icon(Icons.key_outlined,
                        color: AppColors.accentBlue),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      _showChangePasswordModal(context);
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
              ListTile(
                title: const Text('تغيير رمز PIN للتداول'),
                leading: const Icon(Icons.lock_outline, color: AppColors.accentBlue),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {},
              ),
            ],
          );
        },
      ),
    );
  }

  void _showChangePasswordModal(BuildContext context) {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => ValueListenableBuilder<ThemeMode>(
          valueListenable: AppTheme.themeNotifier,
          builder: (context, mode, _) {
            final isDark = mode == ThemeMode.dark;
            final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
            final onSurface =
                isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

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
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.lock_reset,
                                  color: AppColors.accentBlue, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                'تغيير كلمة المرور (Change Password)',
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
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      Divider(
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight),
                      const SizedBox(height: 12),

                      // 1. Old Password
                      TextFormField(
                        controller: oldPasswordController,
                        obscureText: obscureOld,
                        style: TextStyle(color: onSurface),
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور القديمة (Old Password)',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(obscureOld
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () =>
                                setState(() => obscureOld = !obscureOld),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'يرجى إدخال كلمة المرور القديمة';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // 2. New Password
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: obscureNew,
                        style: TextStyle(color: onSurface),
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور الجديدة (New Password)',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_reset),
                          suffixIcon: IconButton(
                            icon: Icon(obscureNew
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () =>
                                setState(() => obscureNew = !obscureNew),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().length < 6) {
                            return 'كلمة المرور الجديدة يجب ألا تقل عن 6 أحرف/أرقام';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // 3. Confirm Password
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirm,
                        style: TextStyle(color: onSurface),
                        decoration: InputDecoration(
                          labelText:
                              'تأكيد كلمة المرور الجديدة (Confirm New Password)',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.check_circle_outline),
                          suffixIcon: IconButton(
                            icon: Icon(obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () => setState(
                                () => obscureConfirm = !obscureConfirm),
                          ),
                        ),
                        validator: (val) {
                          if (val != newPasswordController.text) {
                            return 'كلمة المرور الجديدة غير متطابقة مع التأكيد';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentBlue,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم تغيير كلمة المرور بنجاح!'),
                                  backgroundColor: AppColors.greenPositive,
                                ),
                              );
                            }
                          },
                          child: const Text(
                            'حفظ كلمة المرور الجديدة',
                            style: TextStyle(
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
              ),
            );
          },
        ),
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
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) => ValueListenableBuilder<ThemeMode>(
        valueListenable: AppTheme.themeNotifier,
        builder: (context, mode, _) {
          final isDark = mode == ThemeMode.dark;
          final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
          final onSurface =
              isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
          final borderClr =
              isDark ? AppColors.borderDark : AppColors.borderLight;

          return Material(
            color: cardBg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(bottomSheetContext).size.height * 0.8,
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
                            color: onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: onSurface),
                        onPressed: () => Navigator.pop(bottomSheetContext),
                      ),
                    ],
                  ),
                  Divider(color: borderClr),
                  Flexible(
                    child: SingleChildScrollView(
                      child: body,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

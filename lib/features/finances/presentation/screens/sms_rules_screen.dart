import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:note_taking_app/core/services/app_haptics.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import 'package:note_taking_app/features/finances/data/transaction_repository.dart';
import 'package:note_taking_app/data/transaction_category.dart';
import 'package:note_taking_app/services/sms_service.dart';
import 'package:note_taking_app/services/sms_parser.dart';
import 'package:note_taking_app/services/sms_constants.dart';
import 'package:note_taking_app/core/theme/app_layout.dart';
import 'package:note_taking_app/core/ui/expressive_sliver_app_bar.dart';
import 'package:note_taking_app/data/custom_sms_rule.dart';
import 'package:note_taking_app/features/finances/presentation/widgets/teach_sms_rule_sheet.dart';
import 'package:note_taking_app/utils/app_route.dart';
import 'package:note_taking_app/features/finances/presentation/screens/category_management_screen.dart';
import 'package:note_taking_app/features/finances/presentation/screens/sms_contacts_screen.dart';
import '../widgets/sms_import_sheet.dart';

class SmsRulesScreen extends StatefulWidget {
  const SmsRulesScreen({super.key});

  @override
  State<SmsRulesScreen> createState() => _SmsRulesScreenState();
}

class _SmsRulesScreenState extends State<SmsRulesScreen> {
  // Controllers for adding rules
  final _expenseRuleController = TextEditingController();
  final _incomeRuleController = TextEditingController();
  final _testSmsController = TextEditingController();

  @override
  void dispose() {
    _expenseRuleController.dispose();
    _incomeRuleController.dispose();
    _testSmsController.dispose();
    super.dispose();
  }

  Future<void> _pasteToTest() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      setState(() {
        _testSmsController.text = data.text!.trim();
      });
    }
  }

  Future<void> _confirmRestoreDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore default rules?'),
        content: const Text(
            'All custom transaction-type rules will be removed and built-in category keywords reset to their defaults.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    await settings.clearCustomRules();
    await TransactionRepository.instance.resetBuiltInCategoryKeywords();
    await TransactionCategory.reload();
    await SmsService.reloadSmsContacts();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SMS rules restored to defaults')),
      );
    }
  }

  String _formatTimeOfDay(BuildContext context, String timeStr) {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final time = TimeOfDay(hour: hour, minute: minute);
      return time.format(context);
    } catch (_) {
      return timeStr;
    }
  }

  void _showTimePicker(BuildContext context, SettingsProvider settings) async {
    final parts = settings.dailySyncTime.split(':');
    final initialHour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 20 : 20;
    final initialMinute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
    );

    if (picked != null) {
      final formattedTime =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      await settings.setDailySyncTime(formattedTime);
    }
  }

  void _performManualSmsSync(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Scanning SMS inbox for bank transactions...'),
        duration: Duration(seconds: 2),
      ),
    );
    final count = await SmsService.performDailySyncManualTrigger();
    if (!mounted) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          count > 0
              ? 'Synced $count new bank transaction${count == 1 ? "" : "s"} successfully.'
              : 'SMS scan complete. No new bank transactions found.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          ExpressiveSliverAppBar(
            titleText: 'SMS Bank Automation',
            showBackButton: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_backup_restore),
                tooltip: 'Restore defaults',
                onPressed: _confirmRestoreDefaults,
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          final expenseRules = settings.customExpenseRules;
          final incomeRules = settings.customIncomeRules;

          final items = <Widget>[
            // Quick Shortcuts Row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => AppRoute.push(context, const SmsContactsScreen()),
                      icon: const Icon(Icons.contacts_outlined, size: 18),
                      label: const Text('Senders & Blocklist'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppLayout.radiusM)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        builder: (_) => const SmsImportSheet(),
                      ),
                      icon: const Icon(Icons.history_outlined, size: 18),
                      label: const Text('Scan Past SMS'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppLayout.radiusM)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Automated Daily Sync Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppLayout.radiusL),
                  side: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                color: cs.surfaceContainerLow,
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: Icon(Icons.sync_outlined, color: cs.primary),
                      title: const Text('Automated Daily Sync', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Scan inbox for bank transactions in background'),
                      value: settings.dailySyncEnabled,
                      onChanged: settings.setDailySyncEnabled,
                    ),
                    if (settings.dailySyncEnabled) ...[
                      const SizedBox(height: AppLayout.spaceXS),
                      ListTile(
                        leading: Icon(Icons.access_time_outlined, color: cs.secondary),
                        title: const Text('Auto-Sync Time', style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: const Text('Scheduled background execution time'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTimeOfDay(context, settings.dailySyncTime),
                              style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary),
                            ),
                            const Icon(Icons.chevron_right, size: 20),
                          ],
                        ),
                        onTap: () => _showTimePicker(context, settings),
                      ),
                      const SizedBox(height: AppLayout.spaceXS),
                      ListTile(
                        leading: Icon(Icons.play_circle_outline_rounded, color: cs.primary),
                        title: const Text('Sync SMS Now', style: TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: const Text('Instantly scan inbox for recent transactions'),
                        onTap: () => _performManualSmsSync(context),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Info Card
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: cs.secondaryContainer,
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 20, color: cs.onSecondaryContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Define keywords that identify whether an incoming SMS is an Expense or Income. '
                          'If a message body contains one of these keywords, the app will set the type accordingly.',
                          style: tt.bodySmall?.copyWith(color: cs.onSecondaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Test SMS Parser Sandbox Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppLayout.radiusL),
                  side: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                color: cs.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.science_outlined, size: 20, color: cs.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Test SMS Parser',
                            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _pasteToTest,
                            icon: const Icon(Icons.content_paste, size: 16),
                            label: const Text('Paste'),
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _testSmsController,
                        maxLines: 3,
                        minLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Paste an SMS here to test live detection...',
                          filled: true,
                          fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppLayout.radiusM),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.all(12),
                          suffixIcon: _testSmsController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () => setState(() => _testSmsController.clear()),
                                )
                              : null,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (_) {
                          final testText = _testSmsController.text.trim();
                          if (testText.isEmpty) {
                            return Text(
                              'Paste any bank SMS above to preview parsed amount, type, merchant, and category.',
                              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                            );
                          }

                          final parsed = SmsParser.parseMessage(
                            body: testText,
                            address: 'BANK_SMS',
                            messageId: null,
                            messageDate: null,
                            allowedSenderIds: const {},
                            blockedSenderIds: const {},
                            customExpenseRules: expenseRules,
                            customIncomeRules: incomeRules,
                            customSmsRules: settings.customSmsRules,
                            preferredCurrency: settings.currency,
                          );

                          Widget previewCard;
                          if (parsed == null) {
                            final isOtp = SmsConstants.otpRegex.hasMatch(testText);
                            final isPromo = SmsConstants.promotionalRegex.hasMatch(testText);
                            final isIgnored = isOtp || isPromo;

                            final String errorMessage;
                            final IconData statusIcon;
                            if (isOtp) {
                              errorMessage = 'Ignored: Detected as an OTP, 2FA, or transfer authorization code (no money has moved yet).';
                              statusIcon = Icons.lock_outline_rounded;
                            } else if (isPromo) {
                              errorMessage = 'Ignored: Detected as a promotional broadcast or conditional marketing offer (no money was moved).';
                              statusIcon = Icons.campaign_outlined;
                            } else {
                              errorMessage = 'Not recognized as an executed financial transaction. Verify transaction keywords or currency amount format.';
                              statusIcon = Icons.warning_amber_rounded;
                            }

                            previewCard = Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isIgnored
                                    ? cs.surfaceContainerHighest.withValues(alpha: 0.8)
                                    : cs.errorContainer.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(AppLayout.radiusM),
                                border: Border.all(
                                  color: isIgnored
                                      ? cs.outlineVariant.withValues(alpha: 0.5)
                                      : cs.error.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    statusIcon,
                                    size: 20,
                                    color: isIgnored ? cs.primary : cs.error,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      errorMessage,
                                      style: tt.bodySmall?.copyWith(
                                        color: isIgnored ? cs.onSurface : cs.onErrorContainer,
                                        fontWeight: isIgnored ? FontWeight.w500 : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            previewCard = Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(AppLayout.radiusM),
                                border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        parsed.isExpense ? Icons.arrow_outward_rounded : Icons.arrow_downward_rounded,
                                        size: 18,
                                        color: parsed.isExpense ? cs.error : cs.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${parsed.isExpense ? '-' : '+'} ${settings.currency} ${parsed.amount.toStringAsFixed(2)}',
                                        style: tt.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: parsed.isExpense ? cs.error : cs.primary,
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: cs.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(AppLayout.radiusS),
                                        ),
                                        child: Text(
                                          parsed.isExpense ? 'Expense' : 'Income',
                                          style: tt.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.label_outline_rounded, size: 14, color: cs.onSurfaceVariant),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Title: ${parsed.description}',
                                          style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Icon(Icons.category_outlined, size: 14, color: cs.onSurfaceVariant),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Category: ${parsed.category}',
                                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              previewCard,
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final result = await TeachSmsRuleSheet.show(
                                    context: context,
                                    sampleSmsBody: testText,
                                  );
                                  if (result != null) {
                                    await SmsService.reloadSmsContacts();
                                    if (mounted) setState(() {});
                                  }
                                },
                                icon: const Icon(Icons.school_rounded, size: 18),
                                label: const Text('Teach App / Customize Rule from this SMS'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppLayout.radiusM),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Taught Custom Bank Rules Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Taught Custom Rules',
                              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Personalized rules taught to recognize your bank formats',
                              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          final result = await TeachSmsRuleSheet.show(context: context);
                          if (result != null) {
                            await SmsService.reloadSmsContacts();
                            if (mounted) setState(() {});
                          }
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Rule'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (settings.customSmsRules.isEmpty)
                    Card(
                      elevation: 0,
                      color: cs.surfaceContainerLow,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppLayout.radiusL),
                        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: cs.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No custom rules taught yet. Paste any SMS in the tester above or tap "+ Add Rule" to train the parser.',
                                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: settings.customSmsRules.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final rule = settings.customSmsRules[index];
                        final typeColor = switch (rule.type) {
                          RuleTransactionType.expense => cs.error,
                          RuleTransactionType.income => cs.tertiary,
                          RuleTransactionType.transfer => cs.secondary,
                        };
                        final typeIcon = switch (rule.type) {
                          RuleTransactionType.expense => Icons.arrow_upward_rounded,
                          RuleTransactionType.income => Icons.arrow_downward_rounded,
                          RuleTransactionType.transfer => Icons.swap_horiz_rounded,
                        };

                        return Dismissible(
                          key: Key(rule.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: cs.errorContainer,
                              borderRadius: BorderRadius.circular(AppLayout.radiusL),
                            ),
                            child: Icon(Icons.delete_outline_rounded, color: cs.onErrorContainer),
                          ),
                          onDismissed: (_) {
                            settings.deleteCustomSmsRule(rule.id);
                            SmsService.reloadSmsContacts();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Removed rule "${rule.keyword}"'),
                                action: SnackBarAction(
                                  label: 'Undo',
                                  onPressed: () {
                                    settings.restoreCustomSmsRule(rule);
                                    SmsService.reloadSmsContacts();
                                  },
                                ),
                              ),
                            );
                          },
                          child: Card(
                            elevation: 0,
                            color: rule.isEnabled ? cs.surfaceContainerLow : cs.surfaceContainerLowest.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppLayout.radiusL),
                              side: BorderSide(
                                color: rule.isEnabled
                                    ? cs.outlineVariant.withValues(alpha: 0.4)
                                    : cs.outlineVariant.withValues(alpha: 0.15),
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppLayout.radiusL),
                              onTap: () async {
                                final result = await TeachSmsRuleSheet.show(
                                  context: context,
                                  existingRule: rule,
                                );
                                if (result != null) {
                                  await SmsService.reloadSmsContacts();
                                  if (mounted) setState(() {});
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        // Keyword Badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: cs.primaryContainer,
                                            borderRadius: BorderRadius.circular(AppLayout.radiusS),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.key_rounded, size: 14, color: cs.onPrimaryContainer),
                                              const SizedBox(width: 4),
                                              Text(
                                                rule.keyword,
                                                style: tt.labelSmall?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: cs.onPrimaryContainer,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // Type Pill
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: typeColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(AppLayout.radiusS),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(typeIcon, size: 13, color: typeColor),
                                              const SizedBox(width: 3),
                                              Text(
                                                rule.type.label,
                                                style: tt.labelSmall?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: typeColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // Category Pill (if set)
                                        if (rule.category != null && rule.category!.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: cs.surfaceContainerHighest,
                                              borderRadius: BorderRadius.circular(AppLayout.radiusS),
                                            ),
                                            child: Text(
                                              rule.category!,
                                              style: tt.labelSmall?.copyWith(
                                                color: cs.onSurfaceVariant,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),

                                        // OTP Bypass Pill
                                        if (rule.bypassOtpFilter) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: cs.tertiaryContainer.withValues(alpha: 0.5),
                                              borderRadius: BorderRadius.circular(AppLayout.radiusS),
                                            ),
                                            child: Icon(Icons.lock_open_rounded, size: 13, color: cs.onTertiaryContainer),
                                          ),
                                        ],

                                        const Spacer(),

                                        // Enable/Disable Switch
                                        Switch.adaptive(
                                          value: rule.isEnabled,
                                          onChanged: (val) {
                                            AppHaptics.selectionClick();
                                            settings.toggleCustomSmsRule(rule.id);
                                            SmsService.reloadSmsContacts();
                                          },
                                        ),
                                      ],
                                    ),

                                    // Custom Description line if configured
                                    if (rule.customDescription != null && rule.customDescription!.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.label_outline_rounded,
                                            size: 14,
                                            color: cs.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Title: ${rule.customDescription}',
                                            style: tt.bodySmall?.copyWith(
                                              fontWeight: FontWeight.w500,
                                              color: cs.onSurface,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            const SizedBox(height: AppLayout.spaceM),

            // Link to Category Rules & Keywords
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 0,
                color: cs.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppLayout.radiusL),
                  side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: ListTile(
                  leading: Icon(Icons.category_outlined, color: cs.primary),
                  title: const Text('Category Rules & Keywords'),
                  subtitle: const Text('Edit category names, icons, colors, and auto-matching rules'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    AppRoute.push(context, const CategoryManagementScreen());
                  },
                ),
              ),
            ),

            const SizedBox(height: 32),
          ];

          return AnimationLimiter(
            child: Column(
              children: List.generate(
                items.length,
                (index) => AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 300),
                  child: SlideAnimation(
                    verticalOffset: 30.0,
                    child: FadeInAnimation(
                      child: items[index],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
        ],
      ),
    );
  }
}

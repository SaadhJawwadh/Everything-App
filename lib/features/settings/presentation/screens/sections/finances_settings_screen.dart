import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_layout.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../core/ui/expressive_sliver_app_bar.dart';
import '../../../../../utils/app_route.dart';
import '../../../../../widgets/settings_widgets.dart';
import '../../../../finances/presentation/screens/category_management_screen.dart';
import '../../../../finances/presentation/screens/sms_rules_screen.dart';
import '../../../../finances/presentation/widgets/recurring_rules_sheet.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../providers/settings_provider.dart';
import '../settings_dialogs.dart';

class FinancesSettingsScreen extends StatelessWidget {
  const FinancesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semanticColors = theme.extension<AppSemanticColors>();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          final l10n = AppLocalizations.of(context);
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              ExpressiveSliverAppBar(
                titleText: l10n?.financesAndHealthModules ?? 'Finances & Modules',
                showBackButton: true,
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppLayout.spaceXL,
                  vertical: AppLayout.spaceL,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    SettingsSection(
                      title: l10n?.modularEcosystem ?? 'Modular Ecosystem',
                      icon: Icons.apps_rounded,
                      accentColor: colorScheme.secondary,
                      children: [
                        SettingsSwitchTile(
                          icon: Icons.account_balance_wallet_outlined,
                          iconColor: const Color(0xFF10B981),
                          iconBackgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                          title: l10n?.financialManager ?? 'Financial Manager',
                          subtitle: l10n?.financialManagerSubtitle ?? 'Expense tracking, SMS bank ledger & budgets',
                          value: settings.showFinancialManager,
                          onChanged: settings.setShowFinancialManager,
                        ),
                        SettingsSwitchTile(
                          icon: Icons.calendar_month_outlined,
                          iconColor: const Color(0xFFF43F5E),
                          iconBackgroundColor: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                          title: l10n?.periodTracker ?? 'Period Tracker',
                          subtitle: l10n?.periodTrackerSubtitle ?? 'Optional cycle tracking & predictions',
                          value: settings.isPeriodTrackerEnabled,
                          onChanged: settings.setIsPeriodTrackerEnabled,
                        ),
                      ],
                    ),

                    if (settings.showFinancialManager) ...[
                      const SizedBox(height: AppLayout.spaceL),
                      SettingsSection(
                        title: l10n?.ledgerAndBankAutomation ?? 'Ledger & Bank Automation',
                        icon: Icons.account_balance_wallet_outlined,
                        accentColor: const Color(0xFF10B981),
                        children: [
                          SettingsTile(
                            icon: Icons.currency_exchange_outlined,
                            iconColor: const Color(0xFF10B981),
                            title: l10n?.currency ?? 'Currency',
                            subtitle: l10n?.currencySubtitle ?? 'Base ledger currency symbol',
                            valueBadge: settings.currencySymbol,
                            showArrow: true,
                            onTap: () => SettingsDialogs.showCurrencyPicker(context, settings),
                          ),
                          SettingsSwitchTile(
                            icon: Icons.sms_outlined,
                            iconColor: colorScheme.secondary,
                            title: l10n?.smsBankImport ?? 'SMS Bank Import',
                            subtitle: l10n?.smsBankImportSubtitle ?? 'Automatically import and parse transactions from bank SMS',
                            value: settings.enableSmsImport,
                            onChanged: settings.setEnableSmsImport,
                          ),
                          AnimatedSize(
                            duration: AppLayout.animModal,
                            curve: AppLayout.curveEmphasizedDecelerate,
                            child: settings.enableSmsImport
                                ? SettingsTile(
                                    icon: Icons.mark_chat_unread_outlined,
                                    iconColor: colorScheme.secondary,
                                    title: l10n?.smsAutomationRules ?? 'SMS & Bank Automation Rules',
                                    subtitle: l10n?.smsAutomationRulesSubtitle ?? 'Auto-sync, import rules, sender blocklist & parser testing',
                                    showArrow: true,
                                    onTap: () => AppRoute.push(context, const SmsRulesScreen()),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          SettingsSwitchTile(
                            icon: Icons.donut_large_outlined,
                            iconColor: colorScheme.tertiary,
                            title: l10n?.budgetsAndGoals ?? 'Budgets & Financial Goals',
                            subtitle: l10n?.budgetsAndGoalsSubtitle ?? 'Monthly spending limits, analytics chart deck & visual targets',
                            value: settings.enableBudgetsAndAnalytics,
                            onChanged: settings.setEnableBudgetsAndAnalytics,
                          ),
                          SettingsTile(
                            icon: Icons.category_outlined,
                            iconColor: colorScheme.tertiary,
                            title: l10n?.categoriesAndBudgets ?? 'Categories & Budgets',
                            subtitle: l10n?.categoriesAndBudgetsSubtitle ?? 'Customise keywords, budget allocations & colors',
                            showArrow: true,
                            onTap: () => AppRoute.push(context, const CategoryManagementScreen()),
                          ),
                          if (settings.isDeviceAiSupported)
                            SettingsSwitchTile(
                              icon: Icons.auto_awesome_outlined,
                              iconColor: colorScheme.primary,
                              title: l10n?.onDeviceSmartAi ?? 'On-Device Smart AI',
                              subtitle: l10n?.onDeviceSmartAiSubtitle ?? 'Smart merchant cleanup & automatic category classification',
                              value: settings.useOnDeviceAi,
                              onChanged: settings.setUseOnDeviceAi,
                            ),
                        ],
                      ),
                      const SizedBox(height: AppLayout.spaceL),
                      SettingsSection(
                        title: l10n?.accountsVaultsAndSplits ?? 'Accounts, Vaults & Splits',
                        icon: Icons.savings_outlined,
                        accentColor: colorScheme.tertiary,
                        children: [
                          SettingsSwitchTile(
                            icon: Icons.event_repeat_outlined,
                            iconColor: const Color(0xFF10B981),
                            title: l10n?.recurringRulesTitle ?? 'Recurring Subscriptions & Rules',
                            subtitle: l10n?.recurringRulesSubtitle ?? 'Track repeated bills, periodic income & salary reminders',
                            value: settings.enableRecurringRules,
                            onChanged: settings.setEnableRecurringRules,
                          ),
                          AnimatedSize(
                            duration: AppLayout.animModal,
                            curve: AppLayout.curveEmphasizedDecelerate,
                            child: settings.enableRecurringRules
                                ? SettingsTile(
                                    icon: Icons.edit_calendar_outlined,
                                    iconColor: const Color(0xFF10B981),
                                    title: l10n?.manageSubscriptions ?? 'Manage Subscriptions',
                                    subtitle: l10n?.manageSubscriptionsSubtitle ?? 'Manage repeating bills, salaries & automated rules',
                                    showArrow: true,
                                    onTap: () => RecurringRulesSheet.show(
                                      context: context,
                                      currency: settings.currencySymbol,
                                      onRulesUpdated: () {},
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          SettingsSwitchTile(
                            icon: Icons.account_balance_wallet_outlined,
                            iconColor: colorScheme.secondary,
                            iconBackgroundColor: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                            title: l10n?.savingsVaultDualAccounts ?? 'Savings Vault & Dual Accounts',
                            subtitle: l10n?.savingsVaultDualAccountsSubtitle ?? 'Separate daily operating cash flow from long-term savings',
                            value: settings.enableSavingsVault,
                            onChanged: settings.setEnableSavingsVault,
                          ),
                          AnimatedSize(
                            duration: AppLayout.animModal,
                            curve: AppLayout.curveEmphasizedDecelerate,
                            child: settings.enableSavingsVault
                                ? SettingsTile(
                                    icon: Icons.drive_file_rename_outline_rounded,
                                    iconColor: colorScheme.primary,
                                    title: l10n?.accountNamesAndRouting ?? 'Account Names & Routing',
                                    subtitle: '${settings.account1Name} & ${settings.account2Name}',
                                    showArrow: true,
                                    onTap: () => SettingsDialogs.showAccountNamingAndRoutingSheet(context, settings),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          SettingsSwitchTile(
                            icon: Icons.pie_chart_outline_rounded,
                            iconColor: colorScheme.tertiary,
                            iconBackgroundColor: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                            title: l10n?.splitBillsAndSharedDebts ?? 'Split Bills & Shared Debts',
                            subtitle: l10n?.splitBillsAndSharedDebtsSubtitle ?? 'Group bill splitting, friend balances & receipt scanner',
                            value: settings.showSplitBills,
                            onChanged: settings.setShowSplitBills,
                          ),
                          AnimatedSize(
                            duration: AppLayout.animModal,
                            curve: AppLayout.curveEmphasizedDecelerate,
                            child: settings.showSplitBills
                                ? SettingsTile(
                                    icon: Icons.account_balance_outlined,
                                    iconColor: colorScheme.secondary,
                                    title: l10n?.defaultPaymentDetails ?? 'Default Payment Details',
                                    subtitle: settings.defaultPaymentInfo.isNotEmpty
                                        ? settings.defaultPaymentInfo
                                        : 'WhatsApp / Bank Pay',
                                    showArrow: true,
                                    onTap: () => SettingsDialogs.showDefaultPaymentInfoDialog(context, settings),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ],

                    if (settings.isPeriodTrackerEnabled) ...[
                      const SizedBox(height: AppLayout.spaceL),
                      SettingsSection(
                        title: l10n?.healthAndPeriodTracker ?? 'Health & Period Tracker',
                        icon: Icons.calendar_month_outlined,
                        accentColor: semanticColors?.phaseMenstrual ?? colorScheme.tertiary,
                        children: [
                          SettingsSwitchTile(
                            icon: Icons.visibility_off_outlined,
                            iconColor: semanticColors?.phaseMenstrual ?? colorScheme.tertiary,
                            title: l10n?.discreetPrivacyMode ?? 'Discreet Privacy Mode',
                            subtitle: l10n?.discreetPrivacyModeSubtitle ?? 'Conceal cycle day numbers and phases on dashboard with tap-to-reveal',
                            value: settings.isDiscreetHealthMode,
                            onChanged: settings.setIsDiscreetHealthMode,
                          ),
                          SettingsTile(
                            icon: Icons.notifications_none_outlined,
                            iconColor: semanticColors?.phaseMenstrual ?? colorScheme.tertiary,
                            title: l10n?.discreetNotificationText ?? 'Discreet Notification Text',
                            subtitle: l10n?.discreetNotificationTextSubtitle ?? 'Text shown in cycle prediction alerts',
                            valueBadge: settings.discreetNotificationText,
                            showArrow: true,
                            onTap: () => SettingsDialogs.showNotificationTextDialog(context, settings),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: AppLayout.fabBottomPadding),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

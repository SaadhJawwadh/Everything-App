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
                      title: 'Modular Ecosystem',
                      icon: Icons.apps_rounded,
                      accentColor: colorScheme.secondary,
                      children: [
                        SettingsSwitchTile(
                          icon: Icons.account_balance_wallet_outlined,
                          iconColor: const Color(0xFF10B981),
                          iconBackgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                          title: 'Financial Manager',
                          subtitle: 'Expense tracking, SMS bank ledger & budgets',
                          value: settings.showFinancialManager,
                          onChanged: settings.setShowFinancialManager,
                        ),
                        SettingsSwitchTile(
                          icon: Icons.calendar_month_outlined,
                          iconColor: const Color(0xFFF43F5E),
                          iconBackgroundColor: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                          title: 'Period Tracker',
                          subtitle: 'Optional cycle tracking & predictions',
                          value: settings.isPeriodTrackerEnabled,
                          onChanged: settings.setIsPeriodTrackerEnabled,
                        ),
                      ],
                    ),

                    if (settings.showFinancialManager) ...[
                      const SizedBox(height: AppLayout.spaceL),
                      SettingsSection(
                        title: 'Ledger & Bank Automation',
                        icon: Icons.account_balance_wallet_outlined,
                        accentColor: const Color(0xFF10B981),
                        children: [
                          SettingsTile(
                            icon: Icons.currency_exchange_outlined,
                            iconColor: const Color(0xFF10B981),
                            title: 'Currency',
                            subtitle: 'Base ledger currency symbol',
                            valueBadge: settings.currencySymbol,
                            showArrow: true,
                            onTap: () => SettingsDialogs.showCurrencyPicker(context, settings),
                          ),
                          SettingsSwitchTile(
                            icon: Icons.sms_outlined,
                            iconColor: colorScheme.secondary,
                            title: 'SMS Bank Import',
                            subtitle: 'Automatically import and parse transactions from bank SMS',
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
                                    title: 'SMS & Bank Automation Rules',
                                    subtitle: 'Auto-sync, import rules, sender blocklist & parser testing',
                                    showArrow: true,
                                    onTap: () => AppRoute.push(context, const SmsRulesScreen()),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          SettingsSwitchTile(
                            icon: Icons.donut_large_outlined,
                            iconColor: colorScheme.tertiary,
                            title: 'Budgets & Financial Goals',
                            subtitle: 'Monthly spending limits, analytics chart deck & visual targets',
                            value: settings.enableBudgetsAndAnalytics,
                            onChanged: settings.setEnableBudgetsAndAnalytics,
                          ),
                          SettingsTile(
                            icon: Icons.category_outlined,
                            iconColor: colorScheme.tertiary,
                            title: 'Categories & Budgets',
                            subtitle: 'Customise keywords, budget allocations & colors',
                            showArrow: true,
                            onTap: () => AppRoute.push(context, const CategoryManagementScreen()),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppLayout.spaceL),
                      SettingsSection(
                        title: 'Accounts, Vaults & Splits',
                        icon: Icons.savings_outlined,
                        accentColor: colorScheme.tertiary,
                        children: [
                          SettingsSwitchTile(
                            icon: Icons.event_repeat_outlined,
                            iconColor: const Color(0xFF10B981),
                            title: 'Recurring Subscriptions & Rules',
                            subtitle: 'Track repeated bills, periodic income & salary reminders',
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
                                    title: 'Manage Subscriptions',
                                    subtitle: 'Manage repeating bills, salaries & automated rules',
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
                            title: 'Savings Vault & Dual Accounts',
                            subtitle: 'Separate daily operating cash flow from long-term savings',
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
                                    title: 'Account Names & Routing',
                                    subtitle: '${settings.account1Name} & ${settings.account2Name} • Category defaults',
                                    showArrow: true,
                                    onTap: () => SettingsDialogs.showAccountNamingAndRoutingSheet(context, settings),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          SettingsSwitchTile(
                            icon: Icons.pie_chart_outline_rounded,
                            iconColor: colorScheme.tertiary,
                            iconBackgroundColor: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                            title: 'Split Bills & Shared Debts',
                            subtitle: 'Group bill splitting, friend balances & receipt scanner',
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
                                    title: 'Default Payment Details',
                                    subtitle: settings.defaultPaymentInfo.isNotEmpty
                                        ? settings.defaultPaymentInfo
                                        : 'Set bank / mobile pay details for WhatsApp split reminders',
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
                        title: 'Health & Period Tracker',
                        icon: Icons.calendar_month_outlined,
                        accentColor: semanticColors?.phaseMenstrual ?? colorScheme.tertiary,
                        children: [
                          SettingsSwitchTile(
                            icon: Icons.visibility_off_outlined,
                            iconColor: semanticColors?.phaseMenstrual ?? colorScheme.tertiary,
                            title: 'Discreet Privacy Mode',
                            subtitle: 'Conceal cycle day numbers and phases on dashboard with tap-to-reveal',
                            value: settings.isDiscreetHealthMode,
                            onChanged: settings.setIsDiscreetHealthMode,
                          ),
                          SettingsTile(
                            icon: Icons.notifications_none_outlined,
                            iconColor: semanticColors?.phaseMenstrual ?? colorScheme.tertiary,
                            title: 'Discreet Notification Text',
                            subtitle: 'Text shown in cycle prediction alerts',
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

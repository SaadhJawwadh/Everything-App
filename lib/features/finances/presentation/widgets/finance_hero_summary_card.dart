import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/app_card.dart';
import '../../../../data/transaction_model.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../settings/providers/settings_provider.dart';
import 'account_transfer_sheet.dart';

/// Focused, high-signal operational hero summary card displaying:
/// - Net Cash Flow (Income vs Expense)
/// - Range Label and Trend Indicator
/// - Dual-Account Quick Filter Badges (Daily Checking vs. Savings Vault)
/// - Direct Account Transfer Shortcut
///
/// Predictive forecasting metrics (Pacing, Burn Rate gauges, and Month-End
/// projections) are consolidated cleanly on the Budgets & Analytics tab.
class FinanceHeroSummaryCard extends StatelessWidget {
  final bool isLoading;
  final double totalIncome;
  final double totalExpense;
  final double dailyCashFlow;
  final double savingsVaultCashFlow;
  final DateTimeRange selectedRange;
  final List<TransactionModel> transactions;
  final String currency;
  final String selectedAccount;
  final ValueChanged<String> onAccountSelected;
  final int? heroCardMode;
  final PageController? heroPageController;
  final ValueChanged<int>? onModeChanged;
  final VoidCallback? onPauseAutoCycle;

  const FinanceHeroSummaryCard({
    super.key,
    required this.isLoading,
    required this.totalIncome,
    required this.totalExpense,
    required this.dailyCashFlow,
    required this.savingsVaultCashFlow,
    required this.selectedRange,
    required this.transactions,
    required this.currency,
    required this.selectedAccount,
    required this.onAccountSelected,
    this.heroCardMode,
    this.heroPageController,
    this.onModeChanged,
    this.onPauseAutoCycle,
  });

  Widget _miniStat(
    TextTheme tt,
    IconData icon,
    String label,
    double amount,
    String currency,
    Color color,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Text(
              label,
              style: tt.labelSmall?.copyWith(color: color.withValues(alpha: 0.7)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$currency ${amount.toStringAsFixed(0)}',
          style: tt.titleSmall?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    if (isLoading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final net = totalIncome - totalExpense;
    final isPositive = net >= 0;
    final onColor = isPositive ? cs.onTertiaryContainer : cs.onErrorContainer;
    final rangeLabel = selectedRange.duration.inDays == 0
        ? DateFormat.MMMMEEEEd().format(selectedRange.start)
        : '${DateFormat.MMMd().format(selectedRange.start)} – ${DateFormat.MMMd().format(selectedRange.end)}';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    return AppCard(
      backgroundColor: isPositive
          ? cs.tertiaryContainer.withValues(alpha: isDark ? 0.22 : 0.55)
          : cs.errorContainer.withValues(alpha: isDark ? 0.22 : 0.52),
      borderRadius: AppLayout.radiusXL,
      border: BorderSide(
        color: isPositive
            ? cs.tertiary.withValues(alpha: isDark ? 0.35 : 0.45)
            : cs.error.withValues(alpha: isDark ? 0.35 : 0.45),
        width: 1.2,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Bar: Range Label + Trend Icon
          Row(
            children: [
              Expanded(
                child: Text(
                  rangeLabel,
                  style: tt.labelMedium?.copyWith(color: onColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                size: 20,
                color: onColor,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Primary Metric: Net Cash Flow
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '${isPositive ? '+' : '-'} $currency ${net.abs().toStringAsFixed(0)}',
                  style: tt.headlineMedium?.copyWith(
                    fontFamily: AppTheme.fontGoogleSansFlex,
                    fontFamilyFallback: AppTheme.fontFallbacks,
                    color: onColor,
                    fontWeight: FontWeight.bold,
                    fontVariations: AppTheme.buildFontVariations(
                      size: tt.headlineMedium?.fontSize ?? 28.0,
                      brightness: Theme.of(context).brightness,
                      weight: 700.0,
                      grade: 30.0,
                    ),
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isPositive ? 'Net Savings Surplus' : 'Net Cash Flow Deficit',
                style: tt.labelSmall?.copyWith(color: onColor.withValues(alpha: 0.8)),
              ),
            ],
          ),

          const SizedBox(height: 14.0),

          // Income / Expense breakdown Row
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  tt,
                  Icons.south_west,
                  l10n?.income ?? 'Income',
                  totalIncome,
                  currency,
                  onColor,
                ),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: _miniStat(
                  tt,
                  Icons.arrow_outward,
                  l10n?.expense ?? 'Expense',
                  totalExpense,
                  currency,
                  onColor,
                ),
              ),
            ],
          ),

          if (settings.enableSavingsVault) ...[
            const SizedBox(height: 12.0),

            // Dual Account Quick-Filter Badges (Daily Operating vs. Savings Vault)
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Filter by ${settings.account1Name}',
                    selected: selectedAccount == AccountType.daily,
                    child: InkWell(
                      onTap: () {
                        final newAccount = selectedAccount == AccountType.daily ? 'all' : AccountType.daily;
                        onAccountSelected(newAccount);
                      },
                      borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                      child: AnimatedContainer(
                        duration: AppLayout.animShort,
                        curve: AppLayout.curveExpressiveSpatial,
                        constraints: const BoxConstraints(minHeight: 48),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: selectedAccount == AccountType.daily ? onColor.withValues(alpha: 0.18) : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                          border: Border.all(color: onColor.withValues(alpha: selectedAccount == AccountType.daily ? 0.4 : 0.15)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.credit_card_outlined, size: 13, color: onColor.withValues(alpha: 0.85)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${settings.account1Name}: $currency ${dailyCashFlow.toStringAsFixed(0)}',
                                style: tt.labelSmall?.copyWith(
                                  fontFamily: AppTheme.fontGoogleSansFlex,
                                  fontFamilyFallback: AppTheme.fontFallbacks,
                                  color: onColor,
                                  fontWeight: selectedAccount == AccountType.daily ? FontWeight.bold : FontWeight.w500,
                                  fontVariations: AppTheme.buildFontVariations(
                                    size: tt.labelSmall?.fontSize ?? 11.0,
                                    brightness: Theme.of(context).brightness,
                                    weight: selectedAccount == AccountType.daily ? 700.0 : 500.0,
                                    grade: selectedAccount == AccountType.daily ? 30.0 : null,
                                  ),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Transfer between accounts',
                  child: Semantics(
                    button: true,
                    label: 'Transfer funds between ${settings.account1Name} and ${settings.account2Name}',
                    child: InkWell(
                      onTap: () {
                        AppHaptics.selectionClick();
                        AccountTransferSheet.show(context);
                      },
                      borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: onColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: onColor.withValues(alpha: 0.25)),
                        ),
                        child: Icon(
                          Icons.swap_horiz_rounded,
                          size: 18,
                          color: onColor,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Filter by ${settings.account2Name}',
                    selected: selectedAccount == AccountType.savings,
                    child: InkWell(
                      onTap: () {
                        final newAccount = selectedAccount == AccountType.savings ? 'all' : AccountType.savings;
                        onAccountSelected(newAccount);
                      },
                      borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                      child: AnimatedContainer(
                        duration: AppLayout.animShort,
                        curve: AppLayout.curveExpressiveSpatial,
                        constraints: const BoxConstraints(minHeight: 48),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: selectedAccount == AccountType.savings ? onColor.withValues(alpha: 0.18) : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                          border: Border.all(color: onColor.withValues(alpha: selectedAccount == AccountType.savings ? 0.4 : 0.15)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.account_balance_outlined, size: 13, color: onColor.withValues(alpha: 0.85)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${settings.account2Name}: $currency ${savingsVaultCashFlow.toStringAsFixed(0)}',
                                style: tt.labelSmall?.copyWith(
                                  fontFamily: AppTheme.fontGoogleSansFlex,
                                  fontFamilyFallback: AppTheme.fontFallbacks,
                                  color: onColor,
                                  fontWeight: selectedAccount == AccountType.savings ? FontWeight.bold : FontWeight.w500,
                                  fontVariations: AppTheme.buildFontVariations(
                                    size: tt.labelSmall?.fontSize ?? 11.0,
                                    brightness: Theme.of(context).brightness,
                                    weight: selectedAccount == AccountType.savings ? 700.0 : 500.0,
                                    grade: selectedAccount == AccountType.savings ? 30.0 : null,
                                  ),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

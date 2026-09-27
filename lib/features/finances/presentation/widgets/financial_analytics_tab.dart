import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../data/transaction_model.dart';
import '../../../../data/transaction_category.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_card.dart';
import 'burn_rate_forecast_card.dart';
import 'category_budgets_card.dart';
import 'savings_goals_card.dart';
import '../../services/spending_forecast_service.dart';

/// Modular Budgets & Intelligence Tab widget displaying:
/// 1. Sub-Segmented Deck: [ 🍩 Breakdown ] (Default) <-> [ 🎯 Budgets ]
/// 2. In Breakdown: Centered Interactive Donut + Ranked Category Spend with Bi-Directional Highlighting
/// 3. In Budgets: Daily Safe-to-Spend Burn Rate (if configured) + Category Budget Adjustments
class FinancialAnalyticsTab extends StatefulWidget {
  final List<TransactionModel> transactions;
  final List<Map<String, dynamic>> monthlyData;
  final String currency;
  final SettingsProvider settings;
  final VoidCallback onRefresh;
  final int initialDeckIndex; // 0: Breakdown, 1: Budgets

  const FinancialAnalyticsTab({
    super.key,
    required this.transactions,
    required this.monthlyData,
    required this.currency,
    required this.settings,
    required this.onRefresh,
    this.initialDeckIndex = 0,
  });

  @override
  State<FinancialAnalyticsTab> createState() => _FinancialAnalyticsTabState();
}

class _FinancialAnalyticsTabState extends State<FinancialAnalyticsTab> {
  late int _activeDeckIndex; // 0: Breakdown, 1: Budgets
  int? _touchedPieIndex;

  @override
  void initState() {
    super.initState();
    _activeDeckIndex = widget.initialDeckIndex;
  }

  @override
  void didUpdateWidget(covariant FinancialAnalyticsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDeckIndex != oldWidget.initialDeckIndex) {
      setState(() {
        _activeDeckIndex = widget.initialDeckIndex;
      });
    }
  }

  Map<String, double> _calculateCategoryExpenses() {
    final Map<String, double> totals = {};
    for (final t in widget.transactions) {
      if (t.isExpense) {
        totals[t.category] = (totals[t.category] ?? 0.0) + t.amount;
      }
    }
    return totals;
  }

  double _calculateTotalExpense() {
    return widget.transactions
        .where((t) => t.isExpense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    if (widget.transactions.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.track_changes_rounded,
                size: 64,
                color: colorScheme.outlineVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No financial data yet',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Log transactions to view spending breakdowns & set category budgets.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final forecast = SpendingForecastService.calculateMonthlyForecast(
      transactions: widget.transactions,
      categoryBudgets: widget.settings.categoryBudgets,
    );

    final categoryExpenses = _calculateCategoryExpenses();
    final totalExpense = _calculateTotalExpense();

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, AppLayout.fabBottomPadding),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // ── 1. Sub-Segmented Deep-Dive Toggle & Main Card ───────────
          AppCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Full-Width Segmented Pill Toggle
                _buildPillToggle(colorScheme, textTheme),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _activeDeckIndex == 0
                          ? 'EXPENSE DISTRIBUTION'
                          : _activeDeckIndex == 1
                              ? 'MONTHLY BUDGET LIMITS'
                              : 'SAVINGS GOALS & VAULT',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      _activeDeckIndex == 0
                          ? '${categoryExpenses.length} Categories'
                          : _activeDeckIndex == 1
                              ? 'Target Limits'
                              : 'Goal Pockets',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Animated View Switching
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOutCubic,
                  child: _activeDeckIndex == 0
                      ? _buildDetailedBreakdown(
                          categoryExpenses,
                          totalExpense,
                          colorScheme,
                          textTheme,
                        )
                      : _activeDeckIndex == 1
                          ? _buildBudgetsSection(
                              forecast,
                              categoryExpenses,
                              colorScheme,
                              textTheme,
                            )
                          : _buildSavingsSection(
                              colorScheme,
                              textTheme,
                            ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildPillToggle(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppLayout.radiusMAX),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          Expanded(
            child: _pillOption(
              title: 'Breakdown',
              icon: Icons.donut_large_rounded,
              isSelected: _activeDeckIndex == 0,
              onTap: () {
                if (_activeDeckIndex != 0) {
                  setState(() => _activeDeckIndex = 0);
                }
              },
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
          ),
          Expanded(
            child: _pillOption(
              title: 'Budgets',
              icon: Icons.track_changes_rounded,
              isSelected: _activeDeckIndex == 1,
              onTap: () {
                if (_activeDeckIndex != 1) {
                  setState(() => _activeDeckIndex = 1);
                }
              },
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
          ),
          Expanded(
            child: _pillOption(
              title: 'Savings',
              icon: Icons.savings_rounded,
              isSelected: _activeDeckIndex == 2,
              onTap: () {
                if (_activeDeckIndex != 2) {
                  setState(() => _activeDeckIndex = 2);
                }
              },
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.secondaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(AppLayout.radiusMAX),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? colorScheme.onSecondaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? colorScheme.onSecondaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetsSection(
    MonthlySpendingForecast forecast,
    Map<String, double> categoryExpenses,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final hasActiveBudgets = widget.settings.categoryBudgets.values.any((b) => b > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasActiveBudgets) ...[
          // Spending Pace & Daily Safe-to-Spend Forecast Card
          BurnRateForecastCard(
            forecast: forecast,
            currency: widget.currency,
            onAdjustBudgets: widget.onRefresh,
          ),
          const SizedBox(height: 16),
        ] else ...[
          // Friendly Budget Setup Prompt
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(AppLayout.radiusM),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.track_changes_rounded,
                      color: colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set Monthly Budgets',
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Assign limits below to unlock daily safe-to-spend pace and burn rate tracking.',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Category Budgets List & Goal Sliders
        CategoryBudgetsCard(
          categoryExpenses: categoryExpenses,
          settings: widget.settings,
          currency: widget.currency,
          onBudgetChanged: widget.onRefresh,
        ),
      ],
    );
  }

  Widget _buildSavingsSection(ColorScheme colorScheme, TextTheme textTheme) {
    return SavingsGoalsCard(
      currency: widget.currency,
      isEmbeddedInCard: true,
    );
  }

  Widget _buildDetailedBreakdown(
    Map<String, double> categoryExpenses,
    double totalExpense,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    if (categoryExpenses.isEmpty || totalExpense <= 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'No expense data in selected range.',
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final sortedEntries = categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final touched = _touchedPieIndex != null &&
        _touchedPieIndex! >= 0 &&
        _touchedPieIndex! < sortedEntries.length;

    final selectedEntry = touched ? sortedEntries[_touchedPieIndex!] : null;
    final selectedCat = selectedEntry?.key;
    final selectedAmount = selectedEntry?.value ?? totalExpense;
    final selectedPct = totalExpense > 0
        ? ((selectedAmount / totalExpense) * 100).toStringAsFixed(1)
        : '0.0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Interactive Centered Donut Chart ──────────────────────────
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SizedBox(
            height: 145,
            child: Semantics(
              label: 'Category spending breakdown donut chart. Total spent: ${widget.currency} ${NumberFormat('#,##0').format(totalExpense)}. Top category: ${sortedEntries.isNotEmpty ? sortedEntries.first.key : 'None'}',
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              _touchedPieIndex = null;
                              return;
                            }
                            final idx = pieTouchResponse
                                .touchedSection!.touchedSectionIndex;
                            if (idx >= 0 && idx < sortedEntries.length) {
                              if (_touchedPieIndex != idx) {
                                AppHaptics.selectionClick();
                                _touchedPieIndex = idx;
                              }
                            } else {
                              _touchedPieIndex = null;
                            }
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 2.5,
                      centerSpaceRadius: 42,
                      sections: List.generate(sortedEntries.length, (i) {
                        final isTouched = i == _touchedPieIndex;
                        final entry = sortedEntries[i];
                        final catColor = TransactionCategory.colorFor(entry.key);
                        final radius = isTouched ? 22.0 : 16.0;

                        // Enforce a minimum 1.5% visual angle floor so micro-slivers remain visible and crisp
                        final safeVal = totalExpense > 0
                            ? entry.value.clamp(totalExpense * 0.015, double.infinity)
                            : entry.value;

                        return PieChartSectionData(
                          color: catColor,
                          value: safeVal,
                          title: '',
                          radius: radius,
                        );
                      }),
                    ),
                  ),

                  // Center Hole Label (Total or Selected Category)
                  GestureDetector(
                    onTap: () {
                      if (_touchedPieIndex != null) {
                        setState(() => _touchedPieIndex = null);
                      }
                    },
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                selectedCat ?? 'Total Spent',
                                style: textTheme.labelSmall?.copyWith(
                                  color: selectedCat != null
                                      ? TransactionCategory.colorFor(selectedCat)
                                      : colorScheme.onSurfaceVariant,
                                  fontWeight: selectedCat != null
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  fontSize: 10,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${widget.currency} ${NumberFormat('#,##0').format(selectedAmount)}',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                selectedCat != null
                                    ? '$selectedPct%'
                                    : '${sortedEntries.length} categories',
                                style: textTheme.labelSmall?.copyWith(
                                  fontSize: 9,
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
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
            ),
          ),
        ),

        // ── Ranked Category Spend List ────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ranked Category Spend',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              '${(totalExpense > 0 ? 100 : 0)}% of total',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...sortedEntries.asMap().entries.map((item) {
          final i = item.key;
          final entry = item.value;
          final isSelected = i == _touchedPieIndex;
          final cat = entry.key;
          final amount = entry.value;
          final pct = totalExpense > 0 ? (amount / totalExpense) : 0.0;
          final catColor = TransactionCategory.colorFor(cat);
          final catIcon = TransactionCategory.iconFor(cat);

          final txCount = widget.transactions
              .where((t) => t.isExpense && t.category == cat)
              .length;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              AppHaptics.selectionClick();
              setState(() {
                _touchedPieIndex = isSelected ? null : i;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(vertical: 2.0),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? catColor.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppLayout.radiusS),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: catColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(catIcon, color: catColor, size: 14),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isSelected ? catColor : null,
                              ),
                            ),
                            Text(
                              '$txCount transaction${txCount == 1 ? '' : 's'}',
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${widget.currency} ${NumberFormat('#,##0.00').format(amount)}',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text(
                            '${(pct * 100).toStringAsFixed(1)}%',
                            style: textTheme.labelSmall?.copyWith(
                              color: catColor,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: pct.clamp(0.01, 1.0),
                    minHeight: 5,
                    backgroundColor: colorScheme.surfaceContainerLow,
                    valueColor: AlwaysStoppedAnimation<Color>(catColor),
                    borderRadius: BorderRadius.circular(AppLayout.radiusMAX),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

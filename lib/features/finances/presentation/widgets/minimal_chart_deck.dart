import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_card.dart';
import '../../../../data/transaction_category.dart';
import '../../../../services/financial_regression_engine.dart';
import '../../services/spending_forecast_service.dart';

/// Minimalist visual chart deck for the Ledger tab.
/// Features a dynamic 2-or-3 slide PageView:
/// 1. Minimal Spending Trend & Trajectory Curve
/// 2. Minimal Category Expense Donut Chart
/// 3. Monthly Budget Pacing & Daily Safe-to-Spend (when budget is configured)
/// Tapping the deck smoothly transitions the user to the Budgets / Details tab.
class MinimalChartDeck extends StatefulWidget {
  final List<Map<String, dynamic>> monthlyData;
  final Map<String, double> categoryExpenses;
  final double totalExpense;
  final String currency;
  final MonthlySpendingForecast? forecast;
  final VoidCallback? onTapDetails;
  final void Function(int page)? onTapDetailsWithPage;

  const MinimalChartDeck({
    super.key,
    required this.monthlyData,
    required this.categoryExpenses,
    required this.totalExpense,
    required this.currency,
    this.forecast,
    this.onTapDetails,
    this.onTapDetailsWithPage,
  });

  @override
  State<MinimalChartDeck> createState() => _MinimalChartDeckState();
}

class _MinimalChartDeckState extends State<MinimalChartDeck> {
  int _currentPage = 0;
  late final PageController _pageController;
  Timer? _autoCycleTimer;
  bool _userInteracted = false;
  int? _lastTouchedSpotIndex;
  int? _lastTouchedPieIndex;

  bool get _hasBudget =>
      widget.forecast != null && widget.forecast!.totalBudget > 0;
  int get _pageCount => _hasBudget ? 3 : 2;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoCycleTimer();
  }

  void _startAutoCycleTimer() {
    _autoCycleTimer?.cancel();
    if (_userInteracted) return;
    _autoCycleTimer =
        Timer.periodic(const Duration(milliseconds: 6000), (timer) {
      if (!mounted || _userInteracted || !_pageController.hasClients) {
        timer.cancel();
        return;
      }
      final nextPage = (_currentPage + 1) % _pageCount;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _pauseAutoCycle({bool userAction = true}) {
    if (userAction) {
      _userInteracted = true;
    }
    _autoCycleTimer?.cancel();
  }

  @override
  void dispose() {
    _autoCycleTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _handleDetailsTap() {
    widget.onTapDetailsWithPage?.call(_currentPage);
    widget.onTapDetails?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final title = _currentPage == 0
        ? 'Spending Trend'
        : _currentPage == 1
            ? 'Expense Breakdown'
            : 'Budget Pacing';

    final icon = _currentPage == 0
        ? Icons.show_chart_rounded
        : _currentPage == 1
            ? Icons.donut_large_rounded
            : Icons.track_changes_rounded;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_currentPage == 0 && widget.monthlyData.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _buildAverageBadge(colorScheme, textTheme),
                    ] else if (_currentPage == 2 && _hasBudget) ...[
                      const SizedBox(width: 6),
                      _buildBudgetBadge(colorScheme, textTheme, widget.forecast!),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: 'View detailed financial analytics and charts',
                child: InkWell(
                  onTap: _handleDetailsTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Details',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Swipable Visual Chart Area with Auto-Cycle Touch-Freeze
          Listener(
            onPointerDown: (_) => _pauseAutoCycle(userAction: true),
            child: GestureDetector(
              onTap: _handleDetailsTap,
              child: SizedBox(
                height: 125,
                child: PageView(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (page) {
                    setState(() => _currentPage = page);
                  },
                  children: [
                    _buildTrajectorySlide(colorScheme, textTheme),
                    _buildDonutSlide(colorScheme, textTheme),
                    if (_hasBudget)
                      _buildBudgetPaceSlide(
                          colorScheme, textTheme, widget.forecast!),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Interactive Page Indicator Dots
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_pageCount, (index) {
                final isSelected = _currentPage == index;
                final slideTitle = index == 0
                    ? 'Spending Trajectory'
                    : index == 1
                        ? 'Expense Breakdown'
                        : 'Budget Pacing';
                return Semantics(
                  button: true,
                  label: 'Switch to $slideTitle chart',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _pauseAutoCycle(userAction: true);
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                      );
                      setState(() => _currentPage = index);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        width: isSelected ? 16 : 6,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAverageBadge(ColorScheme colorScheme, TextTheme textTheme) {
    double total = 0.0;
    int count = 0;
    final expenses = <double>[];
    for (final d in widget.monthlyData) {
      final exp = (d['totalExpense'] as num?)?.toDouble() ??
          (d['expense'] as num?)?.toDouble() ??
          0.0;
      if (exp > 0) {
        total += exp;
        count++;
      }
      expenses.add(exp);
    }
    final avg = count > 0 ? (total / count) : 0.0;
    final formattedAvg = avg >= 1000
        ? '${(avg / 1000).toStringAsFixed(1)}k'
        : avg.toStringAsFixed(0);

    final regressionForecast =
        expenses.length >= 2 ? FinancialRegressionEngine.computeForecast(expenses) : null;
    final projectedSpend = widget.forecast != null && widget.forecast!.projectedMonthEndSpend > 0
        ? widget.forecast!.projectedMonthEndSpend
        : (regressionForecast?.projectedExpense);

    final formattedForecast = projectedSpend != null
        ? (projectedSpend >= 1000
            ? '${(projectedSpend / 1000).toStringAsFixed(1)}k'
            : projectedSpend.toStringAsFixed(0))
        : null;

    return Semantics(
      label: formattedForecast != null
          ? 'Estimated month end spending: $formattedForecast'
          : 'Average spending: $formattedAvg per month',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formattedForecast != null
                  ? 'Est ~$formattedForecast'
                  : 'Avg ~$formattedAvg/mo',
              style: textTheme.labelSmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            if (formattedForecast != null) ...[
              const SizedBox(width: 3),
              Icon(
                Icons.auto_awesome_rounded,
                size: 11,
                color: colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetBadge(
    ColorScheme colorScheme,
    TextTheme textTheme,
    MonthlySpendingForecast forecast,
  ) {
    final rem = forecast.remainingBudget;
    final formatted = rem >= 1000
        ? '${(rem / 1000).toStringAsFixed(1)}k'
        : rem.toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '${widget.currency} $formatted left',
        style: textTheme.labelSmall?.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  // ── Slide 1: Minimal Line Trajectory Chart with Seamless Forecast ───────────
  Widget _buildTrajectorySlide(ColorScheme colorScheme, TextTheme textTheme) {
    if (widget.monthlyData.isEmpty) {
      return Center(
        child: Text(
          'Log more months for trajectory analysis',
          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    final n = widget.monthlyData.length;
    final spots = <FlSpot>[];
    final expenses = <double>[];
    double maxVal = 0.0;

    for (int i = 0; i < n; i++) {
      final exp = (widget.monthlyData[i]['totalExpense'] as num?)?.toDouble() ??
          (widget.monthlyData[i]['expense'] as num?)?.toDouble() ??
          0.0;
      if (exp > maxVal) maxVal = exp;
      expenses.add(exp);
      spots.add(FlSpot(i.toDouble(), exp));
    }

    final regressionForecast =
        expenses.length >= 2 ? FinancialRegressionEngine.computeForecast(expenses) : null;
    final projectedSpend = widget.forecast != null && widget.forecast!.projectedMonthEndSpend > 0
        ? widget.forecast!.projectedMonthEndSpend
        : (regressionForecast?.projectedExpense);

    if (projectedSpend != null && projectedSpend > maxVal) {
      maxVal = projectedSpend;
    }
    if (maxVal == 0) maxVal = 100.0;

    final hasForecast = projectedSpend != null;
    final totalPoints = hasForecast ? n + 1 : n;

    // Build the line bar data list
    final lineBars = <LineChartBarData>[
      // 1. Historical actual spending curve (solid)
      LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.35,
        color: colorScheme.primary,
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) =>
              FlDotCirclePainter(
            radius: 3.5,
            color: colorScheme.primary,
            strokeWidth: 1.5,
            strokeColor: colorScheme.surface,
          ),
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primary.withValues(alpha: 0.22),
              colorScheme.primary.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),

      // 2. Seamless dashed forecast extension (from last actual to projected)
      if (hasForecast)
        LineChartBarData(
          spots: [
            spots.last,
            FlSpot(n.toDouble(), projectedSpend),
          ],
          isCurved: true,
          curveSmoothness: 0.35,
          color: colorScheme.tertiary,
          dashArray: [5, 4],
          barWidth: 2.5,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            checkToShowDot: (spot, barData) => spot.x == n.toDouble(),
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
              radius: 4.5,
              color: colorScheme.tertiary,
              strokeWidth: 2.0,
              strokeColor: colorScheme.surface,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.tertiary.withValues(alpha: 0.15),
                colorScheme.tertiary.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
    ];

    return Semantics(
      label:
          'Spending trajectory line chart showing monthly spending trends and projected month-end total of ~${widget.currency} ${NumberFormat('#,##0').format(projectedSpend ?? 0)}',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: LineChart(
          LineChartData(
            lineTouchData: LineTouchData(
              enabled: true,
              touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                if (!event.isInterestedForInteractions ||
                    touchResponse == null ||
                    touchResponse.lineBarSpots == null ||
                    touchResponse.lineBarSpots!.isEmpty) {
                  _lastTouchedSpotIndex = null;
                  return;
                }
                final spotIndex = touchResponse.lineBarSpots!.first.spotIndex;
                if (_lastTouchedSpotIndex != spotIndex) {
                  _lastTouchedSpotIndex = spotIndex;
                  AppHaptics.selectionClick();
                }
              },
              touchTooltipData: LineTouchTooltipData(
                showOnTopOfTheChartBoxArea: true,
                getTooltipColor: (_) => colorScheme.surfaceContainerHighest,
                tooltipRoundedRadius: AppLayout.radiusM,
                tooltipBorder: BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  width: 1.0,
                ),
                tooltipPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final xIndex = spot.x.toInt();
                    if (hasForecast && xIndex == n) {
                      final paceLabel = widget.forecast != null
                          ? (widget.forecast!.status == SpendingPaceStatus.overPace
                              ? 'Pacing Fast'
                              : widget.forecast!.status == SpendingPaceStatus.exhausted
                                  ? 'Exhausted'
                                  : 'On Track')
                          : (regressionForecast?.isTrendingUp == true
                              ? 'Trending Up'
                              : 'On Track');

                      return LineTooltipItem(
                        'This Month (Est.)\n',
                        textTheme.labelSmall?.copyWith(
                              color: colorScheme.tertiary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ) ??
                            const TextStyle(),
                        children: [
                          TextSpan(
                            text:
                                '~${widget.currency} ${NumberFormat('#,##0').format(spot.y)}\n',
                            style: textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: paceLabel,
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      );
                    }

                    if (xIndex >= 0 && xIndex < n) {
                      final m = widget.monthlyData[xIndex]['month'];
                      String monthName = '';
                      if (m is DateTime) {
                        monthName = DateFormat.MMMM().format(m);
                      } else if (m is String) {
                        monthName = m;
                      }
                      return LineTooltipItem(
                        '$monthName\n',
                        textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ) ??
                            const TextStyle(),
                        children: [
                          TextSpan(
                            text:
                                '${widget.currency} ${NumberFormat('#,##0').format(spot.y)}',
                            style: textTheme.labelMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                    }
                    return null;
                  }).whereType<LineTooltipItem>().toList();
                },
              ),
            ),
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 22,
                  interval: 1,
                  getTitlesWidget: (val, meta) {
                    final index = val.toInt();
                    if (hasForecast && index == n) {
                      final currentMonthName = widget.monthlyData.isNotEmpty
                          ? () {
                              final lastM = widget.monthlyData.last['month'];
                              if (lastM is DateTime) return DateFormat.MMM().format(lastM);
                              if (lastM is String) {
                                final parts = lastM.split('-');
                                return parts.length == 2 ? parts[1] : lastM;
                              }
                              return 'Est';
                            }()
                          : 'Est';

                      return Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          '$currentMonthName Est',
                          style: textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: colorScheme.tertiary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    }

                  if (index >= 0 && index < n) {
                    final m = widget.monthlyData[index]['month'];
                    String monthName = '';
                    if (m is DateTime) {
                      monthName = DateFormat.MMM().format(m);
                    } else if (m is String) {
                      final parts = m.split('-');
                      monthName = parts.length == 2 ? parts[1] : m;
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        monthName,
                        style: textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (totalPoints - 1).toDouble().clamp(0.0, 10.0),
          minY: 0,
          maxY: maxVal * 1.18,
          lineBarsData: lineBars,
        ),
      ),
    ),
  );
}

  // ── Slide 2: Minimal Category Donut Chart ──────────────────────────────────
  Widget _buildDonutSlide(ColorScheme colorScheme, TextTheme textTheme) {
    if (widget.categoryExpenses.isEmpty || widget.totalExpense <= 0) {
      return Center(
        child: Text(
          'No expenses recorded in this period',
          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    final sorted = widget.categoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topCategories = sorted.take(3).toList();

    return Row(
      children: [
        // Donut Chart with Center Total
        Expanded(
          flex: 4,
          child: Semantics(
            label: 'Category spending donut chart. Total spent: ${widget.currency} ${NumberFormat('#,##0').format(widget.totalExpense)}. Top category: ${topCategories.isNotEmpty ? topCategories.first.key : 'None'}',
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          _lastTouchedPieIndex = null;
                          return;
                        }
                        final idx = pieTouchResponse.touchedSection!.touchedSectionIndex;
                        if (idx >= 0 && idx < sorted.length) {
                          if (_lastTouchedPieIndex != idx) {
                            _lastTouchedPieIndex = idx;
                            AppHaptics.selectionClick();
                          }
                        } else {
                          _lastTouchedPieIndex = null;
                        }
                      },
                    ),
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                    sections: sorted.map((entry) {
                      final color = TransactionCategory.colorFor(entry.key);
                      final safeVal = widget.totalExpense > 0
                          ? entry.value.clamp(widget.totalExpense * 0.015, double.infinity)
                          : entry.value;
                      return PieChartSectionData(
                        color: color,
                        value: safeVal,
                        radius: 14,
                        showTitle: false,
                      );
                    }).toList(),
                  ),
                ),
                SizedBox(
                  width: 52,
                  height: 52,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Total',
                            style: textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '${widget.currency}${NumberFormat.compact().format(widget.totalExpense)}',
                            style: textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Compact Top 3 Legend Badges
        Expanded(
          flex: 5,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: topCategories.map((entry) {
              final catColor = TransactionCategory.colorFor(entry.key);
              final pct = (entry.value / widget.totalExpense) * 100;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: catColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        entry.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall?.copyWith(fontSize: 11),
                      ),
                    ),
                    Text(
                      '${pct.toStringAsFixed(0)}%',
                      style: textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── Slide 3: Minimal Budget Pacing & Daily Safe-to-Spend ───────────────────
  Widget _buildBudgetPaceSlide(
    ColorScheme colorScheme,
    TextTheme textTheme,
    MonthlySpendingForecast forecast,
  ) {
    final spentFraction = forecast.budgetSpentFraction.clamp(0.0, 1.0);
    final spentPct = (forecast.budgetSpentFraction * 100).toStringAsFixed(0);
    final isOverBudget = forecast.status == SpendingPaceStatus.exhausted ||
        forecast.status == SpendingPaceStatus.overPace;

    final ringColor = isOverBudget ? colorScheme.error : colorScheme.primary;

    final statusText = forecast.status == SpendingPaceStatus.exhausted
        ? 'Exhausted'
        : forecast.status == SpendingPaceStatus.overPace
            ? 'Pacing Fast'
            : 'On Track';

    return Semantics(
      label:
          'Budget pacing gauge. $spentPct percent spent. Daily safe to spend: ${widget.currency} ${NumberFormat('#,##0').format(forecast.dailySafeToSpend)}. Status: $statusText.',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
        child: Row(
          children: [
            // Left: Circular Pace Gauge
            SizedBox(
              width: 78,
              height: 78,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      value: spentFraction,
                      strokeWidth: 6.5,
                      strokeCap: StrokeCap.round,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$spentPct%',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: ringColor,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Spent',
                        style: textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Center Column: Daily Safe-to-Spend & Days Left
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Daily Safe-to-Spend',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '~${widget.currency} ${NumberFormat('#,##0').format(forecast.dailySafeToSpend)}',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isOverBudget ? colorScheme.error : colorScheme.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${forecast.remainingDays} days left',
                    style: textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: AppLayout.spaceM),

            // Right Column: Projected Month-End & Status Pill
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Projected Month-End',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '~${widget.currency} ${NumberFormat('#,##0').format(forecast.projectedMonthEndSpend)}',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isOverBudget ? colorScheme.error : colorScheme.onSurface,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isOverBudget
                          ? colorScheme.errorContainer
                          : colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusText,
                      style: textTheme.labelSmall?.copyWith(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: isOverBudget
                            ? colorScheme.onErrorContainer
                            : colorScheme.onPrimaryContainer,
                      ),
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
}

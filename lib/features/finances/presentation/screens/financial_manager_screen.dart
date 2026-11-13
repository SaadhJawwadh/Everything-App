import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import '../../../../data/transaction_model.dart';
import '../../../../data/transaction_category.dart';
import '../../../../services/sms_service.dart';
import 'package:note_taking_app/features/finances/presentation/screens/transaction_editor_screen.dart';
import '../../../../screens/app_lock_screen.dart';
import 'package:note_taking_app/features/finances/providers/financial_manager_provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_dialog.dart';

import '../widgets/financial_ledger_tab.dart';
import '../widgets/financial_analytics_tab.dart';
import '../widgets/minimal_chart_deck.dart';
import '../widgets/split_bills_tab.dart';
import '../widgets/finance_date_range_sheet.dart';
import '../widgets/finance_hero_summary_card.dart';
import '../widgets/finance_sms_sync_banner.dart';
import '../widgets/finance_top_bar.dart';
import '../../services/spending_forecast_service.dart';


class FinancialManagerScreen extends StatefulWidget {
  static final ValueNotifier<String?> tabRedirectNotifier = ValueNotifier<String?>(null);
  @Deprecated('Use FinancialManagerProvider.loadTransactions() or context.read<FinancialManagerProvider>() instead')
  static final ValueNotifier<int> refreshNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<String> activeTabNotifier = ValueNotifier<String>('Ledger');

  const FinancialManagerScreen({super.key});

  @override
  State<FinancialManagerScreen> createState() => _FinancialManagerScreenState();
}

class _FinancialManagerScreenState extends State<FinancialManagerScreen> with WidgetsBindingObserver {
  late String _selectedTab;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _analyticsSubView = 0; // 0: Breakdown, 1: Budgets
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final initialTab = FinancialManagerScreen.tabRedirectNotifier.value;
    if (initialTab != null) {
      _selectedTab = initialTab;
      FinancialManagerScreen.tabRedirectNotifier.value = null; // consume
    } else {
      _selectedTab = 'Ledger';
    }
    FinancialManagerScreen.activeTabNotifier.value = _selectedTab;
    FinancialManagerScreen.tabRedirectNotifier.addListener(_handleTabRedirect);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<FinancialManagerProvider>().loadTransactions();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<FinancialManagerProvider>().loadTransactions();
    }
  }

  void _handleTabRedirect() {
    final newTab = FinancialManagerScreen.tabRedirectNotifier.value;
    if (newTab != null && mounted) {
      setState(() {
        if (newTab == 'Ledger') {
          _selectedTab = 'Ledger';
        } else if (newTab == 'Split Bills') {
          _selectedTab = 'Split Bills';
        } else {
          _selectedTab = 'Budgets';
        }
      });
      FinancialManagerScreen.activeTabNotifier.value = _selectedTab;
      FinancialManagerScreen.tabRedirectNotifier.value = null; // consume
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _searchController.dispose();
    FinancialManagerScreen.tabRedirectNotifier.removeListener(_handleTabRedirect);
    super.dispose();
  }

  Future<void> _refreshTransactions({bool showLoading = false}) async {
    if (!mounted) return;
    await context.read<FinancialManagerProvider>().refreshTransactions(showLoading: showLoading);
  }

  List<dynamic> _buildGroupedTransactions(
    List<TransactionModel> transactions,
    String currency,
  ) {
    if (transactions.isEmpty) return [];
    final items = <dynamic>[];
    DateTime? lastDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Pre-calculate daily net spend per calendar day
    final dailyNetMap = <DateTime, double>{};
    for (final t in transactions) {
      if (t.category.toLowerCase() == 'transfer') continue;
      final tDate = DateTime(t.date.year, t.date.month, t.date.day);
      final delta = t.isExpense ? -t.amount : t.amount;
      dailyNetMap[tDate] = (dailyNetMap[tDate] ?? 0) + delta;
    }

    final numFormat = NumberFormat('#,##0.##');

    for (final t in transactions) {
      final tDate = DateTime(t.date.year, t.date.month, t.date.day);
      if (lastDate == null || tDate != lastDate) {
        String header;
        if (tDate == today) {
          header = 'Today';
        } else if (tDate == yesterday) {
          header = 'Yesterday';
        } else {
          header = DateFormat.MMMd().format(tDate);
        }

        final dailyNet = dailyNetMap[tDate];
        if (dailyNet != null && dailyNet != 0) {
          final sign = dailyNet < 0 ? '-' : '+';
          final formattedAmount = numFormat.format(dailyNet.abs());
          header = '$header • $sign$currency $formattedAmount';
        }

        items.add(header);
        lastDate = tDate;
      }
      items.add(t);
    }
    return items;
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final finProvider = context.read<FinancialManagerProvider>();
    final selectedPreset = await FinanceDateRangeSheet.show(
      context,
      currentRange: finProvider.selectedRange,
    );

    if (selectedPreset != null && selectedPreset != finProvider.selectedRange) {
      finProvider.setSelectedRange(selectedPreset);
    }
  }

  // ── Dashboard widgets ────────────────────────────────────────────────────

  Future<void> _quickImportRecentSms() async {
    final granted = await SmsService.hasPermission();
    if (!mounted) return;

    if (!granted) {
      final proceed = await AppDialog.showConfirm(
        context: context,
        title: 'SMS Access',
        message: 'This app needs permission to read your SMS messages '
            'so it can detect and import bank transactions.\n\n'
            'Only messages from recognised bank senders are processed. '
            'No messages are sent off-device or shared.',
        cancelLabel: 'Not now',
        confirmLabel: 'Allow',
      );
      if (proceed != true) return;

      AppLockScreen.ignoreNextResumeLock();
      final ok = await SmsService.requestPermissions();
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS permission is required to import transactions.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scanning messages from the last 24h...'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );

    // Non-blocking trigger of daily auto-sync pipeline
    unawaited(SmsService.performDailySyncManualTrigger());
  }

  Widget _buildHeroSummaryCard(
    FinancialManagerProvider finProvider,
    ColorScheme cs,
    TextTheme tt,
    String currency,
  ) {
    return FinanceHeroSummaryCard(
      isLoading: finProvider.isLoading,
      totalIncome: finProvider.totalIncome,
      totalExpense: finProvider.totalExpense,
      dailyCashFlow: finProvider.dailyCashFlow,
      savingsVaultCashFlow: finProvider.savingsVaultCashFlow,
      selectedRange: finProvider.selectedRange,
      transactions: finProvider.transactions,
      currency: currency,
      selectedAccount: finProvider.selectedAccount,
      onAccountSelected: (newAccount) {
        finProvider.setSelectedAccount(newAccount);
      },
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final settings = Provider.of<SettingsProvider>(context);
    final currency = settings.currencySymbol;
    final finProvider = Provider.of<FinancialManagerProvider>(context);

    return PopScope(
      canPop: !finProvider.isSelectionMode && !_isSearching,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (finProvider.isSelectionMode) {
          finProvider.clearSelection();
        } else if (_isSearching) {
          setState(() {
            _isSearching = false;
            _searchController.clear();
          });
          finProvider.setSearchQuery('');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AnimationLimiter(
          child: CustomScrollView(
            controller: _scrollController,
            slivers: _buildSlivers(colorScheme, textTheme, currency, settings, finProvider),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSlivers(
    ColorScheme colorScheme,
    TextTheme textTheme,
    String currency,
    SettingsProvider settings,
    FinancialManagerProvider finProvider,
  ) {
    final showBudgets = settings.enableBudgetsAndAnalytics;
    final showSplitBills = settings.showSplitBills;
    final effectiveTab = (showBudgets || _selectedTab != 'Budgets') && (showSplitBills || _selectedTab != 'Split Bills')
        ? _selectedTab
        : 'Ledger';

    return [
            SliverAppBar(
              pinned: true,
              floating: false,
              snap: false,
              primary: false,
              backgroundColor: Colors.transparent,
              elevation: 0,
              toolbarHeight: MediaQuery.of(context).padding.top + 72.0,
              titleSpacing: 0,
              automaticallyImplyLeading: false,
              flexibleSpace: Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 6,
                  left: 16,
                  right: 16,
                  bottom: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  border: null,
                ),
                child: Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    height: 60,
                    child: FinanceTopBar(
                      isSearching: _isSearching,
                      searchController: _searchController,
                      currency: currency,
                      onExitSearch: () {
                        setState(() {
                          _isSearching = false;
                          _searchController.clear();
                        });
                        context.read<FinancialManagerProvider>().setSearchQuery('');
                      },
                      onStartSearch: () {
                        setState(() {
                          if (_selectedTab != 'Ledger') {
                            _selectedTab = 'Ledger';
                          }
                          _isSearching = true;
                        });
                      },
                      onSelectDateRange: () => _selectDateRange(context),
                      onQuickImportRecentSms: _quickImportRecentSms,
                      onOpenSavingsGoals: () => setState(() => _selectedTab = 'Budgets'),
                      onRefreshTransactions: _refreshTransactions,
                    ),
                  ),
                ),
              ),
            ),

            if (finProvider.isSmsSyncing && settings.enableSmsImport && finProvider.smsSyncProgress != null)
              SliverToBoxAdapter(
                child: FinanceSmsSyncBanner(progress: finProvider.smsSyncProgress),
              ),

            // ── Hero summary card (net + income/expense breakdown) ────────
            // Only displayed for Ledger & Budgets tabs; Split Bills has its own dedicated Split Summary Hero Card
            if (effectiveTab != 'Split Bills')
              SliverToBoxAdapter(
                child: AnimationConfiguration.staggeredList(
                  position: 2,
                  duration: AppLayout.animShort,
                  child: SlideAnimation(
                    verticalOffset: 24.0,
                    child: FadeInAnimation(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _buildHeroSummaryCard(
                            finProvider, colorScheme, textTheme, currency),
                      ),
                    ),
                  ),
                ),
              ),

            // ── Tab selector ──────────────────────────────────────────────
            if (showBudgets || showSplitBills)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _buildTabSelector(colorScheme),
                ),
              )
            else
              const SliverToBoxAdapter(
                child: SizedBox(height: 12),
              ),
            if (effectiveTab == 'Ledger') ...[
        // ── Minimalist Visual Chart Deck on Ledger (Tap jumps to Budgets) ──
        if (showBudgets && (finProvider.categoryExpenses.isNotEmpty || finProvider.monthlyData.isNotEmpty)) ...[
          SliverToBoxAdapter(
            child: AnimationConfiguration.staggeredList(
              position: 3,
              duration: AppLayout.animShort,
              child: SlideAnimation(
                verticalOffset: 24.0,
                child: FadeInAnimation(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Consumer<SettingsProvider>(
                      builder: (context, settings, _) {
                        final forecast =
                            SpendingForecastService.calculateMonthlyForecast(
                          transactions: finProvider.transactions,
                          categoryBudgets: settings.categoryBudgets,
                        );
                        return MinimalChartDeck(
                          monthlyData: finProvider.monthlyData,
                          categoryExpenses: finProvider.categoryExpenses,
                          totalExpense: finProvider.totalDateExpense,
                          currency: currency,
                          forecast: forecast,
                          onTapDetailsWithPage: (page) {
                            setState(() {
                              _selectedTab = 'Budgets';
                              _analyticsSubView = (page == 2) ? 1 : 0;
                            });
                          },
                          onTapDetails: () {
                            setState(() {
                              _selectedTab = 'Budgets';
                              _analyticsSubView = 0;
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],

        // ── Active search query badge indicator (if query set and top bar not in search mode) ──
        if (finProvider.searchQuery.isNotEmpty && !_isSearching)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Clear search filter ${finProvider.searchQuery}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                      onTap: () {
                        _searchController.clear();
                        finProvider.setSearchQuery('');
                      },
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search, size: 14, color: colorScheme.onPrimaryContainer),
                                const SizedBox(width: 6),
                                Text(
                                  'Search: "${finProvider.searchQuery}"',
                                  style: textTheme.labelMedium?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.close_rounded, size: 16, color: colorScheme.onPrimaryContainer),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── Account Selector Segment ──────────────────────────────────
        if (settings.enableSavingsVault)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      showCheckmark: false,
                      avatar: const Icon(Icons.account_tree_outlined, size: 16),
                      label: const Text('All Accounts'),
                      selected: finProvider.selectedAccount == 'all',
                      onSelected: (_) {
                        finProvider.setSelectedAccount('all');
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      showCheckmark: false,
                      avatar: const Icon(Icons.credit_card_outlined, size: 16),
                      label: Text(settings.account1Name),
                      selected: finProvider.selectedAccount == AccountType.daily,
                      onSelected: (_) {
                        finProvider.setSelectedAccount(AccountType.daily);
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      showCheckmark: false,
                      avatar: const Icon(Icons.account_balance_outlined, size: 16),
                      label: Text(settings.account2Name),
                      selected: finProvider.selectedAccount == AccountType.savings,
                      onSelected: (_) {
                        finProvider.setSelectedAccount(AccountType.savings);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Category filter chips ────────────────────────────────────
        if (finProvider.activeCategories.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: AnimationConfiguration.staggeredList(
              position: 5,
              duration: AppLayout.animShort,
              child: SlideAnimation(
                verticalOffset: 24.0,
                child: FadeInAnimation(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            showCheckmark: false,
                            avatar: const Icon(Icons.all_inclusive, size: 16),
                            label: const Text('All Categories'),
                            selected: finProvider.selectedCategory == null,
                            onSelected: (_) {
                              finProvider.setSelectedCategory(null);
                            },
                          ),
                          const SizedBox(width: 8),
                          ...finProvider.activeCategories.map((cat) {
                            final catColor = TransactionCategory.colorFor(cat);
                            final catIcon = TransactionCategory.iconFor(cat);
                            final selected = finProvider.selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                showCheckmark: false,
                                avatar: Icon(
                                  catIcon,
                                  size: 16,
                                  color: selected ? catColor : colorScheme.onSurfaceVariant,
                                ),
                                label: Text(cat),
                                selected: selected,
                                onSelected: (_) {
                                  finProvider.setSelectedCategory(selected ? null : cat);
                                },
                                selectedColor: catColor.withValues(alpha: 0.2),
                                checkmarkColor: catColor,
                                labelStyle: TextStyle(
                                  color: selected ? catColor : colorScheme.onSurfaceVariant,
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                ),
                                side: BorderSide(
                                  color: selected ? catColor : colorScheme.outline,
                                  width: selected ? 1.5 : 0.5,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],

        // ── Transaction list ──────────────────────────────────────────
            if (finProvider.isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else
              FinancialLedgerTab(
                groupedTransactions: _buildGroupedTransactions(finProvider.transactions, currency),
                currency: currency,
                onRefresh: _refreshTransactions,
                onDuplicate: (transaction) async {
                  final duplicate = TransactionModel(
                    amount: transaction.amount,
                    description: '${transaction.description} (Copy)',
                    date: DateTime.now(),
                    isExpense: transaction.isExpense,
                    category: transaction.category,
                    smsId: null,
                    account: transaction.account,
                  );
                  await finProvider.addTransaction(duplicate);
                  if (mounted) {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Duplicated "${transaction.description}"'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                onDelete: (transaction) async {
                  if (transaction.id != null) {
                    await finProvider.deleteTransaction(transaction.id!);
                  }

                  if (mounted) {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Deleted "${transaction.description}"'),
                        behavior: SnackBarBehavior.floating,
                        action: SnackBarAction(
                          label: 'UNDO',
                          onPressed: () async {
                            if (transaction.id != null) {
                              await finProvider.restoreTransaction(transaction.id!);
                            }
                          },
                        ),
                      ),
                    );
                  }
                },
                onUndoDelete: (transaction) async {
                  if (transaction.id != null) {
                    await finProvider.restoreTransaction(transaction.id!);
                  }
                },
                onAddFirstTransaction: () async {
                  if (!mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TransactionEditorScreen(),
                    ),
                  );
                  await _refreshTransactions();
                },
              ),
      ] else if (effectiveTab == 'Budgets') ...[
        // ── Tab 2: Budgets & Intelligence Dashboard ────────────────────
        Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            return FinancialAnalyticsTab(
              transactions: finProvider.transactions,
              monthlyData: finProvider.monthlyData,
              currency: currency,
              settings: settings,
              onRefresh: _refreshTransactions,
              initialDeckIndex: _analyticsSubView,
            );
          },
        ),
      ] else if (effectiveTab == 'Split Bills') ...[
        // ── Tab 3: Split Bills & Shared Liabilities ──────────────────
        const SliverFillRemaining(
          hasScrollBody: true,
          child: SplitBillsTab(),
        ),
      ],
    ];
  }

  // Helper tab selector: 2 or 3-segment toggle for Ledger, Budgets & Split Bills
  Widget _buildTabSelector(ColorScheme colorScheme) {
    final settings = Provider.of<SettingsProvider>(context);
    final showBudgets = settings.enableBudgetsAndAnalytics;
    final showSplitBills = settings.showSplitBills;

    if (!showBudgets && !showSplitBills) {
      return const SizedBox.shrink();
    }

    final effectiveSelected = (showBudgets || _selectedTab != 'Budgets') && (showSplitBills || _selectedTab != 'Split Bills')
        ? _selectedTab
        : 'Ledger';

    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment<String>(
            value: 'Ledger',
            label: Text(l10n?.ledger ?? 'Ledger', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
            icon: const Icon(Icons.receipt_long_outlined, size: 18),
          ),
          if (showBudgets)
            ButtonSegment<String>(
              value: 'Budgets',
              label: Text(l10n?.budgets ?? 'Budgets', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
              icon: const Icon(Icons.track_changes_rounded, size: 18),
            ),
          if (showSplitBills)
            ButtonSegment<String>(
              value: 'Split Bills',
              label: Text(l10n?.splitBillsTitle ?? 'Split Bills', maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
              icon: const Icon(Icons.pie_chart_outline_rounded, size: 18),
            ),
        ],
        selected: {effectiveSelected},
        onSelectionChanged: (Set<String> newSelection) {
          final finProvider = Provider.of<FinancialManagerProvider>(context, listen: false);
          if (finProvider.isSelectionMode) {
            finProvider.clearSelection();
          }
          setState(() {
            _selectedTab = newSelection.first;
          });
          FinancialManagerScreen.activeTabNotifier.value = newSelection.first;
          if (_scrollController.hasClients && _scrollController.offset > 0) {
            _scrollController.jumpTo(0.0);
          }
        },
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          selectedBackgroundColor: colorScheme.secondaryContainer,
          selectedForegroundColor: colorScheme.onSecondaryContainer,
          backgroundColor: colorScheme.surfaceContainerLow,
          foregroundColor: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/app_haptics.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import '../../data/transaction_repository.dart';
import '../../../../data/repositories/recurring_rule_repository.dart';
import '../../../../data/transaction_model.dart';
import '../../../../data/transaction_category.dart';
import '../../../../services/sms_service.dart';
import '../../../../services/sms_constants.dart';
import 'package:note_taking_app/features/finances/presentation/screens/transaction_editor_screen.dart';
import 'package:note_taking_app/features/finances/presentation/screens/sms_rules_screen.dart';
import 'package:note_taking_app/features/settings/presentation/screens/settings_screen.dart';
import '../../../../screens/app_lock_screen.dart';
import '../../../../utils/app_route.dart';
import 'package:note_taking_app/features/finances/providers/financial_manager_provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_dialog.dart';
import '../../../../core/ui/expressive_wavy_progress.dart';

import '../../../../widgets/bouncing_widget.dart';
import '../widgets/sms_import_sheet.dart';
import '../widgets/financial_trash_sheet.dart';
import '../widgets/account_transfer_sheet.dart';
import '../widgets/financial_ledger_tab.dart';
import '../widgets/financial_analytics_tab.dart';
import '../widgets/minimal_chart_deck.dart';
import '../widgets/recurring_rules_sheet.dart';
import '../widgets/savings_goal_editor_sheet.dart';
import '../widgets/split_bills_tab.dart';
import '../widgets/finance_date_range_sheet.dart';
import '../widgets/finance_hero_summary_card.dart';
import '../../services/financial_export_service.dart';
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
  DateTimeRange _selectedRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );
  List<TransactionModel> _transactions = [];
  List<TransactionModel> _allDateFiltered = [];
  bool _isLoading = true;
  String? _selectedCategory;
  String _selectedAccount = 'all'; // 'all', 'daily', 'savings'
  List<String> _activeCategories = [];
  late String _selectedTab;

  List<Map<String, dynamic>> _monthlyData = [];
  int _trashedCount = 0;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _analyticsSubView = 0; // 0: Breakdown, 1: Budgets
  String _searchQuery = '';
  bool _isSearching = false;

  StreamSubscription<TransactionModel>? _smsSubscription;
  StreamSubscription<SmsSyncProgress>? _smsProgressSub;
  bool _isSmsSyncing = false;
  SmsSyncProgress? _lastSmsProgress;

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
    FinancialManagerScreen.refreshNotifier.addListener(_handleExternalRefresh);
    _refreshTransactions(showLoading: true);
    _smsSubscription = SmsService.incomingTransactions.listen((t) async {
      if (!mounted) return;
      await _refreshTransactions();
    });
    _smsProgressSub = SmsService.syncProgressStream.listen((progress) {
      if (!mounted) return;
      final wasSyncing = _isSmsSyncing;
      setState(() {
        _isSmsSyncing = progress.isSyncing;
        _lastSmsProgress = progress;
      });
      if (wasSyncing && !progress.isSyncing) {
        _refreshTransactions(showLoading: false);
        if (progress.message != 'Sync cancelled by user') {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    progress.found > 0 ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      progress.found > 0
                          ? (progress.alreadyImported > 0
                              ? 'Synced ${progress.found} new transaction${progress.found == 1 ? "" : "s"} (${progress.alreadyImported} already up-to-date)'
                              : 'Synced ${progress.found} new transaction${progress.found == 1 ? "" : "s"} from the last 24h')
                          : (progress.alreadyImported > 0
                              ? 'Up to date • ${progress.alreadyImported} transaction${progress.alreadyImported == 1 ? " was" : "s were"} already imported'
                              : 'Up to date • No new transactions found in the last 24h'),
                    ),
                  ),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshTransactions();
    }
  }

  void _handleExternalRefresh() {
    if (mounted) {
      _refreshTransactions();
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
    FinancialManagerScreen.refreshNotifier.removeListener(_handleExternalRefresh);
    _smsSubscription?.cancel();
    _smsProgressSub?.cancel();
    super.dispose();
  }

  Map<String, double> get _categoryExpenses {
    final Map<String, double> totals = {};
    for (final t in _allDateFiltered) {
      if (t.isExpense && t.category.toLowerCase() != 'transfer') {
        totals[t.category] = (totals[t.category] ?? 0.0) + t.amount;
      }
    }
    return totals;
  }

  double get _totalDateExpense {
    return _allDateFiltered
        .where((t) => t.isExpense && t.category.toLowerCase() != 'transfer')
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  Future<void> _refreshTransactions({bool showLoading = false}) async {
    if (showLoading && _transactions.isEmpty) {
      setState(() {
        _isLoading = true;
      });
    }
    // Materialize any recurring transactions that came due since last visit.
    try {
      await RecurringRuleRepository.instance.materializeDueRules();
    } catch (e) {
      debugPrint('Recurring materialization error: $e');
    }
    final allTransactions = await TransactionRepository.instance.readAllTransactions();

    _allDateFiltered = allTransactions.where((t) {
      // Filter out any orphan reversal sentinels
      if (t.category == SmsConstants.reversalSentinel) return false;
      final tDate = DateTime(t.date.year, t.date.month, t.date.day);
      final start = DateTime(_selectedRange.start.year,
          _selectedRange.start.month, _selectedRange.start.day);
      final end = DateTime(_selectedRange.end.year, _selectedRange.end.month,
          _selectedRange.end.day);
      return tDate.isAfter(start.subtract(const Duration(days: 1))) &&
          tDate.isBefore(end.add(const Duration(days: 1)));
    }).toList();

    _monthlyData =
        await TransactionRepository.instance.getMonthlyTransactionSummary(6);

    final trashed = await TransactionRepository.instance.readTrashedTransactions();

    _applyFilters();
    if (mounted) {
      setState(() {
        _trashedCount = trashed.length;
      });
      unawaited(context.read<FinancialManagerProvider>().loadTransactions());
    }
  }

  /// Applies account, category, and search filters from the cached [_allDateFiltered]
  /// list. No DB call, no loading spinner — instant.
  void _applyFilters() {
    final activeCategories =
        _allDateFiltered.map((t) => t.category).toSet().toList()..sort();

    var filtered = _allDateFiltered;

    if (_selectedAccount != 'all') {
      filtered = filtered.where((t) => t.account == _selectedAccount).toList();
    }

    if (_selectedCategory != null) {
      filtered = filtered.where((t) => t.category == _selectedCategory).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((t) =>
              t.description.toLowerCase().contains(_searchQuery) ||
              t.category.toLowerCase().contains(_searchQuery))
          .toList();
    }

    setState(() {
      _activeCategories = activeCategories;
      _transactions = filtered;
      _isLoading = false;
    });
  }

  double get _dailyCashFlow {
    return _allDateFiltered
        .where((t) => t.account != AccountType.savings)
        .fold(0.0, (sum, t) => sum + (t.isExpense ? -t.amount : t.amount));
  }

  double get _savingsVaultCashFlow {
    return _allDateFiltered
        .where((t) => t.account == AccountType.savings)
        .fold(0.0, (sum, t) => sum + (t.isExpense ? -t.amount : t.amount));
  }

  double get _totalExpense {
    return _transactions
        .where((t) => t.isExpense && t.category.toLowerCase() != 'transfer')
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get _totalIncome {
    return _transactions
        .where((t) => !t.isExpense && t.category.toLowerCase() != 'transfer')
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  /// Flat list of [String] date-header labels and [TransactionModel] items,
  /// ordered newest-first, for the grouped transaction list.
  List<dynamic> get _groupedTransactions {
    if (_transactions.isEmpty) return [];
    final items = <dynamic>[];
    DateTime? lastDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Pre-calculate daily net spend per calendar day
    final dailyNetMap = <DateTime, double>{};
    for (final t in _transactions) {
      if (t.category.toLowerCase() == 'transfer') continue;
      final tDate = DateTime(t.date.year, t.date.month, t.date.day);
      final delta = t.isExpense ? -t.amount : t.amount;
      dailyNetMap[tDate] = (dailyNetMap[tDate] ?? 0) + delta;
    }

    final currency = context.read<SettingsProvider>().currencySymbol;
    final numFormat = NumberFormat('#,##0.##');

    for (final t in _transactions) {
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
    final selectedPreset = await FinanceDateRangeSheet.show(
      context,
      currentRange: _selectedRange,
    );

    if (selectedPreset != null && selectedPreset != _selectedRange) {
      setState(() => _selectedRange = selectedPreset);
      await _refreshTransactions();
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

  Widget _buildHeroSummaryCard(ColorScheme cs, TextTheme tt, String currency) {
    return FinanceHeroSummaryCard(
      isLoading: _isLoading,
      totalIncome: _totalIncome,
      totalExpense: _totalExpense,
      dailyCashFlow: _dailyCashFlow,
      savingsVaultCashFlow: _savingsVaultCashFlow,
      selectedRange: _selectedRange,
      transactions: _transactions,
      currency: currency,
      selectedAccount: _selectedAccount,
      onAccountSelected: (newAccount) {
        setState(() => _selectedAccount = newAccount);
        _applyFilters();
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
            _searchQuery = '';
            _applyFilters();
          });
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            AnimationLimiter(
              child: CustomScrollView(
                controller: _scrollController,
                slivers: _buildSlivers(colorScheme, textTheme, currency, settings, finProvider),
              ),
            ),
            if (finProvider.isSmsSyncing && finProvider.smsSyncProgress != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 70,
                left: 16,
                right: 16,
                child: _buildSyncProgressBanner(context, finProvider.smsSyncProgress!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncProgressBanner(BuildContext context, SmsSyncProgress progress) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppLayout.radiusMAX),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              progress.total > 0
                  ? 'Scanning SMS (${progress.scanned}/${progress.total})... Found ${progress.found}'
                  : progress.message ?? 'Scanning bank messages in background...',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (progress.isSyncing) ...[
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'Cancel sync',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  AppHaptics.selectionClick();
                  SmsService.cancelSync();
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppLayout.radiusMAX),
                      ),
                      child: Text(
                        'Cancel',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchModeHeader(ColorScheme colorScheme, TextTheme textTheme) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Exit search',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          visualDensity: VisualDensity.compact,
          onPressed: () {
            setState(() {
              _isSearching = false;
              _searchController.clear();
              _searchQuery = '';
              _applyFilters();
            });
          },
        ),
        Expanded(
          child: TextField(
            controller: _searchController,
            autofocus: true,
            style: textTheme.titleMedium,
            enableInteractiveSelection: true,
            textCapitalization: TextCapitalization.sentences,
            autocorrect: true,
            decoration: InputDecoration(
              hintText: 'Search transactions, categories...',
              hintStyle: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              filled: false,
              fillColor: Colors.transparent,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim().toLowerCase();
                _applyFilters();
              });
            },
            onSubmitted: (_) {
              FocusScope.of(context).unfocus();
            },
          ),
        ),
        if (_searchQuery.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: 'Clear query',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            visualDensity: VisualDensity.compact,
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _applyFilters();
              });
            },
          ),
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          visualDensity: VisualDensity.compact,
          onPressed: () {
            FocusScope.of(context).unfocus();
          },
        ),
      ],
    );
  }

  Widget _buildNormalHeader(ColorScheme colorScheme, TextTheme textTheme, String currency, bool isDark) {
    final settings = Provider.of<SettingsProvider>(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Finances',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 3),
              Semantics(
                button: true,
                label:
                    'Selected date range: ${_selectedRange.duration.inDays == 0 ? DateFormat.MMMd().format(_selectedRange.start) : '${DateFormat.MMMd().format(_selectedRange.start)} to ${DateFormat.MMMd().format(_selectedRange.end)}'}. Tap to change filter',
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                  onTap: () {
                    _selectDateRange(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: isDark ? 0.35 : 0.45),
                      borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.28),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 13,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _selectedRange.duration.inDays == 0
                                ? DateFormat.MMMd().format(_selectedRange.start)
                                : '${DateFormat.MMMd().format(_selectedRange.start)} – ${DateFormat.MMMd().format(_selectedRange.end)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 14,
                          color: colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: AppLocalizations.of(context)?.searchFinances ?? 'Search transactions',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          visualDensity: VisualDensity.compact,
          onPressed: () {
            setState(() {
              if (_selectedTab != 'Ledger') {
                _selectedTab = 'Ledger';
              }
              _isSearching = true;
            });
          },
        ),
        if (settings.enableSmsImport)
          Semantics(
            button: true,
            label:
                'Sync SMS transactions. Tap for quick sync, hold for advanced import options',
            child: Tooltip(
              message: 'Quick Sync (Tap) | Advanced Import (Hold)',
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                child: BouncingWidget(
                  onTap: () {
                    _quickImportRecentSms();
                  },
                  onLongPress: () {
                    AppHaptics.mediumImpact();
                    SmsImportSheet.show(context);
                  },
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _isSmsSyncing
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.primary,
                                ),
                              ),
                            )
                          : const Icon(Icons.sync_rounded),
                    ),
                  ),
                ),
              ),
            ),
          ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          tooltip: 'Finances Tools',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          elevation: 3,
          shadowColor: colorScheme.shadow.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppLayout.radiusXL),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          color: colorScheme.surfaceContainerHigh,
          onSelected: (value) {
            if (value == 'savings_goals') {
              setState(() => _selectedTab = 'Budgets');
              SavingsGoalEditorSheet.show(context).then((_) {
                if (mounted) _refreshTransactions();
              });
            } else if (value == 'sms_rules') {
              AppRoute.push(context, const SmsRulesScreen());
            } else if (value == 'recurring') {
              RecurringRulesSheet.show(
                context: context,
                currency: currency,
                onRulesUpdated: _refreshTransactions,
              );
            } else if (value == 'export') {
              FinancialExportService.showExportSheet(
                context,
                _transactions,
                currency: currency,
              );
            } else if (value == 'transfer') {
              AccountTransferSheet.show(context).then((_) {
                if (mounted) _refreshTransactions();
              });
            } else if (value == 'trash') {
              FinancialTrashSheet.show(context).then((_) {
                if (mounted) _refreshTransactions();
              });
            }
          },
          itemBuilder: (ctx) {
            final menuSettings = ctx.read<SettingsProvider>();
            return [
              if (menuSettings.enableSmsImport)
                PopupMenuItem(
                  value: 'sms_rules',
                  height: 48,
                  child: Row(
                    children: [
                      Icon(Icons.flash_on_rounded, size: 20, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Text('SMS & Bank Automation', style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              if (menuSettings.enableBudgetsAndAnalytics)
                PopupMenuItem(
                  value: 'savings_goals',
                  height: 48,
                  child: Row(
                    children: [
                      Icon(Icons.flag_rounded, size: 20, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Text('Savings Goals & Pockets', style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              if (menuSettings.enableRecurringRules)
                PopupMenuItem(
                  value: 'recurring',
                  height: 48,
                  child: Row(
                    children: [
                      Icon(Icons.repeat_outlined, size: 20, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Text('Recurring Subscriptions', style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              if (menuSettings.enableSavingsVault)
                PopupMenuItem(
                  value: 'transfer',
                  height: 48,
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz_rounded, size: 20, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Text('Transfer Between Accounts', style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'export',
                height: 48,
                child: Row(
                  children: [
                    Icon(Icons.ios_share_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Text('Export Ledger', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'trash',
                height: 48,
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Trash Bin', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
                    ),
                    if (_trashedCount > 0)
                      Badge(
                        label: Text('$_trashedCount'),
                        backgroundColor: colorScheme.error,
                      ),
                  ],
                ),
              ),
            ];
          },
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          visualDensity: VisualDensity.compact,
          onPressed: () {
            AppRoute.push(context, const SettingsScreen())
                .then((_) => _refreshTransactions());
          },
        ),
      ],
    );
  }

  Widget _buildSmsSyncProgressBanner(
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isDark,
  ) {
    final scanned = _lastSmsProgress?.scanned ?? 0;
    final total = _lastSmsProgress?.total ?? 0;
    final found = _lastSmsProgress?.found ?? 0;
    final progressVal = total > 0 ? (scanned / total).clamp(0.0, 1.0) : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh.withValues(alpha: isDark ? 0.90 : 0.95),
          borderRadius: BorderRadius.circular(AppLayout.radiusM),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.30),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: progressVal,
                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    total > 0
                        ? 'Scanning $scanned / $total messages • $found found'
                        : 'Scanning messages from the last 24h...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  label: 'Cancel sync',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppLayout.radiusS),
                    onTap: () {
                      AppHaptics.selectionClick();
                      SmsService.cancelSync();
                    },
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        'Cancel',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ExpressiveWavyLinearProgress(
              value: progressVal,
              height: 4.0,
              color: colorScheme.primary,
              backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionModeHeader(
    ColorScheme colorScheme,
    TextTheme textTheme,
    FinancialManagerProvider finProvider,
  ) {
    final validTxIds = _transactions.where((t) => t.id != null).map((t) => t.id!).toList();
    final allSelected = validTxIds.isNotEmpty &&
        validTxIds.every((id) => finProvider.selectedTransactionIds.contains(id));

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Clear selection',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          visualDensity: VisualDensity.compact,
          onPressed: () {
            AppHaptics.selectionClick();
            finProvider.clearSelection();
          },
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${finProvider.selectedCount} selected',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
        ),
        IconButton(
          icon: Icon(allSelected ? Icons.deselect_rounded : Icons.select_all_rounded),
          tooltip: allSelected ? 'Deselect all' : 'Select all',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          visualDensity: VisualDensity.compact,
          onPressed: () {
            AppHaptics.selectionClick();
            if (allSelected) {
              finProvider.clearSelection();
            } else {
              finProvider.selectAll(_transactions);
            }
          },
        ),
      ],
    );
  }

  List<Widget> _buildSlivers(
    ColorScheme colorScheme,
    TextTheme textTheme,
    String currency,
    SettingsProvider settings,
    FinancialManagerProvider finProvider,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                    child: finProvider.isSelectionMode
                        ? _buildSelectionModeHeader(colorScheme, textTheme, finProvider)
                        : _isSearching
                            ? _buildSearchModeHeader(colorScheme, textTheme)
                            : _buildNormalHeader(colorScheme, textTheme, currency, isDark),
                  ),
                ),
              ),
            ),

            if (_isSmsSyncing && settings.enableSmsImport)
              SliverToBoxAdapter(
                child: _buildSmsSyncProgressBanner(colorScheme, textTheme, isDark),
              ),

            // ── Hero summary card (net + income/expense breakdown) ────────
            // Only displayed for Ledger & Budgets tabs; Split Bills has its own dedicated Split Summary Hero Card
            if (effectiveTab != 'Split Bills')
              SliverToBoxAdapter(
                child: AnimationConfiguration.staggeredList(
                  position: 2,
                  duration: const Duration(milliseconds: 220),
                  child: SlideAnimation(
                    verticalOffset: 24.0,
                    child: FadeInAnimation(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: _buildHeroSummaryCard(
                            colorScheme, textTheme, currency),
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
        if (showBudgets && (_categoryExpenses.isNotEmpty || _monthlyData.isNotEmpty)) ...[
          SliverToBoxAdapter(
            child: AnimationConfiguration.staggeredList(
              position: 3,
              duration: const Duration(milliseconds: 220),
              child: SlideAnimation(
                verticalOffset: 24.0,
                child: FadeInAnimation(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Consumer<SettingsProvider>(
                      builder: (context, settings, _) {
                        final forecast =
                            SpendingForecastService.calculateMonthlyForecast(
                          transactions: _transactions,
                          categoryBudgets: settings.categoryBudgets,
                        );
                        return MinimalChartDeck(
                          monthlyData: _monthlyData,
                          categoryExpenses: _categoryExpenses,
                          totalExpense: _totalDateExpense,
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
        if (_searchQuery.isNotEmpty && !_isSearching)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Clear search filter $_searchQuery',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                      onTap: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                          _applyFilters();
                        });
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
                                  'Search: "$_searchQuery"',
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
                      selected: _selectedAccount == 'all',
                      onSelected: (_) {
                        setState(() => _selectedAccount = 'all');
                        _applyFilters();
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      showCheckmark: false,
                      avatar: const Icon(Icons.credit_card_outlined, size: 16),
                      label: Text(settings.account1Name),
                      selected: _selectedAccount == AccountType.daily,
                      onSelected: (_) {
                        setState(() => _selectedAccount = AccountType.daily);
                        _applyFilters();
                      },
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      showCheckmark: false,
                      avatar: const Icon(Icons.account_balance_outlined, size: 16),
                      label: Text(settings.account2Name),
                      selected: _selectedAccount == AccountType.savings,
                      onSelected: (_) {
                        setState(() => _selectedAccount = AccountType.savings);
                        _applyFilters();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Category filter chips ────────────────────────────────────
        if (_activeCategories.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: AnimationConfiguration.staggeredList(
              position: 5,
              duration: const Duration(milliseconds: 220),
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
                            selected: _selectedCategory == null,
                            onSelected: (_) {
                              setState(() => _selectedCategory = null);
                              _applyFilters();
                            },
                          ),
                          const SizedBox(width: 8),
                          ..._activeCategories.map((cat) {
                            final catColor = TransactionCategory.colorFor(cat);
                            final catIcon = TransactionCategory.iconFor(cat);
                            final selected = _selectedCategory == cat;
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
                                  setState(() => _selectedCategory = selected ? null : cat);
                                  _applyFilters();
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
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else
              FinancialLedgerTab(
                groupedTransactions: _groupedTransactions,
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
                  await TransactionRepository.instance.createTransaction(duplicate);
                  await _refreshTransactions();
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
                  // 1. Instant optimistic local list update (0ms latency)
                  if (transaction.id != null) {
                    _allDateFiltered.removeWhere((t) => t.id == transaction.id);
                    _applyFilters();
                    if (mounted) {
                      setState(() {
                        _trashedCount += 1;
                      });
                    }
                  }

                  // 2. Persist in background
                  if (transaction.id != null) {
                    await TransactionRepository.instance.deleteTransaction(transaction.id!);
                    await _refreshTransactions(showLoading: false);
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
                              // 1. Instant optimistic restore (0ms latency)
                              final restored = transaction.copy(deletedAt: null);
                              _allDateFiltered.removeWhere((t) => t.id == transaction.id);
                              _allDateFiltered.add(restored);
                              _allDateFiltered.sort((a, b) => b.date.compareTo(a.date));
                              _applyFilters();
                              if (mounted) {
                                setState(() {
                                  _trashedCount = (_trashedCount - 1).clamp(0, 999999);
                                });
                              }

                              // 2. Persist in background
                              await TransactionRepository.instance.restoreTransaction(transaction.id!);
                              await _refreshTransactions(showLoading: false);
                            }
                          },
                        ),
                      ),
                    );
                  }
                },
                onUndoDelete: (transaction) async {
                  if (transaction.id != null) {
                    // Instant optimistic restore
                    final restored = transaction.copy(deletedAt: null);
                    _allDateFiltered.removeWhere((t) => t.id == transaction.id);
                    _allDateFiltered.add(restored);
                    _allDateFiltered.sort((a, b) => b.date.compareTo(a.date));
                    _applyFilters();
                    if (mounted) {
                      setState(() {
                        _trashedCount = (_trashedCount - 1).clamp(0, 999999);
                      });
                    }
                    await TransactionRepository.instance.restoreTransaction(transaction.id!);
                    await _refreshTransactions(showLoading: false);
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
              transactions: _transactions,
              monthlyData: _monthlyData,
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

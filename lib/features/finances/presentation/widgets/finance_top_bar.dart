import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../utils/app_route.dart';
import '../../../../widgets/bouncing_widget.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../providers/financial_manager_provider.dart';
import '../../services/financial_export_service.dart';
import '../screens/sms_rules_screen.dart';
import 'account_transfer_sheet.dart';
import 'financial_trash_sheet.dart';
import 'recurring_rules_sheet.dart';
import 'savings_goal_editor_sheet.dart';
import 'sms_import_sheet.dart';

class FinanceTopBar extends StatelessWidget {
  final bool isSearching;
  final TextEditingController searchController;
  final String currency;
  final VoidCallback onExitSearch;
  final VoidCallback onStartSearch;
  final VoidCallback onSelectDateRange;
  final VoidCallback onQuickImportRecentSms;
  final VoidCallback onOpenSavingsGoals;
  final VoidCallback onRefreshTransactions;

  const FinanceTopBar({
    super.key,
    required this.isSearching,
    required this.searchController,
    required this.currency,
    required this.onExitSearch,
    required this.onStartSearch,
    required this.onSelectDateRange,
    required this.onQuickImportRecentSms,
    required this.onOpenSavingsGoals,
    required this.onRefreshTransactions,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final finProvider = context.watch<FinancialManagerProvider>();

    if (finProvider.isSelectionMode) {
      return _buildSelectionModeHeader(context, colorScheme, textTheme, finProvider);
    }
    if (isSearching) {
      return _buildSearchModeHeader(context, colorScheme, textTheme, finProvider);
    }
    return _buildNormalHeader(context, colorScheme, textTheme, isDark, finProvider);
  }

  Widget _buildSearchModeHeader(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    FinancialManagerProvider finProvider,
  ) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Exit search',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          visualDensity: VisualDensity.compact,
          onPressed: onExitSearch,
        ),
        Expanded(
          child: TextField(
            controller: searchController,
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
              context.read<FinancialManagerProvider>().setSearchQuery(val.trim().toLowerCase());
            },
            onSubmitted: (_) {
              FocusScope.of(context).unfocus();
            },
          ),
        ),
        if (finProvider.searchQuery.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: 'Clear query',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            visualDensity: VisualDensity.compact,
            onPressed: () {
              searchController.clear();
              context.read<FinancialManagerProvider>().setSearchQuery('');
            },
          ),
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          visualDensity: VisualDensity.compact,
          onPressed: () {
            FocusScope.of(context).unfocus();
          },
        ),
      ],
    );
  }

  Widget _buildNormalHeader(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isDark,
    FinancialManagerProvider finProvider,
  ) {
    final settings = Provider.of<SettingsProvider>(context);
    final selectedRange = finProvider.selectedRange;

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
                    'Selected date range: ${selectedRange.duration.inDays == 0 ? DateFormat.MMMd().format(selectedRange.start) : '${DateFormat.MMMd().format(selectedRange.start)} to ${DateFormat.MMMd().format(selectedRange.end)}'}. Tap to change filter',
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                  onTap: onSelectDateRange,
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
                            selectedRange.duration.inDays == 0
                                ? DateFormat.MMMd().format(selectedRange.start)
                                : '${DateFormat.MMMd().format(selectedRange.start)} – ${DateFormat.MMMd().format(selectedRange.end)}',
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
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          visualDensity: VisualDensity.compact,
          onPressed: onStartSearch,
        ),
        if (settings.enableSmsImport)
          Semantics(
            button: true,
            label:
                'Sync SMS transactions. Tap for quick sync, hold for advanced import options',
            child: Tooltip(
              message: 'Quick Sync (Tap) | Advanced Import (Hold)',
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: BouncingWidget(
                  onTap: onQuickImportRecentSms,
                  onLongPress: () {
                    AppHaptics.mediumImpact();
                    SmsImportSheet.show(context);
                  },
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: finProvider.isSmsSyncing
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
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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
              onOpenSavingsGoals();
              SavingsGoalEditorSheet.show(context).then((_) {
                if (context.mounted) onRefreshTransactions();
              });
            } else if (value == 'sms_rules') {
              AppRoute.push(context, const SmsRulesScreen());
            } else if (value == 'recurring') {
              RecurringRulesSheet.show(
                context: context,
                currency: currency,
                onRulesUpdated: onRefreshTransactions,
              );
            } else if (value == 'export') {
              FinancialExportService.showExportSheet(
                context,
                context.read<FinancialManagerProvider>().transactions,
                currency: currency,
              );
            } else if (value == 'transfer') {
              AccountTransferSheet.show(context).then((_) {
                if (context.mounted) onRefreshTransactions();
              });
            } else if (value == 'trash') {
              FinancialTrashSheet.show(context).then((_) {
                if (context.mounted) onRefreshTransactions();
              });
            }
          },
          itemBuilder: (ctx) {
            final menuSettings = ctx.read<SettingsProvider>();
            final fin = ctx.read<FinancialManagerProvider>();
            return [
              if (menuSettings.enableSmsImport)
                PopupMenuItem(
                  value: 'sms_rules',
                  height: 48,
                  child: Row(
                    children: [
                      Icon(Icons.flash_on_rounded, size: 20, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        'SMS & Bank Automation',
                        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
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
                      Text(
                        'Savings Goals & Pockets',
                        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
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
                      Text(
                        'Recurring Subscriptions',
                        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
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
                      Text(
                        'Transfer Between Accounts',
                        style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
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
                    Text(
                      'Export Ledger',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
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
                      child: Text(
                        'Trash Bin',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                    if (fin.trashedCount > 0)
                      Badge(
                        label: Text('${fin.trashedCount}'),
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
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          visualDensity: VisualDensity.compact,
          onPressed: () {
            AppRoute.push(context, const SettingsScreen())
                .then((_) => onRefreshTransactions());
          },
        ),
      ],
    );
  }

  Widget _buildSelectionModeHeader(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    FinancialManagerProvider finProvider,
  ) {
    final validTxIds = finProvider.transactions
        .where((t) => t.id != null)
        .map((t) => t.id!)
        .toList();
    final allSelected = validTxIds.isNotEmpty &&
        validTxIds.every((id) => finProvider.selectedTransactionIds.contains(id));

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Clear selection',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          visualDensity: VisualDensity.compact,
          onPressed: () {
            AppHaptics.selectionClick();
            if (allSelected) {
              finProvider.clearSelection();
            } else {
              finProvider.selectAll(finProvider.transactions);
            }
          },
        ),
      ],
    );
  }
}

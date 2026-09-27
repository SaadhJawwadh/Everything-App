import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../data/transaction_model.dart';
import '../../../../data/transaction_category.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_card.dart';
import '../../providers/financial_manager_provider.dart';
import '../screens/transaction_editor_screen.dart';

/// Modular Ledger Tab widget for FinancialManagerScreen displaying transactions list and date grouping.
class FinancialLedgerTab extends StatelessWidget {
  final List<dynamic> groupedTransactions;
  final String currency;
  final VoidCallback onRefresh;
  final Function(TransactionModel) onDuplicate;
  final Function(TransactionModel) onDelete;
  final Function(TransactionModel) onUndoDelete;
  final VoidCallback onAddFirstTransaction;

  const FinancialLedgerTab({
    super.key,
    required this.groupedTransactions,
    required this.currency,
    required this.onRefresh,
    required this.onDuplicate,
    required this.onDelete,
    required this.onUndoDelete,
    required this.onAddFirstTransaction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    if (groupedTransactions.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 64,
                color: colorScheme.outlineVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No transactions found',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add a transaction or adjust your date filter.',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAddFirstTransaction,
                icon: const Icon(Icons.add),
                label: const Text('Add Transaction'),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, AppLayout.fabBottomPadding),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = groupedTransactions[index];

            // Date group header
            if (item is String) {
              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 220),
                child: SlideAnimation(
                  verticalOffset: 16.0,
                  child: FadeInAnimation(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                      child: Text(
                        item,
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            final transaction = item as TransactionModel;
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 220),
              child: SlideAnimation(
                verticalOffset: 16.0,
                child: FadeInAnimation(
                  child: OpenContainer<bool>(
                    transitionType: ContainerTransitionType.fadeThrough,
                    transitionDuration: const Duration(milliseconds: 300),
                    openBuilder: (context, _) => TransactionEditorScreen(transaction: transaction),
                    closedElevation: 0,
                    openElevation: 0,
                    closedColor: colorScheme.surfaceContainer,
                    openColor: colorScheme.surface,
                    closedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppLayout.radiusM),
                    ),
                    onClosed: (updated) {
                      if (updated == true) onRefresh();
                    },
                    closedBuilder: (context, openContainer) {
                      final finProvider = Provider.of<FinancialManagerProvider>(context);
                      final isSelected = transaction.id != null &&
                          finProvider.selectedTransactionIds.contains(transaction.id);
                      final catColor = TransactionCategory.colorFor(transaction.category);
                      final isDark = theme.brightness == Brightness.dark;

                      return AppCard(
                        margin: const EdgeInsets.only(bottom: AppLayout.spaceS),
                        padding: const EdgeInsets.symmetric(horizontal: AppLayout.spaceM, vertical: AppLayout.spaceXS),
                        backgroundColor: isSelected
                            ? colorScheme.primaryContainer.withValues(alpha: isDark ? 0.35 : 0.45)
                            : null,
                        border: isSelected
                            ? BorderSide(color: colorScheme.primary, width: 1.5)
                            : null,
                        child: Semantics(
                          label:
                              '${transaction.description}, ${transaction.category}, ${transaction.isExpense ? 'Expense' : 'Income'} of $currency ${NumberFormat('#,##0.00').format(transaction.amount)}, at ${DateFormat('hh:mm a').format(transaction.date)}.',
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                              child: isSelected
                                  ? Container(
                                      key: const ValueKey('selected'),
                                      padding: const EdgeInsets.all(AppLayout.spaceS),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.check_rounded,
                                        color: colorScheme.onPrimary,
                                        size: 20,
                                      ),
                                    )
                                  : finProvider.isSelectionMode
                                      ? Container(
                                          key: const ValueKey('unselected'),
                                          padding: const EdgeInsets.all(AppLayout.spaceS),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: colorScheme.outline.withValues(alpha: 0.6),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: const SizedBox(width: 20, height: 20),
                                        )
                                      : Container(
                                          key: const ValueKey('category_icon'),
                                          padding: const EdgeInsets.all(AppLayout.spaceS),
                                          decoration: BoxDecoration(
                                            color: catColor.withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: catColor.withValues(alpha: 0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Icon(
                                            TransactionCategory.iconFor(transaction.category),
                                            color: catColor,
                                            size: 20,
                                          ),
                                        ),
                            ),
                            title: Text(
                              transaction.description,
                              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${transaction.account == AccountType.savings ? 'Savings • ' : ''}${transaction.category} • ${DateFormat('hh:mm a').format(transaction.date)}',
                              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                            ),
                            trailing: Text(
                              '${transaction.isExpense ? '-' : '+'}$currency ${NumberFormat('#,##0.00').format(transaction.amount)}',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontFeatures: const [FontFeature.tabularFigures()],
                                color: transaction.isExpense
                                    ? colorScheme.error
                                    : colorScheme.primary,
                              ),
                            ),
                            onTap: () {
                              if (finProvider.isSelectionMode && transaction.id != null) {
                                AppHaptics.selectionClick();
                                finProvider.toggleSelection(transaction.id!);
                              } else {
                                openContainer();
                              }
                            },
                            onLongPress: () {
                              if (transaction.id != null) {
                                AppHaptics.mediumImpact();
                                if (finProvider.isSelectionMode) {
                                  finProvider.toggleSelection(transaction.id!);
                                } else {
                                  finProvider.startSelection(transaction.id!);
                                }
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
          childCount: groupedTransactions.length,
        ),
      ),
    );
  }
}

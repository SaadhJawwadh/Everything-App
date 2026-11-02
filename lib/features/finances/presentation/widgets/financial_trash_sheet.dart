import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_bottom_sheet.dart';
import '../../../../core/ui/app_card.dart';
import '../../../../core/ui/app_dialog.dart';
import '../../../../core/ui/expressive_shape_morph_indicator.dart';
import '../../../../data/transaction_model.dart';
import '../../data/transaction_repository.dart';
import '../screens/financial_manager_screen.dart';

class FinancialTrashSheet extends StatefulWidget {
  const FinancialTrashSheet({super.key});

  static Future<void> show(BuildContext context) {
    return AppBottomSheet.show<void>(
      context: context,
      title: 'Financial Trash Bin',
      child: const FinancialTrashSheet(),
    );
  }

  @override
  State<FinancialTrashSheet> createState() => _FinancialTrashSheetState();
}

class _FinancialTrashSheetState extends State<FinancialTrashSheet> {
  List<TransactionModel> _trashed = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrashed();
  }

  Future<void> _loadTrashed({bool showLoading = false}) async {
    if (showLoading || _trashed.isEmpty) {
      setState(() => _isLoading = true);
    }
    final list = await TransactionRepository.instance.readTrashedTransactions();
    if (!mounted) return;
    setState(() {
      _trashed = list;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppLayout.spaceXL),
        child: Center(child: ExpressiveShapeMorphIndicator(size: 44)),
      );
    }

    if (_trashed.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppLayout.spaceXXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.delete_outline_rounded,
              size: 56,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppLayout.spaceM),
            Text(
              'Trash is Empty',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppLayout.spaceXS),
            Text(
              'Deleted transactions will appear here for 30 days before permanent deletion.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '${_trashed.length} Deleted Transaction${_trashed.length == 1 ? '' : 's'}',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () async {
                final confirm = await AppDialog.showConfirm(
                  context: context,
                  title: 'Empty Trash?',
                  message:
                      'Permanently delete all trashed transactions? Their SMS IDs will be permanently remembered so they are never re-imported.',
                  confirmLabel: 'Empty Trash',
                  isDestructive: true,
                );
                if (confirm == true && mounted) {
                  await TransactionRepository.instance.emptyTrash();
                  FinancialManagerScreen.refreshNotifier.value++;
                  await _loadTrashed();
                }
              },
              icon: const Icon(Icons.delete_forever_outlined, size: 18),
              label: const Text('Empty Trash'),
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.error,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppLayout.spaceS),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _trashed.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppLayout.spaceS),
            itemBuilder: (context, index) {
              final txn = _trashed[index];
              final isExpense = txn.isExpense;
              final amountFormatted = txn.amount.toStringAsFixed(0);

              return AppCard(
                padding: const EdgeInsets.all(AppLayout.spaceM),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isExpense
                          ? colorScheme.errorContainer.withValues(alpha: 0.5)
                          : colorScheme.primaryContainer.withValues(alpha: 0.5),
                      radius: 20,
                      child: Icon(
                        isExpense
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 18,
                        color: isExpense ? colorScheme.error : colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: AppLayout.spaceM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            txn.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${txn.category} • ${DateFormat.MMMd().format(txn.date)}',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppLayout.spaceS),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isExpense ? "-" : "+"} $amountFormatted',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: isExpense ? colorScheme.error : colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Semantics(
                              button: true,
                              label: 'Restore transaction',
                              child: InkWell(
                                borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                                onTap: () async {
                                  if (txn.id != null) {
                                    // 1. Instant optimistic UI removal (0ms)
                                    setState(() {
                                      _trashed.removeWhere((t) => t.id == txn.id);
                                    });
                                    // 2. Persist in background
                                    await TransactionRepository.instance.restoreTransaction(txn.id!);
                                    FinancialManagerScreen.refreshNotifier.value++;
                                    await _loadTrashed(showLoading: false);
                                  }
                                },
                                child: Container(
                                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.restore_rounded,
                                          size: 16, color: colorScheme.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Restore',
                                        style: textTheme.labelSmall?.copyWith(
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Semantics(
                              button: true,
                              label: 'Permanently delete transaction',
                              child: InkWell(
                                borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                                onTap: () async {
                                  if (txn.id != null) {
                                    // 1. Instant optimistic UI removal (0ms)
                                    setState(() {
                                      _trashed.removeWhere((t) => t.id == txn.id);
                                    });
                                    // 2. Persist in background
                                    await TransactionRepository.instance.permanentlyDeleteTransaction(txn.id!);
                                    FinancialManagerScreen.refreshNotifier.value++;
                                    await _loadTrashed(showLoading: false);
                                  }
                                },
                                child: Container(
                                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 4),
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: colorScheme.error,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

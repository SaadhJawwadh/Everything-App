import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/app_haptics.dart';
import '../../../../core/ui/expressive_floating_toolbar.dart';
import '../../../../core/ui/app_bottom_sheet.dart';
import '../../../../data/transaction_category.dart';
import '../../../../data/transaction_model.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../providers/financial_manager_provider.dart';

/// Contextual floating action toolbar rendered during Financial Ledger multi-selection mode.
class LedgerFloatingToolbar extends StatelessWidget {
  final VoidCallback? onActionCompleted;

  const LedgerFloatingToolbar({super.key, this.onActionCompleted});

  void _showCategoryPicker(BuildContext context, FinancialManagerProvider provider) {
    final categories = TransactionCategory.allNames;

    AppBottomSheet.show(
      context: context,
      title: 'Assign Category (${provider.selectedCount} selected)',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((cat) {
            final color = TransactionCategory.colorFor(cat);
            final icon = TransactionCategory.iconFor(cat);
            return FilterChip(
              showCheckmark: false,
              avatar: Icon(icon, size: 16, color: color),
              label: Text(cat),
              onSelected: (_) async {
                AppHaptics.mediumImpact();
                if (context.mounted) Navigator.pop(context);
                final count = provider.selectedCount;
                await provider.bulkUpdateCategory(cat);
                onActionCompleted?.call();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Updated $count transaction${count == 1 ? "" : "s"} to "$cat"'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showAccountPicker(BuildContext context, FinancialManagerProvider provider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    AppBottomSheet.show(
      context: context,
      title: 'Move Account (${provider.selectedCount} selected)',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.account_balance_wallet_outlined, color: colorScheme.primary, size: 20),
            ),
            title: const Text('Daily Operating Account', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Primary everyday spending & debit account', style: TextStyle(fontSize: 12)),
            onTap: () async {
              AppHaptics.mediumImpact();
              if (context.mounted) Navigator.pop(context);
              final count = provider.selectedCount;
              await provider.bulkUpdateAccount(AccountType.daily);
              onActionCompleted?.call();
              if (context.mounted) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Moved $count transaction${count == 1 ? "" : "s"} to Daily Operating'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 4),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.savings_outlined, color: colorScheme.tertiary, size: 20),
            ),
            title: const Text('Savings Vault', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Protected reserve & goal allocation vault', style: TextStyle(fontSize: 12)),
            onTap: () async {
              AppHaptics.mediumImpact();
              if (context.mounted) Navigator.pop(context);
              final count = provider.selectedCount;
              await provider.bulkUpdateAccount(AccountType.savings);
              onActionCompleted?.call();
              if (context.mounted) {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Moved $count transaction${count == 1 ? "" : "s"} to Savings Vault'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = context.watch<FinancialManagerProvider>();
    final settings = context.watch<SettingsProvider>();

    if (!provider.isSelectionMode) return const SizedBox.shrink();

    final isAiSupported = settings.isAiActive;

    return SafeArea(
      top: false,
      child: ExpressiveFloatingToolbar(
        key: const ValueKey('ledger_selection_toolbar'),
        isVibrant: true,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Assign Category
          ExpressiveFloatingToolbar.actionButton(
            icon: Icons.category_outlined,
            tooltip: 'Assign category',
            onPressed: provider.isBulkAiRefining
                ? null
                : () {
                    _showCategoryPicker(context, provider);
                  },
          ),

          // 2. Move Account
          ExpressiveFloatingToolbar.actionButton(
            icon: Icons.account_balance_outlined,
            tooltip: 'Move account',
            onPressed: provider.isBulkAiRefining
                ? null
                : () {
                    _showAccountPicker(context, provider);
                  },
          ),

          // 3. Targeted AI Refine
          if (isAiSupported) ...[
            ExpressiveFloatingToolbar.actionButton(
              icon: Icons.auto_awesome_rounded,
              tooltip: provider.isBulkAiRefining ? 'Refining transactions...' : 'Refine selected with AI',
              color: colorScheme.primary,
              customIcon: provider.isBulkAiRefining
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: colorScheme.primary,
                      ),
                    )
                  : null,
              onPressed: provider.isBulkAiRefining
                  ? null
                  : () async {
                      AppHaptics.mediumImpact();
                      if (!context.mounted) return;
                      final messenger = ScaffoldMessenger.of(context);
                      final selectedCount = provider.selectedCount;
                      messenger.clearSnackBars();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Refining $selectedCount transaction${selectedCount == 1 ? "" : "s"} with on-device AI...'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );

                      final count = await provider.bulkAiRefineSelected();
                      onActionCompleted?.call();
                      if (!context.mounted) return;
                      messenger.clearSnackBars();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            count == 0
                                ? 'AI could not refine: description already concise or AI unavailable.'
                                : 'Successfully refined $count transaction${count == 1 ? "" : "s"} with on-device AI!',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
            ),
          ],

          ExpressiveFloatingToolbar.spacer(),

          // 4. Bulk Delete with Undo
          ExpressiveFloatingToolbar.actionButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Delete selected',
            color: colorScheme.error,
            onPressed: provider.isBulkAiRefining
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    AppHaptics.mediumImpact();
                    final deletedIds = await provider.bulkDeleteSelected();
                    if (deletedIds.isEmpty) return;
                    onActionCompleted?.call();

                    messenger.clearSnackBars();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Deleted ${deletedIds.length} transaction${deletedIds.length == 1 ? "" : "s"}'),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 5),
                        action: SnackBarAction(
                          label: 'UNDO',
                          onPressed: () async {
                            await provider.bulkRestore(deletedIds);
                            onActionCompleted?.call();
                          },
                        ),
                      ),
                    );
                  },
          ),
        ],
      ),
    );
  }
}

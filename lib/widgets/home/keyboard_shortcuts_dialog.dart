import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_layout.dart';
import '../../core/ui/app_dialog.dart';
import '../../features/settings/providers/settings_provider.dart';

/// Material 3 Expressive Keyboard Shortcuts Cheat-Sheet Dialog for Google Book
/// laptops, Chromebooks, tablets, and hardware keyboards (`Ctrl/Cmd + /` or `?`).
class KeyboardShortcutsDialog extends StatelessWidget {
  const KeyboardShortcutsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const KeyboardShortcutsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = context.watch<SettingsProvider>();

    final items = <({String label, String keys, IconData icon})>[
      (
        label: 'New Note',
        keys: 'Ctrl + N',
        icon: Icons.note_add_outlined,
      ),
      if (settings.showFinancialManager)
        (
          label: 'New Transaction',
          keys: 'Ctrl + T',
          icon: Icons.add_card_outlined,
        ),
      (
        label: 'Universal Search & A2UI Actions',
        keys: 'Ctrl + F',
        icon: Icons.search_rounded,
      ),
      (
        label: 'Switch to Notes',
        keys: 'Ctrl + 1',
        icon: Icons.note_alt_outlined,
      ),
      if (settings.showFinancialManager)
        (
          label: 'Switch to Finances',
          keys: 'Ctrl + 2',
          icon: Icons.account_balance_wallet_outlined,
        ),
      if (settings.isPeriodTrackerEnabled)
        (
          label: 'Switch to Period Tracker',
          keys: settings.showFinancialManager ? 'Ctrl + 3' : 'Ctrl + 2',
          icon: Icons.water_drop_outlined,
        ),
      (
        label: 'Keyboard Shortcuts Cheat-Sheet',
        keys: 'Ctrl + /',
        icon: Icons.keyboard_alt_outlined,
      ),
      (
        label: 'Clear Search / Selection',
        keys: 'Esc',
        icon: Icons.close_rounded,
      ),
    ];

    return AppDialog(
      title: 'Keyboard Shortcuts',
      showConfirmButton: false,
      cancelLabel: 'Close',
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Navigate faster on Google Books, tablets, and external keyboards.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppLayout.spaceM),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      Icon(
                        item.icon,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: AppLayout.spaceS),
                      Expanded(
                        child: Text(
                          item.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppLayout.spaceS),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius:
                              BorderRadius.circular(AppLayout.radiusS),
                          border: Border.all(
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        child: Text(
                          item.keys,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

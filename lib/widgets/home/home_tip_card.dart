import 'package:flutter/material.dart';
import '../../core/services/app_haptics.dart';
import '../../core/theme/app_layout.dart';
import '../../core/ui/app_card.dart';
import '../../features/notes/presentation/widgets/note_migration_sheet.dart';

class ProTipItem {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ProTipItem({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });
}

class HomeTipCard extends StatelessWidget {
  final ProTipItem tip;
  final VoidCallback onDismiss;
  final VoidCallback onDisable;

  const HomeTipCard({
    super.key,
    required this.tip,
    required this.onDismiss,
    required this.onDisable,
  });

  static List<ProTipItem> getCatalog(BuildContext context) {
    return [
      ProTipItem(
        icon: Icons.import_contacts_rounded,
        title: 'Migrate from Google Keep',
        description:
            'Import your Google Keep notes & checklists with 1-tap Google Takeout pre-selection, smart clean headings, and undo safety.',
        actionLabel: 'Import Notes',
        onAction: () => NoteMigrationSheet.show(context),
      ),
      const ProTipItem(
        icon: Icons.sync_rounded,
        title: 'Zero-Cloud P2P Device Sync',
        description:
            'Pair devices over local Wi-Fi to sync notes, finances, and health logs without uploading any data to the cloud.',
      ),
      const ProTipItem(
        icon: Icons.sms_outlined,
        title: 'Instant SMS Bank Ledger',
        description:
            'Enable auto-sync to turn incoming bank SMS alerts into categorized income and expense transactions in real-time.',
      ),
      const ProTipItem(
        icon: Icons.keyboard_double_arrow_right_rounded,
        title: 'Split-Axis Cursor Steppers',
        description:
            'Use the left and right directional steppers on the note editor toolbar for single-character nudges and word boundary snaps.',
      ),
      const ProTipItem(
        icon: Icons.repeat_rounded,
        title: 'Recurring Subscriptions',
        description:
            'Open any transaction and set a Repeat frequency to automatically track monthly rent, Netflix, and recurring bills.',
      ),
      const ProTipItem(
        icon: Icons.insights_rounded,
        title: 'Daily Safe-to-Spend Pacing',
        description:
            'Assign category limits in Finances to unlock daily safe-to-spend pacing and real-time month-end forecasts.',
      ),
      const ProTipItem(
        icon: Icons.fingerprint_rounded,
        title: 'Biometric & PIN Privacy',
        description:
            'Enable App Lock in Settings to protect your private notes, financial ledger, and cycle logs behind biometrics.',
      ),
      const ProTipItem(
        icon: Icons.pie_chart_outline_rounded,
        title: 'Split Bills & Receipt Scanner',
        description:
            'Split group expenses with friends, scan receipts with your camera for instant totals, and send 1-tap WhatsApp breakdown reminders.',
      ),
      const ProTipItem(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Savings Vault & Dual Accounts',
        description:
            'Keep daily operating cash flow separate from long-term savings in Financial Manager with dedicated balance badges and instant filtering.',
      ),
      const ProTipItem(
        icon: Icons.tune_rounded,
        title: 'Train Bank SMS Rules',
        description:
            'Paste any bank SMS into the SMS Rules test sandbox to teach the app custom descriptions, transfer approvals, and keywords.',
      ),
      const ProTipItem(
        icon: Icons.water_drop_outlined,
        title: 'Discreet Cycle Alerts',
        description:
            'The built-in Period Tracker calculates cycle regularity and sends customizable discreet alerts like "Check the app".',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppLayout.spaceS),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    tip.icon,
                    size: 18,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'PRO-TIP',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        tip.title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Dismiss tip',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDismiss,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tip.description,
              style: textTheme.bodySmall?.copyWith(
                 color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    AppHaptics.selectionClick();
                    onDisable();
                  },
                  child: Text(
                    "Don't show tips",
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (tip.actionLabel != null && tip.onAction != null) ...[
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: tip.onAction!,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                        label: Text(
                          tip.actionLabel!,
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: onDismiss,
                      child: const Text('Got it', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

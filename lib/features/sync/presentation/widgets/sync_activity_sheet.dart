import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_bottom_sheet.dart';
import '../../../../core/ui/app_card.dart';
import '../../../../core/ui/app_chip.dart';
import '../../providers/p2p_sync_provider.dart';

/// Modal bottom sheet displaying recent local Wi-Fi P2P sync logs, audit telemetry,
/// and live device network diagnostics.
class SyncActivitySheet extends StatelessWidget {
  const SyncActivitySheet({super.key});

  /// Displays the sync audit activity sheet.
  static Future<void> show(BuildContext context) {
    return AppBottomSheet.show<void>(
      context: context,
      title: 'P2P Sync Audit & Activity',
      child: const SyncActivitySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final sync = context.watch<P2pSyncProvider>();
    final activities = sync.recentActivity;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Device & Network Status Card ──
        AppCard.tonal(
          color: cs.primaryContainer.withValues(alpha: isDark ? 0.25 : 0.45),
          borderColor: cs.primary.withValues(alpha: isDark ? 0.35 : 0.3),
          borderRadius: AppLayout.radiusL,
          child: Padding(
            padding: const EdgeInsets.all(AppLayout.spaceM),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppLayout.spaceS),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    sync.diagnostics?.isReady == true ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    color: sync.diagnostics?.isReady == true ? cs.primary : cs.error,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppLayout.spaceM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sync.localDeviceName,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sync.localIpAddress != null
                            ? 'Local IP: ${sync.localIpAddress} • Port 8765'
                            : 'Searching for local Wi-Fi subnet...',
                        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppLayout.spaceS),
                AppChip(
                  label: '${sync.pairedDevices.length} Paired',
                  icon: Icons.devices_rounded,
                  backgroundColor: cs.surfaceContainerHighest,
                  textColor: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppLayout.spaceL),

        // ── Activity List Section Header ──
        Row(
          children: [
            Text(
              'Recent Sync Events',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            if (sync.lastSyncedAt != null)
              Text(
                'Last: ${DateFormat.jm().format(sync.lastSyncedAt!)}',
                style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
              ),
          ],
        ),
        const SizedBox(height: AppLayout.spaceS),

        // ── Event Logs ──
        if (activities.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppLayout.spaceXL),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded, size: 40, color: cs.outlineVariant),
                  const SizedBox(height: AppLayout.spaceS),
                  Text(
                    'No sync activity recorded yet',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sync events appear here whenever two devices exchange data.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.outline),
                  ),
                ],
              ),
            ),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.42,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: activities.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppLayout.spaceS),
              itemBuilder: (context, index) {
                final event = activities[index];
                final isOk = event.result.success;
                final res = event.result;

                return AppCard.tonal(
                  color: cs.surfaceContainerHigh.withValues(alpha: isDark ? 0.35 : 0.65),
                  borderColor: cs.outlineVariant.withValues(alpha: 0.35),
                  borderRadius: AppLayout.radiusL,
                  child: Padding(
                    padding: const EdgeInsets.all(AppLayout.spaceM),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isOk ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                          color: isOk ? Colors.green : cs.error,
                          size: 20,
                        ),
                        const SizedBox(width: AppLayout.spaceM),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    isOk ? 'Delta Merge Complete' : 'Sync Encountered Error',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isOk ? cs.onSurface : cs.error,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    DateFormat.jms().format(event.timestamp),
                                    style: theme.textTheme.labelSmall?.copyWith(color: cs.outline),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              if (isOk) ...[
                                Text(
                                  event.peerName != null
                                      ? 'Peer: ${event.peerName} • ${res.transportUsed}'
                                      : res.transportUsed,
                                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: AppLayout.spaceXS,
                                  runSpacing: 4,
                                  children: [
                                    if (res.receivedCount > 0)
                                      _telemetryBadge(
                                        context,
                                        '+${res.receivedCount} Received',
                                        Icons.arrow_downward_rounded,
                                        Colors.teal,
                                      ),
                                    if (res.sentCount > 0)
                                      _telemetryBadge(
                                        context,
                                        '+${res.sentCount} Sent',
                                        Icons.arrow_upward_rounded,
                                        cs.primary,
                                      ),
                                    if (res.latencyMs != null)
                                      _telemetryBadge(
                                        context,
                                        '${res.latencyMs}ms latency',
                                        Icons.speed_rounded,
                                        cs.secondary,
                                      ),
                                  ],
                                ),
                              ] else
                                Text(
                                  res.errorMessage ?? 'Unknown network failure',
                                  style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: AppLayout.spaceL),

        // ── Action CTA ──
        FilledButton.icon(
          onPressed: () {
            AppHaptics.lightImpact();
            sync.syncAllPairedDevices();
            Navigator.pop(context);
          },
          icon: const Icon(Icons.sync_rounded),
          label: const Text('Sync All Paired Devices Now'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
            ),
          ),
        ),
      ],
    );
  }

  Widget _telemetryBadge(BuildContext context, String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

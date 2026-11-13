import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:note_taking_app/core/services/app_haptics.dart';
import 'package:note_taking_app/core/theme/app_layout.dart';
import 'package:note_taking_app/core/ui/app_card.dart';
import 'package:note_taking_app/core/ui/app_chip.dart';
import 'package:note_taking_app/core/ui/app_dialog.dart';
import 'package:note_taking_app/core/ui/expressive_sliver_app_bar.dart';
import 'package:note_taking_app/widgets/bouncing_widget.dart';
import 'package:note_taking_app/features/notes/providers/note_provider.dart';
import 'package:note_taking_app/features/finances/providers/financial_manager_provider.dart';
import 'package:note_taking_app/features/finances/providers/savings_goal_provider.dart';
import 'package:note_taking_app/features/finances/providers/split_bill_provider.dart';
import 'package:note_taking_app/features/health/providers/period_tracker_provider.dart';
import 'package:note_taking_app/screens/app_lock_screen.dart';
import 'package:note_taking_app/services/backup_service.dart';
import 'package:note_taking_app/services/p2p_sync_service.dart';
import 'package:note_taking_app/features/sync/providers/p2p_sync_provider.dart';
import '../widgets/p2p_sync_modals.dart';
import '../widgets/sync_activity_sheet.dart';

class P2pSyncScreen extends StatefulWidget {
  const P2pSyncScreen({super.key});

  @override
  State<P2pSyncScreen> createState() => _P2pSyncScreenState();
}

class _P2pSyncScreenState extends State<P2pSyncScreen> {
  final TextEditingController _pairCodeController = TextEditingController();
  final TextEditingController _deviceNameController = TextEditingController();
  final TextEditingController _targetIpController = TextEditingController();

  void _refreshAllDomainProviders(
    NoteProvider noteProvider,
    FinancialManagerProvider finProvider,
    SplitBillProvider splitProvider,
    SavingsGoalProvider savingsProvider,
    PeriodTrackerProvider healthProvider,
  ) {
    noteProvider.refreshNotes();
    finProvider.refresh();
    splitProvider.loadSplitBills(showLoading: false);
    savingsProvider.loadGoals();
    healthProvider.loadData();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<P2pSyncProvider>().refreshDiagnostics(fullSubnetScan: true);
      }
    });
  }

  @override
  void dispose() {
    _pairCodeController.dispose();
    _deviceNameController.dispose();
    _targetIpController.dispose();
    super.dispose();
  }

  void _showPairDeviceDialog(BuildContext context, P2pSyncProvider syncProvider, {DiscoveredPeer? initialPeer}) {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final finProvider = Provider.of<FinancialManagerProvider>(context, listen: false);
    final splitProvider = Provider.of<SplitBillProvider>(context, listen: false);
    final savingsProvider = Provider.of<SavingsGoalProvider>(context, listen: false);
    final healthProvider = Provider.of<PeriodTrackerProvider>(context, listen: false);

    P2pSyncModals.showPairDeviceDialog(
      context: context,
      syncProvider: syncProvider,
      pairCodeController: _pairCodeController,
      deviceNameController: _deviceNameController,
      targetIpController: _targetIpController,
      initialPeer: initialPeer,
      onRefreshProviders: () => _refreshAllDomainProviders(
        noteProvider,
        finProvider,
        splitProvider,
        savingsProvider,
        healthProvider,
      ),
    );
  }

  Future<void> _showQrCodeModal(BuildContext context, P2pSyncProvider provider) =>
      P2pSyncModals.showQrCodeModal(context, provider);

  void _showRenameDeviceDialog({
    required BuildContext context,
    required String currentName,
    required Future<void> Function(String name) onSave,
  }) =>
      P2pSyncModals.showRenameDeviceDialog(
        context: context,
        currentName: currentName,
        onSave: onSave,
      );

  void _showCustomRelayDialog(BuildContext context, P2pSyncProvider syncProvider) =>
      P2pSyncModals.showCustomRelayDialog(context, syncProvider);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Consumer<P2pSyncProvider>(
      builder: (context, syncProvider, child) {
        final isSyncing = syncProvider.status == SyncStatus.syncing;
        final isError = syncProvider.status == SyncStatus.error;

        final heroBg = isError
            ? colorScheme.errorContainer.withValues(alpha: isDark ? 0.22 : 0.55)
            : colorScheme.primaryContainer.withValues(alpha: isDark ? 0.22 : 0.55);
        final heroBorder = isError
            ? colorScheme.error.withValues(alpha: isDark ? 0.35 : 0.45)
            : colorScheme.primary.withValues(alpha: isDark ? 0.35 : 0.45);
        final heroIconColor = isError ? colorScheme.error : colorScheme.primary;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              ExpressiveSliverAppBar(
                titleText: 'Master P2P Device Sync',
                showBackButton: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.hub_rounded),
                    tooltip: 'Cross-Network Relay Settings',
                    onPressed: () {
                      AppHaptics.selectionClick();
                      _showCustomRelayDialog(context, syncProvider);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.receipt_long_rounded),
                    tooltip: 'Sync Audit & Activity',
                    onPressed: () {
                      AppHaptics.selectionClick();
                      SyncActivitySheet.show(context);
                    },
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.all(AppLayout.spaceM),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Top Hero Status Card
                    AppCard.frosted(
                      backgroundColor: heroBg,
                      border: BorderSide(
                        color: heroBorder,
                        width: 1.2,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppLayout.spaceS + 2),
                                decoration: BoxDecoration(
                                  color: isSyncing
                                      ? colorScheme.primaryContainer
                                      : (isError ? colorScheme.errorContainer : colorScheme.surfaceContainerHighest),
                                  shape: BoxShape.circle,
                                ),
                                child: isSyncing
                                    ? SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                                        ),
                                      )
                                    : Icon(
                                        isError ? Icons.sync_problem_rounded : Icons.sync_rounded,
                                        color: heroIconColor,
                                        size: 26,
                                      ),
                              ),
                              const SizedBox(width: AppLayout.spaceM),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Bi-Directional P2P Sync',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        AppChip(
                                          label: isSyncing
                                              ? 'Syncing...'
                                              : (syncProvider.status == SyncStatus.error
                                                  ? 'Error'
                                                  : (syncProvider.pairedDevices.isEmpty ? 'Unlinked' : 'Ready')),
                                          isSelected: true,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      syncProvider.lastMessage ??
                                          (syncProvider.pairedDevices.isEmpty
                                              ? 'Link a nearby phone or tablet to merge notes, ledgers & settings offline'
                                              : 'Merge notes, ledgers & settings non-destructively'),
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: isError ? colorScheme.error : colorScheme.onSurfaceVariant,
                                        height: 1.3,
                                      ),
                                    ),
                                    if (syncProvider.lastSyncedAt != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Last synced: ${DateFormat.jm().format(syncProvider.lastSyncedAt!)}',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppLayout.spaceL),
                          if (syncProvider.pairedDevices.isEmpty)
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: SizedBox(
                                    height: 48,
                                    child: BouncingWidget(
                                      child: FilledButton.icon(
                                        onPressed: isSyncing
                                            ? null
                                            : () => _showPairDeviceDialog(context, syncProvider),
                                        icon: Icon(isError ? Icons.refresh_rounded : Icons.phonelink_ring_rounded),
                                        label: Text(
                                          isError ? 'Pair Again' : 'Pair Device',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppLayout.spaceS),
                                Expanded(
                                  flex: 2,
                                  child: SizedBox(
                                    height: 48,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _showQrCodeModal(context, syncProvider),
                                      icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                                      label: const Text(
                                        'My QR',
                                        maxLines: 1,
                                        softWrap: false,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: SizedBox(
                                    height: 48,
                                    child: BouncingWidget(
                                      child: FilledButton.icon(
                                        onPressed: isSyncing
                                            ? null
                                            : () async {
                                                final noteProvider = Provider.of<NoteProvider>(context, listen: false);
                                                final finProvider = Provider.of<FinancialManagerProvider>(context, listen: false);
                                                final splitProvider = Provider.of<SplitBillProvider>(context, listen: false);
                                                final savingsProvider = Provider.of<SavingsGoalProvider>(context, listen: false);
                                                final healthProvider = Provider.of<PeriodTrackerProvider>(context, listen: false);
                                                final result = await syncProvider.syncBiDirectional(
                                                  onCompleted: () => _refreshAllDomainProviders(
                                                    noteProvider,
                                                    finProvider,
                                                    splitProvider,
                                                    savingsProvider,
                                                    healthProvider,
                                                  ),
                                                );
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).clearSnackBars();
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        result.success
                                                            ? 'Sync completed successfully'
                                                            : (result.errorMessage ?? 'Sync failed'),
                                                      ),
                                                      backgroundColor: result.success
                                                          ? colorScheme.primary
                                                          : colorScheme.error,
                                                      behavior: SnackBarBehavior.floating,
                                                      action: result.success
                                                          ? null
                                                          : SnackBarAction(
                                                              label: 'Retry',
                                                              textColor: colorScheme.onError,
                                                              onPressed: () => syncProvider.syncBiDirectional(
                                                                onCompleted: () => _refreshAllDomainProviders(
                                                                  noteProvider,
                                                                  finProvider,
                                                                  splitProvider,
                                                                  savingsProvider,
                                                                  healthProvider,
                                                                ),
                                                              ),
                                                            ),
                                                    ),
                                                  );
                                                }
                                              },
                                        icon: isSyncing
                                            ? const SizedBox.shrink()
                                            : const Icon(Icons.sync_rounded),
                                        label: Text(
                                          isSyncing ? 'Syncing...' : 'Sync & Merge Now',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppLayout.spaceS),
                                Expanded(
                                  flex: 2,
                                  child: SizedBox(
                                    height: 48,
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        final success = await syncProvider.sendTestPing();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).clearSnackBars();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                syncProvider.lastMessage ??
                                                    (success ? 'Test Ping Succeeded' : 'Test Ping Failed'),
                                              ),
                                              backgroundColor: success ? colorScheme.primary : colorScheme.error,
                                              behavior: SnackBarBehavior.floating,
                                              action: success
                                                  ? null
                                                  : SnackBarAction(
                                                      label: 'Retry',
                                                      textColor: colorScheme.onError,
                                                      onPressed: () => syncProvider.sendTestPing(),
                                                    ),
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.network_ping_rounded, size: 18),
                                      label: const Text('Test Ping'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppLayout.spaceL),

                    // This Device Network & Hosting Identity Hub
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.router_rounded, color: colorScheme.primary, size: 20),
                                    const SizedBox(width: AppLayout.spaceS),
                                    Expanded(
                                      child: Text(
                                        syncProvider.localDeviceName.isEmpty
                                            ? 'This Device Hosting Info'
                                            : syncProvider.localDeviceName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Rename this device',
                                onPressed: () => _showRenameDeviceDialog(
                                  context: context,
                                  currentName: syncProvider.localDeviceName,
                                  onSave: syncProvider.renameLocalDevice,
                                ),
                              ),
                               IconButton(
                                 icon: const Icon(Icons.refresh_rounded),
                                 tooltip: 'Refresh Wi-Fi IP Address',
                                 onPressed: () async {
                                   AppHaptics.mediumImpact();
                                   await syncProvider.refreshDiagnostics();
                                   if (context.mounted) {
                                     final ip = syncProvider.localIpAddress;
                                     ScaffoldMessenger.of(context).clearSnackBars();
                                     ScaffoldMessenger.of(context).showSnackBar(
                                       SnackBar(
                                         content: Text(
                                           ip != null && ip.isNotEmpty
                                               ? 'Wi-Fi Interface Refreshed: $ip'
                                               : 'Wi-Fi Interface Refreshed (Offline / Hotspot)',
                                         ),
                                         behavior: SnackBarBehavior.floating,
                                       ),
                                     );
                                   }
                                 },
                               ),
                            ],
                          ),
                          const SizedBox(height: AppLayout.spaceM),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '6-Digit Pair Code',
                                      style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                                              borderRadius: BorderRadius.circular(AppLayout.radiusM),
                                              border: Border.all(
                                                color: colorScheme.primary.withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                syncProvider.currentPairCode,
                                                style: theme.textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 2.0,
                                                  color: colorScheme.primary,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.copy_rounded, size: 18),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                          visualDensity: VisualDensity.compact,
                                          tooltip: 'Copy Pair Code',
                                          onPressed: () {
                                            AppHaptics.selectionClick();
                                            Clipboard.setData(ClipboardData(text: syncProvider.currentPairCode));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Pair code copied to clipboard'),
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Device Local IP',
                                      style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.wifi_rounded,
                                          size: 18,
                                          color: syncProvider.localIpAddress != null ? colorScheme.primary : colorScheme.outline,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            syncProvider.localIpAddress ?? 'Checking Wi-Fi...',
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (syncProvider.localIpAddress != null && syncProvider.localIpAddress!.isNotEmpty)
                                          IconButton(
                                            icon: const Icon(Icons.copy_rounded, size: 18),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                            visualDensity: VisualDensity.compact,
                                            tooltip: 'Copy IP Address',
                                            onPressed: () {
                                              AppHaptics.selectionClick();
                                              Clipboard.setData(ClipboardData(text: syncProvider.localIpAddress!));
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('IP address copied to clipboard'),
                                                  behavior: SnackBarBehavior.floating,
                                                ),
                                              );
                                            },
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppLayout.spaceM),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: FilledButton.tonalIcon(
                              onPressed: () => _showQrCodeModal(context, syncProvider),
                              icon: const Icon(Icons.qr_code_2_rounded),
                              label: const Text('Show Host QR Code', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppLayout.spaceL),

                    // Discovered Nearby Devices (via UDP Radio Beacon)
                    Builder(
                      builder: (context) {
                        final nearbyPeers = syncProvider.discoveredPeers.where((p) =>
                            !syncProvider.pairedDevices.any((d) => d.deviceId == p.deviceId)
                        ).toList();

                        if (nearbyPeers.isEmpty) return const SizedBox.shrink();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.radar_rounded, size: 20, color: colorScheme.primary),
                                    const SizedBox(width: AppLayout.spaceS),
                                    Text(
                                      'Nearby Devices (${nearbyPeers.length})',
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const AppChip(
                                  label: 'Discovered',
                                  isSelected: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppLayout.spaceS),
                            ...List.generate(nearbyPeers.length, (idx) {
                              final peer = nearbyPeers[idx];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: AppLayout.spaceS),
                                child: AppCard(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(AppLayout.radiusM),
                                    onTap: () => _showPairDeviceDialog(context, syncProvider, initialPeer: peer),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(AppLayout.spaceS),
                                          decoration: BoxDecoration(
                                            color: colorScheme.primaryContainer,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(Icons.wifi_tethering_rounded, color: colorScheme.onPrimaryContainer),
                                        ),
                                        const SizedBox(width: AppLayout.spaceM),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                peer.deviceName,
                                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${peer.ipAddress}:${peer.port} • Ready to Pair',
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        FilledButton.tonal(
                                          onPressed: () => _showPairDeviceDialog(context, syncProvider, initialPeer: peer),
                                          style: FilledButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 14),
                                          ),
                                          child: const Text('Pair'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: AppLayout.spaceM),
                          ],
                        );
                      },
                    ),

                    // Paired Devices List Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Paired Devices (${syncProvider.pairedDevices.length})',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        FilledButton.icon(
                          onPressed: () => _showPairDeviceDialog(context, syncProvider),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Pair Device'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppLayout.spaceS),

                    if (syncProvider.pairedDevices.isEmpty)
                      AppCard(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppLayout.spaceL),
                            child: Column(
                              children: [
                                Icon(Icons.devices_other_rounded, size: 48, color: colorScheme.outline),
                                const SizedBox(height: AppLayout.spaceS),
                                Text(
                                  'No devices paired yet',
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap "Pair Device" to scan QR code or enter IP address.',
                                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      ...List.generate(syncProvider.pairedDevices.length, (index) {
                        final device = syncProvider.pairedDevices[index];
                        final targetIp = device.ipAddress;
                        final count = syncProvider.pairedDevices.length;
                        final isFirst = index == 0;
                        final isLast = index == count - 1;
                        final isOnly = count == 1;

                        final BorderRadiusGeometry radiusGeometry;
                        if (isOnly) {
                          radiusGeometry = BorderRadius.circular(AppLayout.radiusL);
                        } else if (isFirst) {
                          radiusGeometry = const BorderRadius.vertical(
                            top: Radius.circular(AppLayout.radiusL),
                            bottom: Radius.circular(AppLayout.radiusXS),
                          );
                        } else if (isLast) {
                          radiusGeometry = const BorderRadius.vertical(
                            top: Radius.circular(AppLayout.radiusXS),
                            bottom: Radius.circular(AppLayout.radiusL),
                          );
                        } else {
                          radiusGeometry = BorderRadius.circular(AppLayout.radiusXS);
                        }

                        return Padding(
                          padding: EdgeInsets.only(bottom: isLast ? AppLayout.spaceL : 2.0),
                          child: AppCard(
                            borderRadiusGeometry: radiusGeometry,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(AppLayout.spaceS),
                                  decoration: BoxDecoration(
                                    color: device.role == 'PRIMARY'
                                        ? colorScheme.primaryContainer
                                        : colorScheme.secondaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    device.role == 'PRIMARY' ? Icons.star_rounded : Icons.phone_android_rounded,
                                    color: device.role == 'PRIMARY'
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSecondaryContainer,
                                  ),
                                ),
                                const SizedBox(width: AppLayout.spaceM),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        device.deviceName,
                                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        targetIp != null && targetIp.isNotEmpty
                                            ? '${device.endpoints.length} network ${device.endpoints.length == 1 ? 'endpoint' : 'endpoints'} • $targetIp • ${device.lastSyncedAt != null ? DateFormat.jm().format(device.lastSyncedAt!) : 'Not synced'}'
                                            : (device.lastSyncedAt != null
                                                ? 'Last synced ${DateFormat.jm().format(device.lastSyncedAt!)}'
                                                : 'Not synced yet'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                                if (targetIp != null && targetIp.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.sync_rounded),
                                    color: colorScheme.primary,
                                    tooltip: 'Sync with ${device.deviceName}',
                                    onPressed: isSyncing
                                        ? null
                                        : () async {
                                            final noteProvider = Provider.of<NoteProvider>(context, listen: false);
                                            final finProvider = Provider.of<FinancialManagerProvider>(context, listen: false);
                                            final splitProvider = Provider.of<SplitBillProvider>(context, listen: false);
                                            final savingsProvider = Provider.of<SavingsGoalProvider>(context, listen: false);
                                            final healthProvider = Provider.of<PeriodTrackerProvider>(context, listen: false);
                                            final res = await syncProvider.syncBiDirectional(
                                              targetIp: targetIp,
                                              onCompleted: () => _refreshAllDomainProviders(
                                                noteProvider,
                                                finProvider,
                                                splitProvider,
                                                savingsProvider,
                                                healthProvider,
                                              ),
                                            );
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    res.success ? 'Synced with ${device.deviceName}' : (res.errorMessage ?? 'Sync failed'),
                                                  ),
                                                  behavior: SnackBarBehavior.floating,
                                                ),
                                              );
                                            }
                                          },
                                  ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppLayout.radiusM),
                                  ),
                                  tooltip: 'Device options',
                                  onSelected: (value) async {
                                    if (value == 'rename') {
                                      _showRenameDeviceDialog(
                                        context: context,
                                        currentName: device.deviceName,
                                        onSave: (name) => syncProvider.renamePairedDevice(device.deviceId, name),
                                      );
                                    } else if (value == 'unpair') {
                                      final confirmed = await AppDialog.showConfirm(
                                        context: context,
                                        title: 'Unpair ${device.deviceName}?',
                                        message: 'This device will be removed from your trusted peer network. You can pair it again at any time.',
                                        confirmLabel: 'Unpair',
                                        isDestructive: true,
                                      );
                                      if (confirmed == true) {
                                        await syncProvider.unpairDevice(device.deviceId);
                                      }
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'rename',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 18, color: colorScheme.onSurface),
                                          const SizedBox(width: AppLayout.spaceS),
                                          const Text('Rename'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'unpair',
                                      child: Row(
                                        children: [
                                          Icon(Icons.link_off_rounded, size: 18, color: colorScheme.error),
                                          const SizedBox(width: AppLayout.spaceS),
                                          Text('Unpair', style: TextStyle(color: colorScheme.error)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: AppLayout.spaceL),

                    // Offline Backup File Fallback Card
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.folder_zip_rounded, color: colorScheme.secondary, size: 20),
                              const SizedBox(width: AppLayout.spaceS),
                              Text(
                                'Offline Backup File Fallback',
                                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Share offline backup files via Bluetooth, Nearby Share, or Google Drive as a manual fallback.',
                            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: AppLayout.spaceM),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      AppLockScreen.ignoreNextResumeLock();
                                      BackupService.exportBackup(context);
                                    },
                                    icon: const Icon(Icons.share_rounded, size: 18),
                                    label: const Text(
                                      'Export & Share',
                                      maxLines: 1,
                                      softWrap: false,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppLayout.spaceS),
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: FilledButton.tonalIcon(
                                    onPressed: () {
                                      AppLockScreen.ignoreNextResumeLock();
                                      BackupService.importBackup(context);
                                    },
                                    icon: const Icon(Icons.file_open_rounded, size: 18),
                                    label: const Text(
                                      'Import File',
                                      maxLines: 1,
                                      softWrap: false,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppLayout.spaceL),

                    // Options & Preferences Card
                    AppCard(
                      child: Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
                          value: syncProvider.isAutoSyncEnabled,
                          onChanged: (val) => syncProvider.setAutoSyncEnabled(val),
                          title: const Text('Event Auto-Sync'),
                          subtitle: const Text('Sync 3s after saving notes or ledgers'),
                          secondary: const Icon(Icons.sync_lock_rounded),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_bottom_sheet.dart';
import '../../../../core/ui/app_dialog.dart';
import '../../../../screens/app_lock_screen.dart';
import '../../../../services/p2p_sync_service.dart';
import '../../data/p2p_pairing_model.dart';
import '../../providers/p2p_sync_provider.dart';
import 'qr_scanner_dialog.dart';

/// Encapsulates P2P Sync modal sheets and dialogs (Pair Device, Host QR Code,
/// Rename Device, and Cross-Network E2EE Relay Configuration).
class P2pSyncModals {
  const P2pSyncModals._();

  static void showPairDeviceDialog({
    required BuildContext context,
    required P2pSyncProvider syncProvider,
    required TextEditingController pairCodeController,
    required TextEditingController deviceNameController,
    required TextEditingController targetIpController,
    required VoidCallback onRefreshProviders,
    DiscoveredPeer? initialPeer,
  }) {
    String? scannedDeviceId;
    int scannedTargetPort = 8765;
    List<String> scannedCandidateIps = const [];

    if (initialPeer != null) {
      deviceNameController.text = initialPeer.deviceName;
      targetIpController.text = initialPeer.ipAddress;
      scannedDeviceId = initialPeer.deviceId;
      scannedTargetPort = initialPeer.port;
      scannedCandidateIps = [initialPeer.ipAddress];
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        bool isPairing = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final colorScheme = theme.colorScheme;

            return AppDialog(
              title: 'Pair New Device',
              showConfirmButton: false,
              actions: [
                TextButton(
                  onPressed: isPairing ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: isPairing
                      ? null
                      : () async {
                          final code = pairCodeController.text.trim();
                          final name = deviceNameController.text.trim();
                          final ip = targetIpController.text.trim();
                          if (code.length == 6) {
                            setDialogState(() {
                              isPairing = true;
                              errorMessage = null;
                            });

                            try {
                              final paired = await syncProvider.pairNewDevice(
                                deviceName: name.isEmpty ? PairedDevice.generateRandomName() : name,
                                pairCode: code,
                                targetIp: ip.isEmpty ? 'relay' : ip,
                                candidateIps: scannedCandidateIps,
                                targetPort: scannedTargetPort,
                                remoteDeviceId: scannedDeviceId,
                                role: 'PEER',
                              );
                              await syncProvider.syncBiDirectional(
                                targetIp: paired.ipAddress ?? (ip.isEmpty ? 'relay' : ip),
                                onCompleted: onRefreshProviders,
                              );
                              pairCodeController.clear();
                              deviceNameController.clear();
                              targetIpController.clear();
                              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Successfully paired with ${paired.deviceName}!'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              setDialogState(() {
                                isPairing = false;
                                errorMessage = P2pSyncService.formatUserFriendlyErrorMessage(e, ip);
                              });
                            }
                          } else {
                            setDialogState(() {
                              errorMessage = 'Please enter a valid 6-digit pair code.';
                            });
                          }
                        },
                  child: isPairing
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                          ),
                        )
                      : const Text('Pair & Sync Device'),
                ),
              ],
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppLayout.spaceS + 2),
                        margin: const EdgeInsets.only(bottom: AppLayout.spaceM),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(AppLayout.radiusM),
                          border: Border.all(color: colorScheme.error.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 20),
                            const SizedBox(width: AppLayout.spaceS),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Text(
                      'Scan the Primary device QR code to auto-detect IP and pair code in 1 tap.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppLayout.spaceM),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: isPairing
                            ? null
                            : () async {
                                AppLockScreen.ignoreNextResumeLock();
                                final scanned = await Navigator.push<String>(
                                  context,
                                  MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                                );
                                if (scanned != null && scanned.isNotEmpty) {
                                  try {
                                    final map = json.decode(scanned) as Map<String, dynamic>;
                                    setDialogState(() {
                                      pairCodeController.text = map['code']?.toString() ?? scanned;
                                      if (map['ip'] != null) targetIpController.text = map['ip'].toString();
                                      if (map['name'] != null) deviceNameController.text = map['name'].toString();
                                      scannedDeviceId = map['deviceId']?.toString();
                                      scannedTargetPort = map['port'] is int
                                          ? map['port'] as int
                                          : int.tryParse('${map['port']}') ?? 8765;
                                      if (map['ips'] is List) {
                                        scannedCandidateIps = (map['ips'] as List)
                                            .map((e) => e.toString())
                                            .where((e) => e.isNotEmpty)
                                            .toList();
                                      } else {
                                        scannedCandidateIps = const [];
                                      }
                                    });
                                  } catch (_) {
                                    setDialogState(() {
                                      pairCodeController.text = scanned;
                                    });
                                  }
                                }
                              },
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Text('Scan QR Code', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: AppLayout.spaceL),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppLayout.spaceXS),
                        child: Text(
                          'OR ENTER MANUAL IP & CODE',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.outline,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppLayout.spaceM),
                    TextField(
                      controller: targetIpController,
                      enabled: !isPairing,
                      keyboardType: TextInputType.datetime,
                      decoration: const InputDecoration(
                        labelText: 'Primary IP Address (Optional on Relay)',
                        helperText: 'Leave blank to pair via Cross-Network E2EE Relay',
                        prefixIcon: Icon(Icons.wifi_rounded),
                      ),
                    ),
                    const SizedBox(height: AppLayout.spaceS),
                    TextField(
                      controller: pairCodeController,
                      enabled: !isPairing,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: '6-Digit Pair Code',
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                    ),
                    const SizedBox(height: AppLayout.spaceS),
                    TextField(
                      controller: deviceNameController,
                      enabled: !isPairing,
                      decoration: const InputDecoration(
                        labelText: 'Device Name (Optional)',
                        prefixIcon: Icon(Icons.devices_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Future<void> showQrCodeModal(BuildContext context, P2pSyncProvider provider) async {
    await provider.startPrimaryHostServer();
    await provider.refreshDiagnostics();
    if (!context.mounted) return;
    final qrData = json.encode({
      'version': 2,
      'role': 'PRIMARY',
      'code': provider.currentPairCode,
      'deviceId': provider.localDeviceId,
      'name': provider.localDeviceName,
      'ip': provider.localIpAddress ?? '',
      'ips': provider.localIpAddresses,
      'port': 8765,
    });

    await AppBottomSheet.show(
      context: context,
      title: 'Primary Host QR Code',
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppLayout.spaceS),
            Container(
              padding: const EdgeInsets.all(AppLayout.spaceM),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppLayout.radiusL),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 210.0,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.circle,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: AppLayout.spaceL),
            Text(
              'Pair Code: ${provider.currentPairCode}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4.0,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            if (provider.localIpAddress != null) ...[
              const SizedBox(height: 4),
              Text(
                'Local IP: ${provider.localIpAddress}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            const SizedBox(height: AppLayout.spaceL),
          ],
        ),
      ),
    );
  }

  static void showRenameDeviceDialog({
    required BuildContext context,
    required String currentName,
    required Future<void> Function(String name) onSave,
  }) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Rename Device',
        confirmLabel: 'Save Name',
        onConfirm: () async {
          AppHaptics.selectionClick();
          await onSave(controller.text);
          if (dialogContext.mounted) Navigator.pop(dialogContext);
        },
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Device name',
            prefixIcon: Icon(Icons.devices_outlined),
          ),
        ),
      ),
    ).whenComplete(controller.dispose);
  }

  static void showCustomRelayDialog(BuildContext context, P2pSyncProvider syncProvider) {
    final controller = TextEditingController(text: syncProvider.customRelayUrl ?? '');
    showDialog(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: 'Cross-Network E2EE Relay',
        confirmLabel: 'Save Relay',
        onConfirm: () async {
          await syncProvider.setCustomRelayUrl(controller.text);
          if (dialogContext.mounted) Navigator.pop(dialogContext);
        },
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Active Relays: ${syncProvider.connectedRelayCount} connected (BIP-340 Schnorr + AES-256 E2EE). '
              'Used automatically when devices are on Mobile Data (4G/5G) or Wi-Fi routers with AP Client Isolation.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppLayout.spaceM),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Custom Relay URL (Optional)',
                hintText: 'wss://relay.example.com',
                prefixIcon: Icon(Icons.hub_rounded),
              ),
            ),
          ],
        ),
      ),
    ).whenComplete(controller.dispose);
  }
}

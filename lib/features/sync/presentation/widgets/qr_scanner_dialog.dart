import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_card.dart';
import '../../../../core/ui/expressive_sliver_app_bar.dart';
import '../../../../screens/app_lock_screen.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    AppLockScreen.ignoreNextResumeLock();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            errorBuilder: (context, error, child) {
              final theme = Theme.of(context);
              final colorScheme = theme.colorScheme;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppLayout.spaceL),
                  child: AppCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.no_photography_rounded,
                          size: 48,
                          color: colorScheme.error,
                        ),
                        const SizedBox(height: AppLayout.spaceM),
                        Text(
                          'Camera Unavailable',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppLayout.spaceXS),
                        Text(
                          error.errorDetails?.message ??
                              'Grant camera permission in Settings or enter the 6-digit pair code and IP address manually.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: AppLayout.spaceM),
                        FilledButton.tonalIcon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.keyboard_rounded),
                          label: const Text('Enter IP & Code Manually'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            onDetect: (capture) {
              if (_hasScanned) return;
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final String? rawValue = barcode.rawValue;
                if (rawValue != null && rawValue.isNotEmpty) {
                  _hasScanned = true;
                  Navigator.pop(context, rawValue);
                  break;
                }
              }
            },
          ),
          const CustomScrollView(
            slivers: [
              ExpressiveSliverAppBar(
                titleText: 'Scan Pair QR Code',
                showBackButton: true,
              ),
            ],
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(AppLayout.radiusL),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

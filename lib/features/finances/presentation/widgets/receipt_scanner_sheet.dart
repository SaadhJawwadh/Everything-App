import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_bottom_sheet.dart';
import '../../../../core/ui/expressive_shape_morph_indicator.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import '../../../../screens/app_lock_screen.dart';
import '../../services/receipt_scanner_service.dart';

class ReceiptScannerSheet extends StatefulWidget {
  const ReceiptScannerSheet({super.key});

  static Future<Map<String, dynamic>?> show(BuildContext context) async {
    return await AppBottomSheet.show<Map<String, dynamic>>(
      context: context,
      title: 'Scan Physical Receipt',
      child: const ReceiptScannerSheet(),
    );
  }

  @override
  State<ReceiptScannerSheet> createState() => _ReceiptScannerSheetState();
}

class _ReceiptScannerSheetState extends State<ReceiptScannerSheet> {
  final _picker = ImagePicker();
  final _titleController = TextEditingController();
  final _totalController = TextEditingController();
  
  String? _imagePath;
  bool _isScanning = false;
  int _scanPhase = 0;
  Timer? _tickerTimer;
  ParsedReceiptResult? _scanResult;
  String? _errorMessage;

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _titleController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  Future<void> _pickAndScan(ImageSource source) async {
    try {
      final XFile? file = await AppLockScreen.withLockIgnored(() => _picker.pickImage(source: source));
      if (file == null) return;

      if (!mounted) return;
      final settings = Provider.of<SettingsProvider>(context, listen: false);

      setState(() {
        _imagePath = file.path;
        _isScanning = true;
        _scanPhase = 0;
        _errorMessage = null;
      });

      _tickerTimer?.cancel();
      _tickerTimer = Timer.periodic(const Duration(milliseconds: 380), (timer) {
        if (!mounted || !_isScanning) {
          timer.cancel();
          return;
        }
        setState(() {
          if (_scanPhase < 2) {
            _scanPhase++;
          }
        });
      });

      final result = await ReceiptScannerService.instance.processReceiptImage(
        file.path,
        isAiActive: settings.isAiActive,
      );

      _tickerTimer?.cancel();

      if (!mounted) return;

      setState(() {
        _isScanning = false;
        _scanResult = result;
        if (result != null) {
          if (result.merchantTitle != null && result.merchantTitle!.isNotEmpty) {
            _titleController.text = result.merchantTitle!;
          }
          if (result.totalAmount != null && result.totalAmount! > 0) {
            _totalController.text = result.totalAmount!.toStringAsFixed(2).replaceAll('.00', '');
          }
        }
      });
    } catch (e) {
      _tickerTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _errorMessage = 'Failed to process receipt: $e';
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + AppLayout.spaceL,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_imagePath == null) ...[
            Text(
              'Select receipt image to automatically extract total, merchant name, and date using offline ML.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppLayout.spaceL),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickAndScan(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: AppLayout.spaceM),
                    ),
                  ),
                ),
                const SizedBox(width: AppLayout.spaceM),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _pickAndScan(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Camera'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: AppLayout.spaceM),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            if (_isScanning) ...[
              const SizedBox(height: AppLayout.spaceL),
              Center(
                child: Column(
                  children: [
                    const ExpressiveShapeMorphIndicator(size: 48),
                    const SizedBox(height: AppLayout.spaceM),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Row(
                        key: ValueKey<int>(_scanPhase),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _scanPhase == 0
                                ? Icons.document_scanner_rounded
                                : (_scanPhase == 1
                                    ? Icons.calculate_rounded
                                    : Icons.storefront_rounded),
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _scanPhase == 0
                                ? 'Extracting text lines locally...'
                                : (_scanPhase == 1
                                    ? 'Calculating subtotal, tax & tips...'
                                    : 'Matching merchant & category...'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppLayout.spaceL),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppLayout.radiusS),
                    child: Image.file(
                      File(_imagePath!),
                      width: 68,
                      height: 84,
                      cacheWidth: 300,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 68,
                        height: 84,
                        color: colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.receipt_long_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppLayout.spaceM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Receipt Scanned',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppLayout.spaceXS),
                        Text(
                          _scanResult?.totalAmount != null
                              ? 'Extracted Total: Rs. ${_scanResult!.totalAmount!.toStringAsFixed(2)}'
                              : 'Total not detected automatically. Please verify below.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _scanResult?.totalAmount != null ? Colors.green : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppLayout.spaceXS),
                        InkWell(
                          onTap: () => setState(() => _imagePath = null),
                          child: Text(
                            'Retake Photo',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppLayout.spaceM),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Merchant / Bill Title',
                  prefixIcon: Icon(Icons.store_rounded),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppLayout.spaceM),
              TextField(
                controller: _totalController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Total Bill Amount (${context.read<SettingsProvider>().currency})',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      widthFactor: 0.0,
                      child: Text(
                        context.read<SettingsProvider>().currency,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppLayout.spaceL),
              FilledButton.icon(
                onPressed: _applyScan,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Apply to Bill'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
              ),
            ],
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: AppLayout.spaceS),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppLayout.spaceS),
        ],
      ),
    );
  }

  void _applyScan() {
    final title = _titleController.text.trim();
    final total = double.tryParse(_totalController.text.trim());

    if (total == null || total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid bill amount.')),
      );
      return;
    }

    AppHaptics.mediumImpact();
    Navigator.of(context).pop({
      'title': title.isNotEmpty ? title : 'Scanned Receipt',
      'total': total,
      'imagePath': _imagePath,
    });
  }
}

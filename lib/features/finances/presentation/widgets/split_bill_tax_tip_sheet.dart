import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_bottom_sheet.dart';
import '../../../../core/ui/app_card.dart';
import '../../../settings/providers/settings_provider.dart';

/// Proportional tax, tip, and flat-fee distributor sheet for [SplitBillEditorScreen].
class SplitBillTaxTipSheet extends StatefulWidget {
  final double currentSubtotalSum;
  final int totalSplitCount;
  final void Function(double grandTotal, double extraRatio, double feePerPerson)
      onApply;

  const SplitBillTaxTipSheet({
    super.key,
    required this.currentSubtotalSum,
    required this.totalSplitCount,
    required this.onApply,
  });

  static void show({
    required BuildContext context,
    required double currentSubtotalSum,
    required int totalSplitCount,
    required void Function(
      double grandTotal,
      double extraRatio,
      double feePerPerson,
    ) onApply,
  }) {
    AppBottomSheet.show(
      context: context,
      title: 'Proportional Tax & Tip Allocator',
      child: SplitBillTaxTipSheet(
        currentSubtotalSum: currentSubtotalSum,
        totalSplitCount: totalSplitCount,
        onApply: onApply,
      ),
    );
  }

  @override
  State<SplitBillTaxTipSheet> createState() => _SplitBillTaxTipSheetState();
}

class _SplitBillTaxTipSheetState extends State<SplitBillTaxTipSheet> {
  final _taxPercentController = TextEditingController();
  final _tipPercentController = TextEditingController();
  final _flatFeeController = TextEditingController();

  @override
  void dispose() {
    _taxPercentController.dispose();
    _tipPercentController.dispose();
    _flatFeeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency =
        Provider.of<SettingsProvider>(context, listen: false).currencySymbol;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mediaQuery = MediaQuery.of(context);

    final taxPct = double.tryParse(_taxPercentController.text.trim()) ?? 0.0;
    final tipPct = double.tryParse(_tipPercentController.text.trim()) ?? 0.0;
    final flatFee = double.tryParse(_flatFeeController.text.trim()) ?? 0.0;

    final currentSubtotalSum = widget.currentSubtotalSum;
    final calculatedTax = currentSubtotalSum * (taxPct / 100.0);
    final calculatedTip = currentSubtotalSum * (tipPct / 100.0);
    final grandCalculatedTotal =
        currentSubtotalSum + calculatedTax + calculatedTip + flatFee;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: mediaQuery.viewInsets.bottom + AppLayout.spaceS,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Distributes tax, tip & service fees across subtotals',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppLayout.spaceM),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _taxPercentController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Tax / VAT %',
                    hintText: 'e.g. 10',
                    suffixText: '%',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: AppLayout.spaceM),
              Expanded(
                child: TextField(
                  controller: _tipPercentController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Tip / Service %',
                    hintText: 'e.g. 15',
                    suffixText: '%',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppLayout.spaceM),
          TextField(
            controller: _flatFeeController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Flat Delivery or Service Fee',
              hintText: 'e.g. 5.00',
              prefixText: '$currency ',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppLayout.spaceL),
          AppCard(
            padding: const EdgeInsets.all(AppLayout.spaceM),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Items Subtotal:', style: theme.textTheme.bodyMedium),
                    Text(
                      '$currency ${currentSubtotalSum.toStringAsFixed(2)}',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (calculatedTax > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tax (${taxPct.toStringAsFixed(1)}%):',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      Text(
                        '+$currency ${calculatedTax.toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
                if (calculatedTip > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tip (${tipPct.toStringAsFixed(1)}%):',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      Text(
                        '+$currency ${calculatedTip.toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
                if (flatFee > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Flat Extra Fee:',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      Text(
                        '+$currency ${flatFee.toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Computed Grand Total:',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '$currency ${grandCalculatedTotal.toStringAsFixed(2)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppLayout.spaceL),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppLayout.spaceM),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Apply to All Shares'),
                  onPressed: () {
                    if (currentSubtotalSum <= 0) {
                      Navigator.pop(context);
                      return;
                    }
                    final extraRatio =
                        (calculatedTax + calculatedTip) / currentSubtotalSum;
                    final feePerPerson = widget.totalSplitCount > 0
                        ? (flatFee / widget.totalSplitCount)
                        : 0.0;

                    widget.onApply(
                      grandCalculatedTotal,
                      extraRatio,
                      feePerPerson,
                    );
                    Navigator.pop(context);
                    AppHaptics.mediumImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Tax, tip, and fees distributed proportionally!',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

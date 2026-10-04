import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_bottom_sheet.dart';
import '../../../../core/ui/expressive_wavy_slider.dart';
import '../../../../data/transaction_model.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../providers/financial_manager_provider.dart';

/// Modal bottom sheet allowing instantaneous double-entry fund transfers
/// between Daily Operating Account and Savings Vault.
class AccountTransferSheet extends StatefulWidget {
  const AccountTransferSheet({super.key});

  static Future<void> show(BuildContext context) {
    return AppBottomSheet.show<void>(
      context: context,
      title: 'Transfer Between Accounts',
      child: const AccountTransferSheet(),
    );
  }

  @override
  State<AccountTransferSheet> createState() => _AccountTransferSheetState();
}

class _AccountTransferSheetState extends State<AccountTransferSheet> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String _fromAccount = AccountType.daily;
  String _toAccount = AccountType.savings;
  double _sliderValue = 0.0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = '0';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _swapAccounts() {
    AppHaptics.lightImpact();
    setState(() {
      final temp = _fromAccount;
      _fromAccount = _toAccount;
      _toAccount = temp;
    });
  }

  void _setAmount(double val, double maxCap) {
    final clamped = val.clamp(0.0, maxCap > 0 ? maxCap : 1000000.0);
    setState(() {
      _sliderValue = clamped;
      _amountController.text = clamped.toStringAsFixed(clamped.truncateToDouble() == clamped ? 0 : 2);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final settings = context.watch<SettingsProvider>();
    final financeProvider = context.watch<FinancialManagerProvider>();

    final currency = settings.currencySymbol;
    final account1Name = settings.account1Name;
    final account2Name = settings.account2Name;

    final fromName = _fromAccount == AccountType.daily ? account1Name : account2Name;
    final toName = _toAccount == AccountType.daily ? account1Name : account2Name;

    final fromBalance = _fromAccount == AccountType.daily
        ? financeProvider.dailyCashFlow
        : financeProvider.savingsVaultCashFlow;
    final toBalance = _toAccount == AccountType.daily
        ? financeProvider.dailyCashFlow
        : financeProvider.savingsVaultCashFlow;

    final maxSlider = fromBalance > 0 ? fromBalance : 50000.0;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Account Direction Cards ──
          Row(
            children: [
              Expanded(
                child: _buildAccountBox(
                  theme: theme,
                  label: 'From',
                  accountName: fromName,
                  balance: fromBalance,
                  currency: currency,
                  icon: _fromAccount == AccountType.daily
                      ? Icons.credit_card_outlined
                      : Icons.account_balance_outlined,
                  color: cs.primary,
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Swap Direction',
                onPressed: _swapAccounts,
                icon: const Icon(Icons.swap_horiz_rounded),
              ),
              Expanded(
                child: _buildAccountBox(
                  theme: theme,
                  label: 'To',
                  accountName: toName,
                  balance: toBalance,
                  currency: currency,
                  icon: _toAccount == AccountType.daily
                      ? Icons.credit_card_outlined
                      : Icons.account_balance_outlined,
                  color: cs.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Amount Input Display ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppLayout.radiusL),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  currency,
                  style: tt.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 8),
                IntrinsicWidth(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    style: tt.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (text) {
                      final parsed = double.tryParse(text) ?? 0.0;
                      setState(() {
                        _sliderValue = parsed.clamp(0.0, maxSlider);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Tactile Sinusoidal Slider ──
          ExpressiveWavySlider(
            value: _sliderValue.clamp(0.0, maxSlider),
            min: 0.0,
            max: maxSlider,
            onChanged: (val) {
              _setAmount(val, maxSlider);
            },
          ),
          const SizedBox(height: 8),

          // ── Preset Amount Quick Chips ──
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildPresetChip('+100', 100, maxSlider),
              _buildPresetChip('+500', 500, maxSlider),
              _buildPresetChip('+1,000', 1000, maxSlider),
              _buildPresetChip('+5,000', 5000, maxSlider),
              if (fromBalance > 0)
                ActionChip(
                  label: const Text('All Available'),
                  avatar: const Icon(Icons.all_inclusive_rounded, size: 14),
                  onPressed: () {
                    AppHaptics.lightImpact();
                    _setAmount(fromBalance, maxSlider);
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Optional Note Input ──
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              hintText: 'Optional transfer memo (e.g. Monthly savings)',
              prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),

          // ── Confirm CTA ──
          FilledButton.icon(
            onPressed: _isSubmitting
                ? null
                : () async {
                    final amount = double.tryParse(_amountController.text) ?? 0.0;
                    if (amount <= 0) {
                      AppHaptics.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter an amount greater than 0')),
                      );
                      return;
                    }

                    setState(() => _isSubmitting = true);
                    AppHaptics.mediumImpact();

                    try {
                      await context.read<FinancialManagerProvider>().transferFunds(
                            amount: amount,
                            fromAccount: _fromAccount,
                            toAccount: _toAccount,
                            note: _noteController.text,
                          );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Transferred $currency ${amount.toStringAsFixed(2)} to $toName',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        setState(() => _isSubmitting = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Transfer failed: $e')),
                        );
                      }
                    }
                  },
            icon: const Icon(Icons.check_circle_rounded),
            label: Text(
              _isSubmitting ? 'Transferring...' : 'Confirm Transfer',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountBox({
    required ThemeData theme,
    required String label,
    required String accountName,
    required double balance,
    required String currency,
    required IconData icon,
    required Color color,
  }) {
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppLayout.radiusL),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            accountName,
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '$currency ${balance.toStringAsFixed(0)}',
            style: tt.bodySmall?.copyWith(
              color: balance >= 0 ? cs.primary : cs.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, double addAmount, double maxSlider) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        AppHaptics.selectionClick();
        final current = double.tryParse(_amountController.text) ?? 0.0;
        _setAmount(current + addAmount, maxSlider);
      },
    );
  }
}

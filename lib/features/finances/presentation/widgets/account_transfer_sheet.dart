import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_bottom_sheet.dart';
import '../../../../data/transaction_model.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../providers/financial_manager_provider.dart';

/// Modal bottom sheet allowing instantaneous double-entry fund transfers
/// between Daily Operating Account and Savings Vault with live balance preview.
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
  double _swapTurns = 0.0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = '';
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
      _swapTurns += 0.5;
    });
  }

  void _addAmount(double addVal) {
    AppHaptics.selectionClick();
    final current = double.tryParse(_amountController.text) ?? 0.0;
    final total = current + addVal;
    _setAbsoluteAmount(total);
  }

  void _setAbsoluteAmount(double val) {
    setState(() {
      _amountController.text = val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 2);
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

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final isOverBalance = fromBalance > 0 && amount > fromBalance;

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
          // ── Connected Vertical Flow Card ──
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppLayout.radiusL),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    // FROM Account Row
                    _buildAccountRow(
                      theme: theme,
                      label: 'From Account',
                      accountName: fromName,
                      balance: fromBalance,
                      currency: currency,
                      icon: _fromAccount == AccountType.daily
                          ? Icons.credit_card_rounded
                          : Icons.savings_outlined,
                      isFrom: true,
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.25),
                    ),
                    // TO Account Row
                    _buildAccountRow(
                      theme: theme,
                      label: 'To Account',
                      accountName: toName,
                      balance: toBalance,
                      currency: currency,
                      icon: _toAccount == AccountType.daily
                          ? Icons.credit_card_rounded
                          : Icons.savings_outlined,
                      isFrom: false,
                    ),
                  ],
                ),
              ),

              // Floating overlapping swap button
              Positioned(
                child: Material(
                  color: cs.surfaceContainerHighest,
                  shape: const CircleBorder(),
                  elevation: 2,
                  shadowColor: cs.shadow.withValues(alpha: 0.15),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _swapAccounts,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: AnimatedRotation(
                        turns: _swapTurns,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack,
                        child: Icon(
                          Icons.swap_vert_rounded,
                          size: 20,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Hero Amount Input Display ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppLayout.radiusL),
              border: Border.all(
                color: isOverBalance
                    ? cs.error.withValues(alpha: 0.6)
                    : cs.outlineVariant.withValues(alpha: 0.45),
                width: isOverBalance ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  currency,
                  style: tt.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isOverBalance ? cs.error : cs.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: IntrinsicWidth(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textAlign: TextAlign.center,
                      autofocus: false,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      style: tt.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isOverBalance ? cs.error : cs.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: tt.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.outlineVariant.withValues(alpha: 0.7),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (text) {
                        setState(() {});
                      },
                    ),
                  ),
                ),
                if (amount > 0) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.cancel_rounded, size: 20),
                    color: cs.onSurfaceVariant,
                    onPressed: () {
                      AppHaptics.selectionClick();
                      setState(() {
                        _amountController.text = '';
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Clear',
                  ),
                ],
              ],
            ),
          ),

          // ── Dynamic Projected Balance or Warning ──
          if (amount > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isOverBalance
                    ? cs.errorContainer.withValues(alpha: 0.35)
                    : cs.primaryContainer.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
                border: Border.all(
                  color: isOverBalance
                      ? cs.error.withValues(alpha: 0.4)
                      : cs.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isOverBalance ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                    size: 16,
                    color: isOverBalance ? cs.error : cs.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isOverBalance
                          ? 'Transfer exceeds available balance ($currency ${fromBalance.toStringAsFixed(2)})'
                          : 'New balance: $fromName $currency ${(fromBalance - amount).toStringAsFixed(0)} • $toName $currency ${(toBalance + amount).toStringAsFixed(0)}',
                      style: tt.bodySmall?.copyWith(
                        color: isOverBalance ? cs.error : cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

          // ── Preset Amount Quick Chips ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPresetChip('+100', 100),
                const SizedBox(width: 8),
                _buildPresetChip('+500', 500),
                const SizedBox(width: 8),
                _buildPresetChip('+1,000', 1000),
                const SizedBox(width: 8),
                _buildPresetChip('+5,000', 5000),
                if (fromBalance > 0) ...[
                  const SizedBox(width: 8),
                  ActionChip(
                    label: Text(
                      'Max ($currency ${fromBalance.toStringAsFixed(0)})',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                    backgroundColor: cs.secondaryContainer.withValues(alpha: 0.55),
                    side: BorderSide(color: cs.secondary.withValues(alpha: 0.35)),
                    avatar: Icon(Icons.flash_on_rounded, size: 16, color: cs.secondary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                    ),
                    onPressed: () {
                      AppHaptics.lightImpact();
                      _setAbsoluteAmount(fromBalance);
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Optional Note Input ──
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              hintText: 'Transfer memo (e.g. Monthly savings)',
              hintStyle: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              prefixIcon: Icon(Icons.edit_note_rounded, size: 22, color: cs.primary),
              filled: true,
              fillColor: cs.surfaceContainerLowest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
                borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
                borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
                borderSide: BorderSide(color: cs.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),

          // ── Confirm CTA ──
          FilledButton.icon(
            onPressed: _isSubmitting || amount <= 0
                ? null
                : () async {
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
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.arrow_forward_rounded),
            label: Text(
              _isSubmitting ? 'Transferring...' : 'Transfer to $toName',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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

  Widget _buildAccountRow({
    required ThemeData theme,
    required String label,
    required String accountName,
    required double balance,
    required String currency,
    required IconData icon,
    required bool isFrom,
  }) {
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isFrom
                  ? cs.primaryContainer.withValues(alpha: 0.5)
                  : cs.secondaryContainer.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: isFrom ? cs.primary : cs.secondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  accountName,
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Available',
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$currency ${balance.toStringAsFixed(2)}',
                style: tt.bodyMedium?.copyWith(
                  color: balance >= 0 ? cs.onSurface : cs.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, double addAmount) {
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
      ),
      onPressed: () => _addAmount(addAmount),
    );
  }
}

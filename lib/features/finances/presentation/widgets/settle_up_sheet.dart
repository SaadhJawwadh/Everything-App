import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/app_bottom_sheet.dart';
import '../../../../core/ui/app_card.dart';
import '../../../../data/category_constants.dart';
import '../../../../data/transaction_model.dart';
import '../../data/models/split_bill_model.dart';
import '../../data/transaction_repository.dart';
import '../../providers/financial_manager_provider.dart';
import '../../providers/split_bill_provider.dart';
import '../../services/split_share_service.dart';
import '../../../settings/providers/settings_provider.dart';
import '../screens/financial_manager_screen.dart';

class SettleUpSheet extends StatefulWidget {
  final String contactName;
  final double netAmount;
  final SplitBillModel? specificBill;
  final SplitParticipantModel? specificParticipant;

  const SettleUpSheet({
    super.key,
    required this.contactName,
    required this.netAmount,
    this.specificBill,
    this.specificParticipant,
  });

  static Future<void> show(
    BuildContext context, {
    required String contactName,
    required double netAmount,
    SplitBillModel? specificBill,
    SplitParticipantModel? specificParticipant,
  }) async {
    await AppBottomSheet.show<void>(
      context: context,
      title: 'Settle Up with $contactName',
      child: SettleUpSheet(
        contactName: contactName,
        netAmount: netAmount,
        specificBill: specificBill,
        specificParticipant: specificParticipant,
      ),
    );
  }

  @override
  State<SettleUpSheet> createState() => _SettleUpSheetState();
}

class _SettleUpSheetState extends State<SettleUpSheet> {
  bool _recordInLedger = true;
  bool _isProcessing = false;
  bool _isSettledSuccess = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = theme.extension<AppSemanticColors>();
    final successColor = semantic?.success ?? colorScheme.primary;
    final debtColor = colorScheme.error;
    final currency = context.select<SettingsProvider, String>((s) => s.currencySymbol);

    final isContactOwingUser = widget.netAmount >= 0;
    final absAmount = widget.netAmount.abs();
    final cardAccentColor = isContactOwingUser ? successColor : debtColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppLayout.spaceM, vertical: AppLayout.spaceS),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            padding: const EdgeInsets.all(AppLayout.spaceL),
            backgroundColor: cardAccentColor.withValues(alpha: 0.12),
            border: BorderSide(
              color: cardAccentColor.withValues(alpha: 0.35),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: cardAccentColor.withValues(alpha: 0.2),
                  child: Icon(
                    isContactOwingUser ? Icons.call_received_rounded : Icons.call_made_rounded,
                    size: 28,
                    color: cardAccentColor,
                  ),
                ),
                const SizedBox(height: AppLayout.spaceM),
                Text(
                  isContactOwingUser
                      ? '${widget.contactName} pays you'
                      : 'You pay ${widget.contactName}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppLayout.spaceXS),
                Text(
                  '$currency ${absAmount.toStringAsFixed(2).replaceAll('.00', '')}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cardAccentColor,
                  ),
                ),
                if (widget.specificBill != null) ...[
                  const SizedBox(height: AppLayout.spaceXS),
                  Text(
                    'For: ${widget.specificBill!.title}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppLayout.spaceM),
          if (widget.specificBill != null &&
              !widget.specificBill!.isPayerUser &&
              widget.specificParticipant != null &&
              widget.specificParticipant!.contactName.trim().toLowerCase() != 'you') ...[
            Container(
              padding: const EdgeInsets.all(AppLayout.spaceS),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppLayout.radiusS),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Settlement between ${widget.contactName} and ${widget.specificBill!.payerName}. Recorded in Split tab only (no personal ledger entry).',
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            CheckboxListTile(
              value: _recordInLedger,
              onChanged: (val) => setState(() => _recordInLedger = val ?? false),
              title: Text(
                isContactOwingUser
                    ? 'Record as Income in Daily Operating Account'
                    : 'Record as Expense in Daily Operating Account',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                isContactOwingUser
                    ? 'Adds a +$currency ${absAmount.toStringAsFixed(2).replaceAll('.00', '')} deposit entry to your ledger'
                    : 'Adds a -$currency ${absAmount.toStringAsFixed(2).replaceAll('.00', '')} payment entry to your ledger',
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ],
          const SizedBox(height: AppLayout.spaceM),
          if (widget.netAmount > 0) ...[
            OutlinedButton.icon(
              onPressed: _isProcessing
                  ? null
                  : () async {
                      final settings = Provider.of<SettingsProvider>(context, listen: false);
                      final splitProvider = Provider.of<SplitBillProvider>(context, listen: false);
                      final String reminder;
                      if (widget.specificBill != null) {
                        reminder = SplitShareService.formatPersonReminder(
                          contactName: widget.contactName,
                          billTitle: widget.specificBill!.title,
                          shareAmount: widget.netAmount,
                          currencySymbol: settings.currencySymbol,
                          defaultPaymentInfo: settings.defaultPaymentInfo,
                        );
                      } else {
                        final openBills = splitProvider.bills.where((b) {
                          if (b.isFullySettled) return false;
                          return b.isPayerUser &&
                              b.participants.any((p) =>
                                  p.contactName.trim().toLowerCase() == widget.contactName.trim().toLowerCase() && !p.hasPaid);
                        }).toList();
                        reminder = SplitShareService.formatPersonPendingStatement(
                          contactName: widget.contactName,
                          openBills: openBills,
                          totalAmount: widget.netAmount,
                          currencySymbol: settings.currencySymbol,
                          defaultPaymentInfo: settings.defaultPaymentInfo,
                        );
                      }
                      await SplitShareService.shareText(reminder, subject: 'Split Bill Reminder');
                    },
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text('Send WhatsApp Reminder'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppLayout.radiusM)),
              ),
            ),
            const SizedBox(height: AppLayout.spaceS),
          ],
          FilledButton.icon(
            onPressed: (_isProcessing || _isSettledSuccess) ? null : _confirmSettleUp,
            icon: _isSettledSuccess
                ? const Icon(Icons.check_circle_rounded, color: Colors.white)
                : _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_rounded),
            label: Text(_isSettledSuccess
                ? 'All Settled Up!'
                : (_isProcessing ? 'Settling...' : 'Confirm Settle Up')),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: _isSettledSuccess ? successColor : null,
              foregroundColor: _isSettledSuccess ? Colors.white : null,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppLayout.radiusM)),
            ),
          ),
          const SizedBox(height: AppLayout.spaceS),
        ],
      ),
    );
  }

  Future<void> _confirmSettleUp() async {
    final splitProvider = Provider.of<SplitBillProvider>(context, listen: false);
    final fmProvider = Provider.of<FinancialManagerProvider>(context, listen: false);
    setState(() => _isProcessing = true);
    AppHaptics.mediumImpact();

    try {
      final isContactOwingUser = widget.netAmount >= 0;
      final absAmount = widget.netAmount.abs();

      // 1. Settle in Split Module
      if (widget.specificParticipant != null) {
        await splitProvider.toggleParticipantPaid(widget.specificParticipant!.id, true);
      } else {
        await splitProvider.settleAllForContact(widget.contactName);
      }

      // 2. Optionally record in Daily Financial Ledger (only if involving user)
      final isFriendSettlingWithFriend = widget.specificBill != null &&
          !widget.specificBill!.isPayerUser &&
          widget.specificParticipant != null &&
          widget.specificParticipant!.contactName.trim().toLowerCase() != 'you';

      int? createdTxId;
      if (!isFriendSettlingWithFriend && _recordInLedger && absAmount > 0 && mounted) {
        final txRepo = TransactionRepository.instance;
        final description = isContactOwingUser
            ? '${widget.contactName} - Split settlement'
            : 'Paid ${widget.contactName} - Split settlement';
        
        final newTx = TransactionModel(
          amount: absAmount,
          description: description,
          date: DateTime.now(),
          isExpense: !isContactOwingUser, // false if income, true if expense
          category: isContactOwingUser ? CategoryConstants.deposit : CategoryConstants.other,
          account: AccountType.daily,
        );

        final createdTx = await txRepo.createTransaction(newTx);
        createdTxId = createdTx.id;
        FinancialManagerScreen.refreshNotifier.value++;

        // Notify Financial Manager Provider if present
        try {
          await fmProvider.loadTransactions();
        } catch (_) {}
      }

      if (mounted) {
        final settings = Provider.of<SettingsProvider?>(context, listen: false);
        final showDelight = settings?.showMilestoneDelight ?? true;

        if (showDelight) {
          setState(() {
            _isProcessing = false;
            _isSettledSuccess = true;
          });
          AppHaptics.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 450));
        }

        if (mounted) {
          Navigator.of(context).pop();
          final messenger = ScaffoldMessenger.of(context);
          messenger.clearSnackBars();
          messenger.showSnackBar(
            SnackBar(
              content: Text('Settled with ${widget.contactName} successfully.'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'UNDO',
              onPressed: () async {
                if (widget.specificParticipant != null) {
                  await splitProvider.toggleParticipantPaid(widget.specificParticipant!.id, false);
                } else {
                  await splitProvider.unsettleAllForContact(widget.contactName);
                }
                if (createdTxId != null) {
                  await TransactionRepository.instance.deleteTransaction(createdTxId);
                }
                FinancialManagerScreen.refreshNotifier.value++;
                try {
                  await fmProvider.loadTransactions();
                } catch (_) {}
              },
            ),
          ),
        );
      }
    }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to settle: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
}

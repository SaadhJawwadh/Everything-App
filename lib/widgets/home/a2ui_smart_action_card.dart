import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/services/app_haptics.dart';
import '../../core/theme/app_layout.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/app_chip.dart';
import '../../data/note_model.dart';
import '../../data/transaction_category.dart';
import '../../data/transaction_model.dart';
import '../../features/finances/data/models/split_bill_model.dart';
import '../../features/finances/data/transaction_repository.dart';
import '../../features/finances/presentation/screens/financial_manager_screen.dart';
import '../../features/finances/presentation/screens/split_bill_editor_screen.dart';
import '../../features/finances/presentation/screens/transaction_editor_screen.dart';
import '../../features/finances/providers/financial_manager_provider.dart';
import '../../features/finances/providers/split_bill_provider.dart';
import '../../features/notes/data/note_repository.dart';
import '../../features/notes/presentation/screens/note_editor_screen.dart';
import '../../features/notes/providers/note_provider.dart';
import '../../features/settings/providers/settings_provider.dart';
import '../../services/local_ai_service.dart';
import '../../services/offline_ai_fallback_service.dart';
import '../../utils/app_constants.dart';
import '../../utils/rich_text_utils.dart';
import '../../utils/widget_helper.dart';
import 'quick_add_todo_sheet.dart';

/// Material 3 Expressive Agent-to-UI (A2UI) Smart Action Card rendered at the top of
/// Universal Search when a user types a natural-language command (e.g. "Spent 450 on coffee",
/// "Todo buy milk", "Split 1200 dinner by 3", "Note flight AB123").
class A2uiSmartActionCard extends StatefulWidget {
  final String query;
  final VoidCallback? onActionExecuted;

  const A2uiSmartActionCard({
    super.key,
    required this.query,
    this.onActionExecuted,
  });

  @override
  State<A2uiSmartActionCard> createState() => _A2uiSmartActionCardState();
}

class _A2uiSmartActionCardState extends State<A2uiSmartActionCard> {
  Map<String, dynamic>? _parsedAction;
  bool _isRefiningWithAi = false;
  bool _isRefinedByAi = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _parseDeterministic();
  }

  @override
  void didUpdateWidget(covariant A2uiSmartActionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _isRefinedByAi = false;
      _isRefiningWithAi = false;
      _parseDeterministic();
    }
  }

  void _parseDeterministic() {
    final categories = TransactionCategory.allNames;
    _parsedAction = OfflineAiFallbackService.parseNaturalLanguageAction(
      widget.query,
      categories,
    );
  }

  Future<void> _refineWithAi() async {
    if (_isRefiningWithAi) return;
    final aiService = Provider.of<LocalAiService>(context, listen: false);
    setState(() => _isRefiningWithAi = true);
    AppHaptics.selectionClick();

    try {
      final categories = TransactionCategory.allNames;
      final refined = await aiService.parseNaturalLanguageAction(
        widget.query,
        categories,
      );
      if (mounted && refined != null) {
        setState(() {
          _parsedAction = refined;
          _isRefinedByAi = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isRefiningWithAi = false);
      }
    }
  }

  void _toggleAccountType() {
    if (_parsedAction == null) return;
    AppHaptics.selectionClick();
    final current = (_parsedAction!['accountType'] as String?) ?? AccountType.daily;
    setState(() {
      _parsedAction = Map<String, dynamic>.from(_parsedAction!)
        ..['accountType'] =
            current == AccountType.daily ? AccountType.savings : AccountType.daily;
    });
  }

  Future<void> _executePrimaryAction(SettingsProvider settings) async {
    final action = _parsedAction;
    if (action == null || _isSaving) return;

    setState(() => _isSaving = true);
    AppHaptics.mediumImpact();

    final messenger = ScaffoldMessenger.of(context);
    final type = action['type'] as String?;

    try {
      if (type == 'transaction') {
        final amount = (action['amount'] as num?)?.toDouble() ?? 0.0;
        final description = (action['description'] as String?) ?? 'Quick Expense';
        final category = (action['category'] as String?) ?? TransactionCategory.other;
        final isExpense = (action['isExpense'] as bool?) ?? true;
        final accountType = (action['accountType'] as String?) ?? AccountType.daily;

        final tx = TransactionModel(
          amount: amount,
          description: description,
          date: DateTime.now(),
          isExpense: isExpense,
          category: category,
          account: accountType,
          isAiRefined: _isRefinedByAi,
        );

        final created = await TransactionRepository.instance.createTransaction(tx);
        if (mounted) {
          final finProvider = Provider.of<FinancialManagerProvider>(context, listen: false);
          unawaited(finProvider.loadTransactions());
          FinancialManagerScreen.refreshNotifier.value++;
        }

        final currencySymbol = AppConstants.getCurrencyInfo(settings.currency).symbol;
        final formattedAmt = '$currencySymbol ${NumberFormat('#,##0.##').format(amount)}';
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              isExpense
                  ? 'Logged expense: $description ($formattedAmt)'
                  : 'Logged income: $description ($formattedAmt)',
            ),
            action: created.id != null
                ? SnackBarAction(
                    label: 'Undo',
                    onPressed: () async {
                      await TransactionRepository.instance.deleteTransaction(created.id!);
                      FinancialManagerScreen.refreshNotifier.value++;
                    },
                  )
                : null,
          ),
        );
        widget.onActionExecuted?.call();
      } else if (type == 'todo') {
        final taskText = (action['taskText'] as String?) ?? '';
        final noteProvider = Provider.of<NoteProvider>(context, listen: false);
        final savedNote = await WidgetHelper.quickAddTask(taskText: taskText);
        if (mounted) {
          unawaited(noteProvider.refreshNotes());
        }
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Added to checklist: $taskText'),
            action: savedNote != null
                ? SnackBarAction(
                    label: 'Open',
                    onPressed: () {
                      if (!mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NoteEditorScreen(note: savedNote),
                        ),
                      );
                    },
                  )
                : null,
          ),
        );
        widget.onActionExecuted?.call();
      } else if (type == 'note') {
        final title = (action['title'] as String?) ?? 'Quick Note';
        final content = (action['content'] as String?) ?? '';
        final noteProvider = Provider.of<NoteProvider>(context, listen: false);
        final now = DateTime.now();
        final selectedFolder = noteProvider.selectedFolder;
        final newNote = Note(
          id: const Uuid().v4(),
          title: title,
          content: RichTextUtils.deltaToJson(
            RichTextUtils.markdownToDelta(content),
          ),
          dateCreated: now,
          dateModified: now,
          category: (selectedFolder == null || selectedFolder == 'All Notes')
              ? 'Notes'
              : selectedFolder,
        );
        await NoteRepository.instance.createNote(newNote);
        if (mounted) {
          unawaited(noteProvider.refreshNotes());
        }
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Saved note: $title'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await NoteRepository.instance.deleteNote(newNote.id);
                await noteProvider.refreshNotes();
              },
            ),
          ),
        );
        widget.onActionExecuted?.call();
      } else if (type == 'split_bill') {
        final amount = (action['amount'] as num?)?.toDouble() ?? 0.0;
        final title = (action['title'] as String?) ?? 'Group Expense';
        final count = (action['participantCount'] as int?) ?? 2;
        final share = double.parse((amount / count).toStringAsFixed(2));
        final billId = const Uuid().v4();

        final tx = await TransactionRepository.instance.createTransaction(
          TransactionModel(
            amount: amount,
            description: '$title (Split Bill)',
            date: DateTime.now(),
            isExpense: true,
            category: TransactionCategory.fromDescriptionCached(title),
            account: AccountType.daily,
          ),
        );

        final participants = <SplitParticipantModel>[
          SplitParticipantModel(
            id: const Uuid().v4(),
            billId: billId,
            contactName: 'You',
            shareAmount: share,
            hasPaid: true,
            paidAt: DateTime.now(),
          ),
          for (int i = 1; i < count; i++)
            SplitParticipantModel(
              id: const Uuid().v4(),
              billId: billId,
              contactName: count == 2 ? 'Friend' : 'Friend $i',
              shareAmount: share,
              hasPaid: false,
            ),
        ];

        final bill = SplitBillModel(
          id: billId,
          transactionId: tx.id,
          title: title,
          totalAmount: amount,
          payerName: 'You',
          isPayerUser: true,
          splitMode: SplitMode.equal,
          date: DateTime.now(),
          status: SplitStatus.unsettled,
          participants: participants,
        );

        if (mounted) {
          final splitProvider = Provider.of<SplitBillProvider>(context, listen: false);
          final finProvider = Provider.of<FinancialManagerProvider>(context, listen: false);
          await splitProvider.createBill(bill);
          unawaited(finProvider.loadTransactions());
          FinancialManagerScreen.refreshNotifier.value++;
        }

        final currencySymbol = AppConstants.getCurrencyInfo(settings.currency).symbol;
        final formattedShare = '$currencySymbol ${NumberFormat('#,##0.##').format(share)}';
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Created split: $title ($formattedShare / person)'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                if (mounted) {
                  await Provider.of<SplitBillProvider>(context, listen: false)
                      .deleteBill(billId);
                }
                if (tx.id != null) {
                  await TransactionRepository.instance.deleteTransaction(tx.id!);
                }
                FinancialManagerScreen.refreshNotifier.value++;
              },
            ),
          ),
        );
        widget.onActionExecuted?.call();
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _openEditor(SettingsProvider settings) async {
    final action = _parsedAction;
    if (action == null) return;
    AppHaptics.selectionClick();

    final type = action['type'] as String?;
    if (type == 'transaction') {
      final amount = (action['amount'] as num?)?.toDouble() ?? 0.0;
      final description = (action['description'] as String?) ?? '';
      final category = (action['category'] as String?) ?? TransactionCategory.other;
      final isExpense = (action['isExpense'] as bool?) ?? true;
      final accountType = (action['accountType'] as String?) ?? AccountType.daily;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TransactionEditorScreen(
            transaction: TransactionModel(
              amount: amount,
              description: description,
              date: DateTime.now(),
              isExpense: isExpense,
              category: category,
              account: accountType,
            ),
          ),
        ),
      );
    } else if (type == 'split_bill') {
      final amount = (action['amount'] as num?)?.toDouble() ?? 0.0;
      final title = (action['title'] as String?) ?? 'Group Expense';
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SplitBillEditorScreen(
            initialTitle: title,
            initialAmount: amount,
            initialDate: DateTime.now(),
          ),
        ),
      );
    } else if (type == 'todo') {
      await QuickAddTodoSheet.show(context, 'ALL_NOTES');
    } else if (type == 'note') {
      final content = (action['content'] as String?) ?? '';
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NoteEditorScreen(
            initialSharedText: content,
            initialFolder: noteProvider.selectedFolder,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final action = _parsedAction;
    if (action == null) return const SizedBox.shrink();

    final type = action['type'] as String?;
    if (type == 'transaction' && !settings.showFinancialManager) {
      return const SizedBox.shrink();
    }
    if (type == 'split_bill' &&
        (!settings.showFinancialManager || !settings.showSplitBills)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final currencySymbol = AppConstants.getCurrencyInfo(settings.currency).symbol;

    late final IconData leadingIcon;
    late final Color accentColor;
    late final String badgeLabel;
    late final String headlineText;
    late final String subtitleText;
    late final String primaryButtonLabel;

    if (type == 'transaction') {
      final amount = (action['amount'] as num?)?.toDouble() ?? 0.0;
      final description = (action['description'] as String?) ?? 'Quick Expense';
      final category = (action['category'] as String?) ?? TransactionCategory.other;
      final isExpense = (action['isExpense'] as bool?) ?? true;
      final accountType = (action['accountType'] as String?) ?? AccountType.daily;

      leadingIcon = TransactionCategory.iconFor(category);
      accentColor = TransactionCategory.colorFor(category);
      badgeLabel = isExpense ? 'Instant Expense' : 'Instant Income';
      headlineText =
          '$description • $currencySymbol ${NumberFormat('#,##0.##').format(amount)}';
      subtitleText =
          '$category • ${accountType == AccountType.savings ? 'Savings Vault' : 'Daily Operating'}';
      primaryButtonLabel = isExpense ? 'Log Expense' : 'Log Income';
    } else if (type == 'split_bill') {
      final amount = (action['amount'] as num?)?.toDouble() ?? 0.0;
      final title = (action['title'] as String?) ?? 'Group Expense';
      final count = (action['participantCount'] as int?) ?? 2;
      final share = amount / count;

      leadingIcon = Icons.call_split_rounded;
      accentColor = colorScheme.tertiary;
      badgeLabel = 'Instant Split Bill';
      headlineText =
          '$title • $currencySymbol ${NumberFormat('#,##0.##').format(amount)}';
      subtitleText =
          '$count people • $currencySymbol ${NumberFormat('#,##0.##').format(share)} / person';
      primaryButtonLabel = 'Create Split';
    } else if (type == 'todo') {
      final taskText = (action['taskText'] as String?) ?? '';
      leadingIcon = Icons.task_alt_rounded;
      accentColor = colorScheme.primary;
      badgeLabel = 'Instant Checklist Task';
      headlineText = taskText;
      subtitleText = 'Appends to your active pinned checklist note';
      primaryButtonLabel = 'Add Task';
    } else {
      final title = (action['title'] as String?) ?? 'Quick Note';
      final content = (action['content'] as String?) ?? '';
      leadingIcon = Icons.note_add_outlined;
      accentColor = colorScheme.secondary;
      badgeLabel = 'Instant Note';
      headlineText = title;
      subtitleText = content;
      primaryButtonLabel = 'Save Note';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppLayout.spaceM),
      child: AppCard.tonal(
        key: const ValueKey('a2ui_smart_action_card'),
        color: colorScheme.primaryContainer.withValues(alpha: isDark ? 0.22 : 0.50),
        borderColor: colorScheme.primary.withValues(alpha: 0.32),
        borderRadius: AppLayout.radiusL,
        padding: const EdgeInsets.all(AppLayout.spaceM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: isDark ? 0.25 : 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    leadingIcon,
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppLayout.spaceM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bolt_rounded,
                            size: 14,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            badgeLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          if (_isRefinedByAi) ...[
                            const SizedBox(width: AppLayout.spaceXS),
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 13,
                              color: colorScheme.tertiary,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        headlineText,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitleText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (settings.isAiActive && !_isRefinedByAi)
                  Semantics(
                    button: true,
                    label: 'AI Refine action details',
                    child: Padding(
                      padding: const EdgeInsets.only(left: AppLayout.spaceXS),
                      child: AppChip(
                        label: _isRefiningWithAi ? 'Refining...' : 'AI Refine',
                        icon: Icons.auto_awesome_rounded,
                        isCompact: true,
                        onTap: _isRefiningWithAi ? null : _refineWithAi,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppLayout.spaceM),
            Wrap(
              spacing: AppLayout.spaceS,
              runSpacing: AppLayout.spaceXS,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Semantics(
                  button: true,
                  label: primaryButtonLabel,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: FilledButton.icon(
                      key: const ValueKey('a2ui_primary_action_button'),
                      onPressed: _isSaving ? null : () => _executePrimaryAction(settings),
                      icon: const Icon(Icons.add_task_rounded, size: 18),
                      label: Text(primaryButtonLabel),
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Edit before saving',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: OutlinedButton.icon(
                      key: const ValueKey('a2ui_edit_action_button'),
                      onPressed: () => _openEditor(settings),
                      icon: const Icon(Icons.tune_rounded, size: 17),
                      label: const Text('Edit'),
                    ),
                  ),
                ),
                if (type == 'transaction')
                  Semantics(
                    button: true,
                    label: 'Switch account type',
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Center(
                        widthFactor: 1.0,
                        child: AppChip(
                          key: const ValueKey('a2ui_account_toggle_chip'),
                          label: (action['accountType'] == AccountType.savings)
                              ? 'Savings Vault'
                              : 'Daily Account',
                          icon: (action['accountType'] == AccountType.savings)
                              ? Icons.savings_outlined
                              : Icons.account_balance_wallet_outlined,
                          isSelected: action['accountType'] == AccountType.savings,
                          onTap: _toggleAccountType,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

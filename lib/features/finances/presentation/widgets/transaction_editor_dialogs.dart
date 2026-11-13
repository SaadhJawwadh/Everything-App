import 'package:flutter/material.dart';

import 'package:note_taking_app/core/services/app_haptics.dart';
import 'package:note_taking_app/core/theme/app_layout.dart';
import 'package:note_taking_app/data/category_definition.dart';
import 'package:note_taking_app/data/transaction_category.dart';

/// Reusable dialogs extracted from [TransactionEditorScreen].
class TransactionEditorDialogs {
  TransactionEditorDialogs._();

  static const _colorSwatches = [
    Color(0xFFE06D53), // Coral Dusk
    Color(0xFFD9779B), // Soft Rose
    Color(0xFF9E7BB5), // Lavender Dusk
    Color(0xFF6A7EC0), // Indigo Dusk
    Color(0xFF5194B6), // Sky Blue
    Color(0xFF4E9F90), // Sage Teal
    Color(0xFF5A9E75), // Emerald
    Color(0xFF86A148), // Olive Green
    Color(0xFFD49339), // Amber Harvest
    Color(0xFFC86F4B), // Terracotta
    Color(0xFF917265), // Warm Brown
    Color(0xFF758596), // Slate Blue
  ];

  static final _leadingActionPrefixRegex = RegExp(
    r'(?:Debit|Credit|Payment at|Purchase at|Transfer to)\s*',
    caseSensitive: false,
  );

  /// Prompts the user to discard, keep editing, or save unsaved changes.
  static Future<String?> showDiscardConfirmation(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppLayout.radiusL),
        ),
        title: Text(
          'Unsaved Changes',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'You have unsaved changes to this transaction. Do you want to save them before leaving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('discard'),
            style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('keep'),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Prompts to move a transaction to Trash, with optional SMS sender blocking.
  static Future<({bool confirmed, bool blockSender})> showDeleteConfirmation(
    BuildContext context, {
    required bool isSmsTxn,
  }) async {
    var blockSender = false;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final cs = Theme.of(context).colorScheme;
          final tt = Theme.of(context).textTheme;

          return AlertDialog(
            title: const Text('Delete Transaction?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Move this transaction to Trash? You can restore it anytime within 30 days.',
                ),
                if (isSmsTxn) ...[
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppLayout.radiusM),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: CheckboxListTile(
                      value: blockSender,
                      onChanged: (val) =>
                          setDialogState(() => blockSender = val ?? false),
                      title: Text(
                        'Block future SMS imports for this source',
                        style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Prevent incoming SMS from this sender from being added to your ledger.',
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: cs.error,
                  foregroundColor: cs.onError,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      ),
    );
    return (confirmed: confirm == true, blockSender: blockSender);
  }

  /// Prompts to teach the SMS parser an expense/income keyword rule.
  static Future<String?> showTrainingDialog(
    BuildContext context,
    String initialKeyword,
  ) {
    return _showKeywordTrainingDialog(
      context,
      initialKeyword: initialKeyword,
      title: 'Train SMS Parser?',
      description:
          'Would you like the app to remember this? Future SMS messages containing the keyword below will automatically be marked as exactly what you selected.',
      hintText: 'e.g., Uber, Keells, Salary',
      confirmLabel: 'Train Parser',
    );
  }

  /// Prompts to teach the SMS parser a category keyword rule.
  static Future<String?> showCategoryTrainingDialog(
    BuildContext context,
    String initialKeyword,
    String category,
  ) {
    return _showKeywordTrainingDialog(
      context,
      initialKeyword: initialKeyword,
      title: 'Train Category Parser?',
      description:
          'Would you like the app to remember this? Future SMS messages containing the keyword below will automatically be categorized as "$category".',
      hintText: 'e.g., Uber, Keells, Mc',
      confirmLabel: 'Train Category',
    );
  }

  static Future<String?> _showKeywordTrainingDialog(
    BuildContext context, {
    required String initialKeyword,
    required String title,
    required String description,
    required String hintText,
    required String confirmLabel,
  }) {
    final keyword =
        initialKeyword.replaceAll(_leadingActionPrefixRegex, '').trim();
    return showDialog<String>(
      context: context,
      builder: (context) {
        var input = keyword;
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(description),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: keyword,
                decoration: InputDecoration(
                  labelText: 'Matching Keyword/Phrase',
                  border: const OutlineInputBorder(),
                  hintText: hintText,
                ),
                onChanged: (v) => input = v.trim(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('No, just this once'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, input),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
  }

  /// Prompts to create a new custom transaction category.
  static Future<CategoryDefinition?> showNewCategoryDialog(
    BuildContext context,
  ) async {
    var name = '';
    var selectedColor = _colorSwatches[5];
    var selectedIcon = TransactionCategory.swatches[0];

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('New Category'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Category name',
                          hintText: 'e.g., Groceries',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => name = v.trim(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Icon',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 120,
                        child: GridView.builder(
                          shrinkWrap: true,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 6,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                          itemCount: TransactionCategory.swatches.length,
                          itemBuilder: (context, idx) {
                            final icon = TransactionCategory.swatches[idx];
                            final isSelected =
                                selectedIcon.codePoint == icon.codePoint;
                            return GestureDetector(
                              onTap: () {
                                AppHaptics.selectionClick();
                                setDialogState(() => selectedIcon = icon);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? selectedColor.withValues(alpha: 0.2)
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(
                                          color: selectedColor,
                                          width: 2,
                                        )
                                      : null,
                                ),
                                child: Icon(
                                  icon,
                                  size: 20,
                                  color: isSelected
                                      ? selectedColor
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Color',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _colorSwatches.map((c) {
                          final isSelected =
                              c.toARGB32() == selectedColor.toARGB32();
                          return Semantics(
                            button: true,
                            label: 'Color option',
                            selected: isSelected,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(
                                AppLayout.radiusStadium,
                              ),
                              onTap: () =>
                                  setDialogState(() => selectedColor = c),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                child: Center(
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: c,
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            size: 16,
                                            color: Colors.white,
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (name.isEmpty) return;
                    Navigator.pop(context, true);
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (created != true || name.isEmpty) return null;
    return CategoryDefinition(
      name: name,
      colorValue: selectedColor.toARGB32(),
      keywords: [],
      iconCodePoint: selectedIcon.codePoint,
    );
  }
}

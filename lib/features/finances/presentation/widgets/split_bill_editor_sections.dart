import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/app_card.dart';
import '../../../../data/transaction_category.dart';
import '../../data/models/split_bill_model.dart';

/// Card for editing bill title, total amount, date, and category in [SplitBillEditorScreen].
class SplitBillDetailsCard extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController amountController;
  final String currencySymbol;
  final DateTime selectedDate;
  final String selectedCategory;
  final VoidCallback onAmountChanged;
  final VoidCallback onOpenCalculator;
  final VoidCallback onSelectDate;
  final ValueChanged<String> onCategorySelected;

  const SplitBillDetailsCard({
    super.key,
    required this.titleController,
    required this.amountController,
    required this.currencySymbol,
    required this.selectedDate,
    required this.selectedCategory,
    required this.onAmountChanged,
    required this.onOpenCalculator,
    required this.onSelectDate,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(AppLayout.spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: titleController,
            textCapitalization: TextCapitalization.sentences,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              labelText: 'Bill / Event Title',
              hintText: 'e.g. Dinner at Botanik, Uber Ride, Starlink',
              prefixIcon: Icon(Icons.receipt_long_rounded),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppLayout.spaceM),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Total Bill Amount ($currencySymbol)',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Center(
                        widthFactor: 0.0,
                        child: Text(
                          currencySymbol,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => onAmountChanged(),
                ),
              ),
              const SizedBox(width: AppLayout.spaceS),
              IconButton.filledTonal(
                icon: const Icon(Icons.calculate_rounded),
                tooltip: 'Calculator',
                onPressed: onOpenCalculator,
              ),
            ],
          ),
          const SizedBox(height: AppLayout.spaceM),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSelectDate,
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: Text(DateFormat('MMM d, yyyy').format(selectedDate)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppLayout.spaceM),
          Text(
            'Category',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppLayout.spaceS),
          Wrap(
            spacing: AppLayout.spaceS,
            runSpacing: AppLayout.spaceXS,
            children: TransactionCategory.allNames.map((cat) {
              final catColor = TransactionCategory.colorFor(cat);
              final catIcon = TransactionCategory.iconFor(cat);
              final isSelected = selectedCategory == cat;
              return FilterChip(
                showCheckmark: false,
                avatar: Icon(
                  catIcon,
                  size: 16,
                  color: isSelected ? catColor : colorScheme.onSurfaceVariant,
                ),
                label: Text(cat),
                selected: isSelected,
                onSelected: (_) {
                  AppHaptics.selectionClick();
                  onCategorySelected(cat);
                },
                selectedColor: catColor.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: isSelected ? catColor : colorScheme.onSurfaceVariant,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                side: BorderSide(
                  color: isSelected
                      ? catColor
                      : colorScheme.outline.withValues(alpha: 0.5),
                  width: isSelected ? 1.5 : 0.5,
                ),
                shape: const StadiumBorder(),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Card for selecting who paid and the bill splitting mode in [SplitBillEditorScreen].
class SplitBillPayerCard extends StatelessWidget {
  final bool isPayerUser;
  final bool includeUserShare;
  final SplitMode splitMode;
  final TextEditingController payerFriendController;
  final List<Map<String, dynamic>> participantsData;
  final List<SplitContactModel> recentContacts;
  final ValueChanged<bool> onPayerTypeChanged;
  final VoidCallback onFriendNameChanged;
  final ValueChanged<String> onFriendNameSubmitted;
  final void Function(bool selected, String name) onQuickSelectPayer;
  final ValueChanged<bool> onIncludeUserShareChanged;
  final ValueChanged<SplitMode> onSplitModeChanged;

  const SplitBillPayerCard({
    super.key,
    required this.isPayerUser,
    required this.includeUserShare,
    required this.splitMode,
    required this.payerFriendController,
    required this.participantsData,
    required this.recentContacts,
    required this.onPayerTypeChanged,
    required this.onFriendNameChanged,
    required this.onFriendNameSubmitted,
    required this.onQuickSelectPayer,
    required this.onIncludeUserShareChanged,
    required this.onSplitModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(AppLayout.spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Who Paid for this Bill?',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppLayout.spaceS),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<bool>(
                value: true,
                label: Text('I Paid for All'),
                icon: Icon(Icons.person_rounded, size: 18),
              ),
              ButtonSegment<bool>(
                value: false,
                label: Text('Friend Paid'),
                icon: Icon(Icons.group_rounded, size: 18),
              ),
            ],
            selected: {isPayerUser},
            onSelectionChanged: (set) {
              AppHaptics.selectionClick();
              onPayerTypeChanged(set.first);
            },
          ),
          if (!isPayerUser) ...[
            const SizedBox(height: AppLayout.spaceM),
            TextField(
              controller: payerFriendController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Friend Who Paid',
                hintText: 'e.g. Alex, Sarah',
                prefixIcon: Icon(Icons.account_circle_rounded),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => onFriendNameChanged(),
              onSubmitted: onFriendNameSubmitted,
            ),
            Builder(
              builder: (context) {
                final suggestions = <String>{};
                for (final p in participantsData) {
                  final name = p['name'] as String;
                  if (name.isNotEmpty) suggestions.add(name);
                }
                for (final c in recentContacts) {
                  if (c.name.isNotEmpty) suggestions.add(c.name);
                }
                if (suggestions.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: AppLayout.spaceS),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Select Payer:',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppLayout.spaceXS),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 110),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: AppLayout.spaceXS,
                            runSpacing: AppLayout.spaceXS,
                            children: suggestions.map((name) {
                              final isPayer = payerFriendController.text
                                      .trim()
                                      .toLowerCase() ==
                                  name.toLowerCase();
                              return ChoiceChip(
                                showCheckmark: false,
                                label: Text(name),
                                selected: isPayer,
                                onSelected: (sel) {
                                  AppHaptics.selectionClick();
                                  onQuickSelectPayer(sel, name);
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: AppLayout.spaceM),
          SwitchListTile(
            value: includeUserShare,
            onChanged: !isPayerUser ? null : onIncludeUserShareChanged,
            title: const Text('Include My Personal Share'),
            subtitle: Text(
              !isPayerUser
                  ? 'Locked: your share is required because a friend paid for you'
                  : (includeUserShare
                      ? 'Your share is calculated and subtracted from what others owe'
                      : 'You paid 100% purely on behalf of others'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          const SizedBox(height: AppLayout.spaceM),
          Text(
            'Splitting Method',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppLayout.spaceS),
          SegmentedButton<SplitMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<SplitMode>(
                value: SplitMode.equal,
                label: Text('Equal Split'),
                icon: Icon(Icons.safety_divider_rounded, size: 18),
              ),
              ButtonSegment<SplitMode>(
                value: SplitMode.exact,
                label: Text('Custom Exact'),
                icon: Icon(Icons.tune_rounded, size: 18),
              ),
            ],
            selected: {splitMode},
            onSelectionChanged: (set) {
              AppHaptics.selectionClick();
              onSplitModeChanged(set.first);
            },
          ),
        ],
      ),
    );
  }
}

/// Card managing split bill participants and exact share inputs in [SplitBillEditorScreen].
class SplitBillParticipantsCard extends StatelessWidget {
  final String currency;
  final int totalSplitCount;
  final SplitMode splitMode;
  final double totalAmount;
  final double equalShareAmount;
  final double remainingToAllocate;
  final bool isPayerUser;
  final bool includeUserShare;
  final String payerFriendName;
  final List<SplitContactModel> recentContacts;
  final List<Map<String, dynamic>> participantsData;
  final Map<String, TextEditingController> exactAmountControllers;
  final TextEditingController newParticipantController;
  final FocusNode newParticipantFocusNode;
  final TextEditingController userExactAmountController;
  final VoidCallback onAssignEqualCustomShares;
  final VoidCallback onShowTaxTipAllocator;
  final VoidCallback onDistributeRemainder;
  final ValueChanged<String> onAddParticipant;
  final ValueChanged<int> onRemoveParticipant;
  final ValueChanged<TextEditingController?> onOpenCalculator;
  final VoidCallback onAmountChanged;

  const SplitBillParticipantsCard({
    super.key,
    required this.currency,
    required this.totalSplitCount,
    required this.splitMode,
    required this.totalAmount,
    required this.equalShareAmount,
    required this.remainingToAllocate,
    required this.isPayerUser,
    required this.includeUserShare,
    required this.payerFriendName,
    required this.recentContacts,
    required this.participantsData,
    required this.exactAmountControllers,
    required this.newParticipantController,
    required this.newParticipantFocusNode,
    required this.userExactAmountController,
    required this.onAssignEqualCustomShares,
    required this.onShowTaxTipAllocator,
    required this.onDistributeRemainder,
    required this.onAddParticipant,
    required this.onRemoveParticipant,
    required this.onOpenCalculator,
    required this.onAmountChanged,
  });

  InputDecoration _exactShareDecoration(
    ColorScheme colorScheme, {
    String? hintText,
    Widget? suffixIcon,
    EdgeInsetsGeometry contentPadding =
        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  }) {
    final enabledBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppLayout.radiusS),
      borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.3)),
    );
    return InputDecoration(
      hintText: hintText,
      isDense: true,
      prefixText: '$currency ',
      prefixStyle: TextStyle(
        color: colorScheme.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      suffixIcon: suffixIcon,
      suffixIconConstraints: suffixIcon != null
          ? const BoxConstraints(minWidth: 48, minHeight: 48)
          : null,
      contentPadding: contentPadding,
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      border: enabledBorder,
      enabledBorder: enabledBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppLayout.radiusS),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(AppLayout.spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Participants ($totalSplitCount)',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (splitMode == SplitMode.equal &&
                  totalSplitCount > 0 &&
                  totalAmount > 0)
                Text(
                  '$currency ${equalShareAmount.toStringAsFixed(2)} / person',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          if (splitMode == SplitMode.exact) ...[
            const SizedBox(height: AppLayout.spaceS),
            Wrap(
              spacing: AppLayout.spaceS,
              runSpacing: AppLayout.spaceXS,
              children: [
                ActionChip(
                  avatar: Icon(
                    Icons.safety_divider_rounded,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  label: const Text('Split Equally'),
                  tooltip:
                      'Assign total bill amount equally among all people with penny-perfect precision',
                  onPressed: () {
                    AppHaptics.selectionClick();
                    onAssignEqualCustomShares();
                  },
                ),
                ActionChip(
                  avatar: Icon(
                    Icons.calculate_outlined,
                    size: 16,
                    color: colorScheme.primary,
                  ),
                  label: const Text('Add Tax / Tip / Fee'),
                  tooltip: 'Distribute tax, tip, or service charge proportionally',
                  onPressed: onShowTaxTipAllocator,
                ),
                if (remainingToAllocate.abs() > 0.009)
                  ActionChip(
                    avatar: Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: colorScheme.tertiary,
                    ),
                    label: Text(
                      remainingToAllocate > 0
                          ? 'Fill Remainder ($currency ${remainingToAllocate.toStringAsFixed(2)})'
                          : 'Reconcile Balance',
                    ),
                    tooltip: 'Automatically balance remaining amount',
                    onPressed: onDistributeRemainder,
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppLayout.spaceS),
          if (recentContacts.isNotEmpty) ...[
            Text(
              'Quick Add Recent Friends:',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppLayout.spaceXS),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 110),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: AppLayout.spaceXS,
                  runSpacing: AppLayout.spaceXS,
                  children: recentContacts.map((c) {
                    final isAdded = participantsData.any(
                      (p) =>
                          (p['name'] as String).toLowerCase() ==
                          c.name.toLowerCase(),
                    );
                    if (isAdded) return const SizedBox.shrink();
                    return ActionChip(
                      avatar: CircleAvatar(
                        radius: 10,
                        backgroundColor: Color(c.colorValue),
                        child: Text(
                          c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      label: Text(c.name),
                      onPressed: () => onAddParticipant(c.name),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: AppLayout.spaceM),
          ],
          Row(
            children: [
              Expanded(
                child: RawAutocomplete<String>(
                  textEditingController: newParticipantController,
                  focusNode: newParticipantFocusNode,
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.trim().isEmpty) {
                      return const Iterable<String>.empty();
                    }
                    final query = textEditingValue.text.trim().toLowerCase();
                    return recentContacts.map((c) => c.name).where(
                          (name) =>
                              name.toLowerCase().contains(query) &&
                              !participantsData.any(
                                (p) =>
                                    p['name'].toString().toLowerCase() ==
                                    name.toLowerCase(),
                              ),
                        );
                  },
                  onSelected: onAddParticipant,
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Enter friend name...',
                        prefixIcon: Icon(Icons.person_add_rounded),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: onAddParticipant,
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4.0,
                        borderRadius: BorderRadius.circular(AppLayout.radiusM),
                        color: colorScheme.surfaceContainerHigh,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 180,
                            maxWidth: 300,
                          ),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (BuildContext context, int index) {
                              final option = options.elementAt(index);
                              return ListTile(
                                dense: true,
                                leading: const Icon(
                                  Icons.person_outline_rounded,
                                  size: 18,
                                ),
                                title: Text(option),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: AppLayout.spaceS),
              IconButton.filled(
                icon: const Icon(Icons.add_rounded),
                tooltip: 'Add Person',
                onPressed: () => onAddParticipant(newParticipantController.text),
              ),
            ],
          ),
          const SizedBox(height: AppLayout.spaceM),
          if (includeUserShare) ...[
            ListTile(
              leading: CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: Text(
                  'You',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: const Text(
                'You (Your Share)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle:
                  Text(isPayerUser ? 'Payer • Already paid' : 'Owed to friend'),
              trailing: splitMode == SplitMode.equal
                  ? Text(
                      '$currency ${equalShareAmount.toStringAsFixed(2)}',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    )
                  : SizedBox(
                      width: 130,
                      child: TextField(
                        controller: userExactAmountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        decoration: _exactShareDecoration(
                          colorScheme,
                          hintText: remainingToAllocate > 0
                              ? remainingToAllocate.toStringAsFixed(2)
                              : '0.00',
                        ),
                        onChanged: (_) => onAmountChanged(),
                      ),
                    ),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: AppLayout.spaceS),
          ],
          if (participantsData.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppLayout.spaceL),
              child: Center(
                child: Text(
                  'Add at least one friend to split this bill.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: participantsData.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppLayout.spaceXS),
              itemBuilder: (context, index) {
                final p = participantsData[index];
                final name = p['name'] as String;
                final ctrl = exactAmountControllers[name];

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.secondaryContainer,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: (!isPayerUser &&
                          payerFriendName.trim().toLowerCase() ==
                              name.toLowerCase())
                      ? Text(
                          'Payer • Settled',
                          style: TextStyle(
                            color: theme.extension<AppSemanticColors>()?.success ??
                                colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (splitMode == SplitMode.equal)
                        Text(
                          '$currency ${equalShareAmount.toStringAsFixed(2)}',
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        )
                      else
                        SizedBox(
                          width: 148,
                          child: TextField(
                            controller: ctrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            decoration: _exactShareDecoration(
                              colorScheme,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(
                                  Icons.calculate_outlined,
                                  size: 18,
                                ),
                                tooltip: 'Calculate share',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                onPressed: ctrl != null
                                    ? () => onOpenCalculator(ctrl)
                                    : null,
                              ),
                            ),
                            onChanged: (_) => onAmountChanged(),
                          ),
                        ),
                      const SizedBox(width: AppLayout.spaceS),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        tooltip: 'Remove',
                        onPressed: () => onRemoveParticipant(index),
                      ),
                    ],
                  ),
                  contentPadding: EdgeInsets.zero,
                );
              },
            ),
        ],
      ),
    );
  }
}

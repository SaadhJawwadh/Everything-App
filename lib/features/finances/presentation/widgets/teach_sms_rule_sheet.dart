import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_bottom_sheet.dart';
import '../../../../data/custom_sms_rule.dart';
import '../../../../data/transaction_category.dart';
import '../../../settings/providers/settings_provider.dart';

class TeachSmsRuleSheet extends StatefulWidget {
  final CustomSmsRule? existingRule;
  final String? sampleSmsBody;

  const TeachSmsRuleSheet({
    super.key,
    this.existingRule,
    this.sampleSmsBody,
  });

  static Future<CustomSmsRule?> show({
    required BuildContext context,
    CustomSmsRule? existingRule,
    String? sampleSmsBody,
  }) {
    return AppBottomSheet.show<CustomSmsRule>(
      context: context,
      title: existingRule != null ? 'Edit SMS Rule' : 'Teach Custom SMS Rule',
      child: TeachSmsRuleSheet(
        existingRule: existingRule,
        sampleSmsBody: sampleSmsBody,
      ),
    );
  }

  @override
  State<TeachSmsRuleSheet> createState() => _TeachSmsRuleSheetState();
}

class _TeachSmsRuleSheetState extends State<TeachSmsRuleSheet> {
  late final TextEditingController _keywordController;
  late final TextEditingController _descriptionController;
  late RuleTransactionType _selectedType;
  String? _selectedCategory;
  String? _targetAccount;
  late bool _bypassOtpFilter;
  List<String> _suggestedTokens = [];

  @override
  void initState() {
    super.initState();
    final rule = widget.existingRule;
    _keywordController = TextEditingController(text: rule?.keyword ?? '');
    _descriptionController = TextEditingController(text: rule?.customDescription ?? '');
    _selectedType = rule?.type ?? RuleTransactionType.expense;
    _selectedCategory = rule?.category;
    _targetAccount = rule?.targetAccount;
    _bypassOtpFilter = rule?.bypassOtpFilter ?? false;

    _extractSuggestedTokens();
  }

  void _extractSuggestedTokens() {
    final sample = widget.sampleSmsBody?.trim();
    if (sample == null || sample.isEmpty) return;

    final tokens = <String>{};

    // Extract multi-word patterns
    final matches = RegExp(r'\b[A-Za-z0-9\-_]{3,20}\b').allMatches(sample);
    final words = matches.map((m) => m.group(0)!).toList();

    // Specific bank/transfer compound patterns
    if (sample.toLowerCase().contains('digital-transfer')) {
      tokens.add('Digital-Transfer');
    }
    if (sample.toLowerCase().contains('transfer within')) {
      tokens.add('Transfer within');
    }
    if (sample.toLowerCase().contains('attempted')) {
      tokens.add('attempted');
    }

    for (final w in words) {
      final lower = w.toLowerCase();
      if (!['the', 'and', 'for', 'with', 'your', 'please', 'this', 'that', 'from', 'lkr', 'usd', 'eur', 'code', 'anyone'].contains(lower)) {
        if (w.length >= 4) {
          tokens.add(w);
        }
      }
    }

    _suggestedTokens = tokens.take(8).toList();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter or select a trigger keyword.')),
      );
      return;
    }

    final customDesc = _descriptionController.text.trim();
    final rule = CustomSmsRule(
      id: widget.existingRule?.id ?? 'rule_${DateTime.now().millisecondsSinceEpoch}',
      keyword: keyword,
      type: _selectedType,
      category: _selectedCategory,
      customDescription: customDesc.isNotEmpty ? customDesc : null,
      targetAccount: _targetAccount,
      bypassOtpFilter: _bypassOtpFilter,
      isEnabled: widget.existingRule?.isEnabled ?? true,
      createdAt: widget.existingRule?.createdAt ?? DateTime.now(),
    );

    context.read<SettingsProvider>().saveCustomSmsRule(rule);
    AppHaptics.mediumImpact();
    Navigator.of(context).pop(rule);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: AppLayout.spaceL,
        right: AppLayout.spaceL,
        top: AppLayout.spaceS,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppLayout.spaceXL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Teach the app how to recognize and classify this SMS format automatically in the future.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppLayout.spaceL),

          // Trigger Keyword Input
          Text('Trigger Keyword or Phrase', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppLayout.spaceS),
          TextField(
            controller: _keywordController,
            decoration: InputDecoration(
              hintText: 'e.g. Digital-Transfer, Salary Deposit, Keells',
              prefixIcon: const Icon(Icons.key_rounded),
              suffixIcon: _keywordController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        setState(() {
                          _keywordController.clear();
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: cs.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),

          // Suggested Token Chips
          if (_suggestedTokens.isNotEmpty) ...[
            const SizedBox(height: AppLayout.spaceS),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _suggestedTokens.map((token) {
                final isSelected = _keywordController.text.trim().toLowerCase() == token.toLowerCase();
                return ActionChip(
                  label: Text(token),
                  avatar: isSelected ? const Icon(Icons.check_rounded, size: 16) : null,
                  backgroundColor: isSelected ? cs.primaryContainer : cs.surfaceContainerHighest,
                  labelStyle: tt.labelSmall?.copyWith(
                    color: isSelected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onPressed: () {
                    setState(() {
                      _keywordController.text = token;
                    });
                  },
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: AppLayout.spaceL),

          // Transaction Type
          Text('Transaction Type', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppLayout.spaceS),
          SegmentedButton<RuleTransactionType>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: RuleTransactionType.expense,
                label: Text('Expense'),
                icon: Icon(Icons.arrow_upward_rounded),
              ),
              ButtonSegment(
                value: RuleTransactionType.income,
                label: Text('Income'),
                icon: Icon(Icons.arrow_downward_rounded),
              ),
              ButtonSegment(
                value: RuleTransactionType.transfer,
                label: Text('Transfer'),
                icon: Icon(Icons.swap_horiz_rounded),
              ),
            ],
            selected: {_selectedType},
            onSelectionChanged: (set) {
              setState(() {
                _selectedType = set.first;
              });
            },
          ),
          const SizedBox(height: AppLayout.spaceL),

          // Category Picker
          Text('Default Category (Optional)', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppLayout.spaceS),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: TransactionCategory.allNames.map((categoryName) {
              final isSelected = _selectedCategory == categoryName;
              final catColor = TransactionCategory.colorFor(categoryName);
              final catIcon = TransactionCategory.iconFor(categoryName);

              return FilterChip(
                showCheckmark: false,
                label: Text(categoryName),
                avatar: Icon(
                  catIcon,
                  size: 16,
                  color: isSelected ? cs.onPrimary : catColor,
                ),
                selected: isSelected,
                selectedColor: cs.primary,
                labelStyle: tt.labelSmall?.copyWith(
                  color: isSelected ? cs.onPrimary : cs.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (selected) {
                  setState(() {
                    _selectedCategory = selected ? categoryName : null;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: AppLayout.spaceL),

          // Target Account Picker (if Dual Accounts is enabled)
          Consumer<SettingsProvider>(
            builder: (context, settings, _) {
              if (!settings.enableSavingsVault) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Target Account (Optional)', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'Explicitly route transactions matching this rule to a specific account.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppLayout.spaceS),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        showCheckmark: false,
                        label: const Text('Auto / Default'),
                        selected: _targetAccount == null,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _targetAccount = null);
                          }
                        },
                      ),
                      ChoiceChip(
                        showCheckmark: false,
                        avatar: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                        label: Text(settings.account1Name),
                        selected: _targetAccount == 'daily',
                        onSelected: (selected) {
                          setState(() => _targetAccount = selected ? 'daily' : null);
                        },
                      ),
                      ChoiceChip(
                        showCheckmark: false,
                        avatar: const Icon(Icons.savings_outlined, size: 16),
                        label: Text(settings.account2Name),
                        selected: _targetAccount == 'savings',
                        onSelected: (selected) {
                          setState(() => _targetAccount = selected ? 'savings' : null);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppLayout.spaceL),
                ],
              );
            },
          ),

          // Custom Clean Title / Description (Optional)
          Text('Custom Transaction Title (Optional)', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            'If provided, incoming SMS matching this rule will use this exact clean description.',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppLayout.spaceS),
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(
              hintText: 'e.g. ComBank Digital Transfer, Office Salary',
              prefixIcon: const Icon(Icons.edit_note_rounded),
              filled: true,
              fillColor: cs.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppLayout.spaceL),

          // OTP / 2FA Safeguard Override Switch
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppLayout.radiusM),
              border: Border.all(
                color: _bypassOtpFilter ? cs.primary.withValues(alpha: 0.5) : cs.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: SwitchListTile.adaptive(
              value: _bypassOtpFilter,
              onChanged: (val) {
                AppHaptics.selectionClick();
                setState(() {
                  _bypassOtpFilter = val;
                });
              },
              title: Text(
                'Bypass OTP / Authorization Filter',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Enable for banks (like ComBank) that send approval codes for transfers without a follow-up confirmation SMS.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              secondary: Icon(
                _bypassOtpFilter ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                color: _bypassOtpFilter ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: AppLayout.spaceXL),

          // Save Button
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_rounded),
            label: Text(widget.existingRule != null ? 'Update Rule' : 'Save & Apply Rule'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusL),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

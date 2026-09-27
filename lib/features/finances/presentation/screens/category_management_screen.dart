// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:note_taking_app/core/services/app_haptics.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:note_taking_app/data/category_constants.dart';
import 'package:note_taking_app/data/category_definition.dart';
import 'package:note_taking_app/features/finances/data/transaction_repository.dart';
import 'package:note_taking_app/data/transaction_category.dart';
import 'package:note_taking_app/core/theme/app_layout.dart';
import 'package:note_taking_app/core/ui/app_morphing_fab.dart';
import 'package:note_taking_app/core/ui/expressive_sliver_app_bar.dart';
import 'package:note_taking_app/core/ui/expressive_shape_morph_indicator.dart';
import 'package:note_taking_app/utils/app_route.dart';
import 'package:note_taking_app/features/finances/presentation/screens/sms_rules_screen.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  List<CategoryDefinition> _categories = [];
  bool _loading = true;
  bool _isFabExpanded = true;

  bool _onScrollNotification(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.reverse) {
      if (_isFabExpanded) setState(() => _isFabExpanded = false);
    } else if (notification.direction == ScrollDirection.forward) {
      if (!_isFabExpanded) setState(() => _isFabExpanded = true);
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await TransactionRepository.instance.getAllCategoryDefinitions();
    if (mounted) {
      setState(() {
        _categories = cats;
        _loading = false;
      });
    }
  }

  Future<void> _saveAndReload() async {
    await TransactionCategory.reload();
    await _loadCategories();
  }

  Future<void> _confirmRestoreDefaults() async {
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore default categories?'),
        content: const Text(
            'Custom categories will be removed and built-in categories reset to their default colors and keywords. Existing transactions keep their category labels.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    AppHaptics.mediumImpact();
    await TransactionRepository.instance.resetCategoriesToDefaults();
    await _saveAndReload();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Categories restored to defaults')),
      );
    }
  }

  Future<void> _showEditDialog(CategoryDefinition def) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _EditCategoryDialog(
        definition: def,
        existingCategories: _categories,
        onSave: (oldName, updated) async {
          await TransactionRepository.instance.renameCategoryDefinition(oldName, updated);
          await _saveAndReload();
        },
      ),
    );
  }

  Future<void> _showAddDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _AddCategoryDialog(
        existingCategories: _categories,
        onSave: (newDef) async {
          await TransactionRepository.instance.renameCategoryDefinition(newDef.name, newDef);
          await _saveAndReload();
        },
      ),
    );
  }

  Future<void> _deleteCategory(CategoryDefinition def) async {
    if (def.name == CategoryConstants.other) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The "Other" fallback category cannot be deleted.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${def.name}"?'),
        content: const Text(
            'Existing transactions with this category will be reassigned to "Other" so your history stays intact.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      AppHaptics.mediumImpact();
      await TransactionRepository.instance.deleteCategoryDefinition(def.name);
      await _saveAndReload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: NotificationListener<UserScrollNotification>(
        onNotification: _onScrollNotification,
        child: AnimationLimiter(
          child: CustomScrollView(
            slivers: [
              ExpressiveSliverAppBar(
                titleText: 'Manage Categories',
                showBackButton: true,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings_backup_restore),
                    tooltip: 'Restore defaults',
                    onPressed: _confirmRestoreDefaults,
                  ),
                ],
              ),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: ExpressiveShapeMorphIndicator(size: 44)),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, AppLayout.fabBottomPadding),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final cat = _categories[index];
                        final catColor = Color(cat.colorValue);
                        final isLast = index == _categories.length - 1;
                        return AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 375),
                          child: SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              child: Card(
                                margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
                                elevation: 0,
                                color: colorScheme.surfaceContainerLow,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppLayout.radiusL),
                                  side: BorderSide(
                                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                                    width: 1.0,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: catColor.withValues(alpha: 0.15),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: catColor.withValues(alpha: 0.3),
                                                width: 1,
                                              ),
                                            ),
                                            child: Icon(
                                              TransactionCategory.iconFor(cat.name),
                                              color: catColor,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              cat.name,
                                              style: textTheme.titleSmall?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          if (cat.name != CategoryConstants.other)
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline),
                                              iconSize: 20,
                                              color: colorScheme.error,
                                              tooltip: 'Delete category',
                                              onPressed: () => _deleteCategory(cat),
                                            ),
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined),
                                            iconSize: 20,
                                            color: colorScheme.onSurfaceVariant,
                                            tooltip: 'Edit category',
                                            onPressed: () => _showEditDialog(cat),
                                          ),
                                        ],
                                      ),
                                      if (cat.keywords.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children: cat.keywords.map((kw) {
                                              return Padding(
                                                padding: const EdgeInsets.only(right: 6),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: catColor.withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(AppLayout.radiusXL),
                                                    border: Border.all(
                                                      color: catColor.withValues(alpha: 0.3),
                                                      width: 0.5,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    kw,
                                                    style: textTheme.labelSmall
                                                        ?.copyWith(color: catColor),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ] else
                                        Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Text(
                                            'No keywords',
                                            style: textTheme.labelSmall?.copyWith(
                                              color: colorScheme.onSurfaceVariant,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: _categories.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: AppMorphingFab(
        isExpanded: _isFabExpanded,
        icon: Icons.add,
        label: 'New Category',
        onPressed: () => _showAddDialog(),
        secondaryAction: IconButton(
          tooltip: 'SMS Rules',
          icon: Icon(Icons.rule_outlined, color: colorScheme.onPrimaryContainer, size: 20),
          onPressed: () {
            AppRoute.push(context, const SmsRulesScreen());
          },
        ),
      ),
    );
  }
}

// ── Icon Swatches List ────────────────────────────────────────────────────────

const List<IconData> _categoryIconSwatches = [
  Icons.directions_car_outlined,
  Icons.restaurant_outlined,
  Icons.subscriptions_outlined,
  Icons.shopping_bag_outlined,
  Icons.power_outlined,
  Icons.medical_services_outlined,
  Icons.sports_esports_outlined,
  Icons.payment_outlined,
  Icons.savings_outlined,
  Icons.school_outlined,
  Icons.flight_outlined,
  Icons.home_outlined,
  Icons.fitness_center_outlined,
  Icons.local_grocery_store_outlined,
  Icons.card_giftcard_outlined,
  Icons.pets_outlined,
  Icons.computer_outlined,
  Icons.work_outlined,
  Icons.child_friendly_outlined,
  Icons.build_outlined,
  Icons.local_gas_station_outlined,
  Icons.movie_outlined,
  Icons.phone_android_outlined,
  Icons.category_outlined,
];

const List<Color> _categoryColorSwatches = [
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

// ── Edit Category Dialog ─────────────────────────────────────────────────────

class _EditCategoryDialog extends StatefulWidget {
  final CategoryDefinition definition;
  final List<CategoryDefinition> existingCategories;
  final Future<void> Function(String oldName, CategoryDefinition updated) onSave;

  const _EditCategoryDialog({
    required this.definition,
    required this.existingCategories,
    required this.onSave,
  });

  @override
  State<_EditCategoryDialog> createState() => _EditCategoryDialogState();
}

class _EditCategoryDialogState extends State<_EditCategoryDialog> {
  late TextEditingController _nameController;
  final _addKeywordController = TextEditingController();
  late Color _selectedColor;
  late IconData _selectedIcon;
  late List<String> _keywords;
  bool _saving = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.definition.name);
    _selectedColor = Color(widget.definition.colorValue);
    _selectedIcon = TransactionCategory.iconFor(widget.definition.name);
    _keywords = List.from(widget.definition.keywords);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addKeywordController.dispose();
    super.dispose();
  }

  void _addKeyword() {
    final kw = _addKeywordController.text.trim().toLowerCase();
    if (kw.isEmpty || _keywords.contains(kw)) return;
    setState(() => _keywords.add(kw));
    _addKeywordController.clear();
  }

  Future<void> _save() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      setState(() => _nameError = 'Category name required');
      return;
    }
    if (newName.toLowerCase() != widget.definition.name.toLowerCase()) {
      final exists = widget.existingCategories.any(
        (c) => c.name.toLowerCase() == newName.toLowerCase(),
      );
      if (exists) {
        setState(() => _nameError = 'Category name already exists');
        return;
      }
    }

    setState(() => _saving = true);
    final updated = widget.definition.copyWith(
      name: newName,
      colorValue: _selectedColor.value,
      keywords: _keywords,
      iconCodePoint: _selectedIcon.codePoint,
    );
    await widget.onSave(widget.definition.name, updated);
    AppHaptics.mediumImpact();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text('Edit Category'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Name
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  errorText: _nameError,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppLayout.radiusM),
                  ),
                  isDense: true,
                ),
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
              ),
              const SizedBox(height: 16),
              // Icon Picker
              Text(
                'Icon',
                style: textTheme.labelMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: _categoryIconSwatches.length,
                  itemBuilder: (context, idx) {
                    final icon = _categoryIconSwatches[idx];
                    final isSelected = _selectedIcon.codePoint == icon.codePoint;
                    return GestureDetector(
                      onTap: () {
                        AppHaptics.selectionClick();
                        setState(() => _selectedIcon = icon);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _selectedColor.withValues(alpha: 0.2)
                              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: _selectedColor, width: 2)
                              : null,
                        ),
                        child: Icon(
                          icon,
                          size: 20,
                          color: isSelected ? _selectedColor : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Colour Picker
              Text(
                'Colour',
                style: textTheme.labelMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categoryColorSwatches.map((color) {
                  final selected = _selectedColor.value == color.value;
                  return GestureDetector(
                    onTap: () {
                      AppHaptics.selectionClick();
                      setState(() => _selectedColor = color);
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: colorScheme.onSurface, width: 2.5)
                            : null,
                      ),
                      child: selected
                          ? Icon(Icons.check,
                              size: 16,
                              color: ThemeData.estimateBrightnessForColor(color) ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Keywords
              Text(
                'Keywords',
                style: textTheme.labelMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addKeywordController,
                      decoration: InputDecoration(
                        hintText: 'Add keyword…',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppLayout.radiusM),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (_) {
                        AppHaptics.selectionClick();
                        _addKeyword();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    color: colorScheme.primary,
                    onPressed: () {
                      AppHaptics.selectionClick();
                      _addKeyword();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_keywords.isEmpty)
                Text(
                  'No keywords — this category will only be used explicitly.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _keywords.map((kw) {
                    return Chip(
                      label: Text(kw),
                      labelStyle: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: _selectedColor),
                      backgroundColor: _selectedColor.withValues(alpha: 0.1),
                      side: BorderSide(
                          color: _selectedColor.withValues(alpha: 0.3), width: 0.5),
                      deleteIconColor: colorScheme.onSurfaceVariant,
                      onDeleted: () {
                        AppHaptics.selectionClick();
                        setState(() => _keywords.remove(kw));
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ── Add Category Dialog ──────────────────────────────────────────────────────

class _AddCategoryDialog extends StatefulWidget {
  final Future<void> Function(CategoryDefinition) onSave;
  final List<CategoryDefinition> existingCategories;

  const _AddCategoryDialog({
    required this.onSave,
    required this.existingCategories,
  });

  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final _nameController = TextEditingController();
  final _keywordController = TextEditingController();
  Color _selectedColor = _categoryColorSwatches[5]; // Blue default
  IconData _selectedIcon = _categoryIconSwatches[0];
  final List<String> _keywords = [];
  bool _saving = false;
  String? _nameError;

  @override
  void dispose() {
    _nameController.dispose();
    _keywordController.dispose();
    super.dispose();
  }

  void _addKeyword() {
    final kw = _keywordController.text.trim().toLowerCase();
    if (kw.isEmpty || _keywords.contains(kw)) return;
    setState(() => _keywords.add(kw));
    _keywordController.clear();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Name is required');
      return;
    }
    final exists = widget.existingCategories.any(
      (c) => c.name.toLowerCase() == name.toLowerCase(),
    );
    if (exists) {
      setState(() => _nameError = 'Category already exists');
      return;
    }
    setState(() {
      _saving = true;
      _nameError = null;
    });
    final def = CategoryDefinition(
      name: name,
      colorValue: _selectedColor.value,
      keywords: _keywords,
      isBuiltIn: false,
      iconCodePoint: _selectedIcon.codePoint,
    );
    await widget.onSave(def);
    AppHaptics.mediumImpact();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text('New Category'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name field
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Category name',
                  errorText: _nameError,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppLayout.radiusM),
                  ),
                  isDense: true,
                ),
                onChanged: (_) {
                  if (_nameError != null) {
                    setState(() => _nameError = null);
                  }
                },
              ),
              const SizedBox(height: 16),
              // Icon Picker
              Text(
                'Icon',
                style: textTheme.labelMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: _categoryIconSwatches.length,
                  itemBuilder: (context, idx) {
                    final icon = _categoryIconSwatches[idx];
                    final isSelected = _selectedIcon.codePoint == icon.codePoint;
                    return GestureDetector(
                      onTap: () {
                        AppHaptics.selectionClick();
                        setState(() => _selectedIcon = icon);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _selectedColor.withValues(alpha: 0.2)
                              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: _selectedColor, width: 2)
                              : null,
                        ),
                        child: Icon(
                          icon,
                          size: 20,
                          color: isSelected ? _selectedColor : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Color picker
              Text(
                'Colour',
                style: textTheme.labelMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categoryColorSwatches.map((color) {
                  final selected = _selectedColor == color;
                  return GestureDetector(
                    onTap: () {
                      AppHaptics.selectionClick();
                      setState(() => _selectedColor = color);
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: colorScheme.onSurface, width: 2.5)
                            : null,
                      ),
                      child: selected
                          ? Icon(Icons.check,
                              size: 16,
                              color:
                                  ThemeData.estimateBrightnessForColor(color) ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Keywords
              Text(
                'Keywords',
                style: textTheme.labelMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _keywordController,
                      decoration: InputDecoration(
                        hintText: 'Add keyword…',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppLayout.radiusM),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (_) {
                        AppHaptics.selectionClick();
                        _addKeyword();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    color: colorScheme.primary,
                    onPressed: () {
                      AppHaptics.selectionClick();
                      _addKeyword();
                    },
                  ),
                ],
              ),
              if (_keywords.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _keywords.map((kw) {
                    return Chip(
                      label: Text(kw),
                      labelStyle:
                          textTheme.labelSmall?.copyWith(color: _selectedColor),
                      backgroundColor: _selectedColor.withValues(alpha: 0.1),
                      side: BorderSide(
                          color: _selectedColor.withValues(alpha: 0.3),
                          width: 0.5),
                      deleteIconColor: colorScheme.onSurfaceVariant,
                      onDeleted: () {
                        AppHaptics.selectionClick();
                        setState(() => _keywords.remove(kw));
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

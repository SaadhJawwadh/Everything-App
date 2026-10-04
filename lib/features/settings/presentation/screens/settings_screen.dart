import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/services/app_haptics.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import 'package:note_taking_app/features/notes/presentation/screens/manage_tags_screen.dart';
import 'package:note_taking_app/features/notes/presentation/widgets/note_migration_sheet.dart';
import 'package:note_taking_app/features/finances/presentation/screens/category_management_screen.dart';
import 'package:note_taking_app/features/finances/presentation/screens/sms_rules_screen.dart';
import 'package:note_taking_app/features/sync/presentation/screens/p2p_sync_screen.dart';
import '../../../../screens/changelog_screen.dart';
import 'onboarding_screen.dart';
import '../../../../utils/app_constants.dart';
import '../../../../utils/widget_helper.dart';
import '../../../../utils/app_route.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/expressive_sliver_app_bar.dart';
import '../../../../core/ui/app_bottom_sheet.dart';
import '../../../../core/ui/app_chip.dart';
import '../../../../core/ui/app_card.dart';
import '../../../../core/ui/expressive_wavy_slider.dart';
import '../../../../data/transaction_category.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../screens/app_lock_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../services/backup_service.dart';
import '../../../../services/notification_service.dart';
import '../../../../widgets/settings_widgets.dart';
import '../../../finances/presentation/widgets/recurring_rules_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/settings_search_index.dart';

class SettingsScreen extends StatefulWidget {
  final String? initialQuery;

  const SettingsScreen({
    super.key,
    this.initialQuery,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _searchController;
  late String _searchQuery;
  String _selectedSearchCategory = 'All';

  final List<String> _searchCategories = [
    'All',
    'Appearance',
    'Features',
    'Finances',
    'Security',
    'Data',
    'About',
  ];

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialQuery ?? '';
    _searchController = TextEditingController(text: _searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showTrashPurgeDialog(BuildContext context, SettingsProvider settings) {
    final options = [
      (label: '7 Days', days: 7, desc: 'Auto-delete items 7 days old'),
      (label: '14 Days', days: 14, desc: 'Auto-delete items 14 days old'),
      (label: '30 Days (Default)', days: 30, desc: 'Auto-delete items 30 days old'),
      (label: 'Disabled', days: 0, desc: 'Never auto-delete deleted notes'),
    ];

    AppBottomSheet.show(
      context: context,
      title: 'Trash Auto-Purge Duration',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final isSelected = settings.trashAutoPurgeDays == opt.days;
          final colorScheme = Theme.of(context).colorScheme;

          return Material(
            color: Colors.transparent,
            child: ListTile(
              leading: Icon(
                Icons.auto_delete_outlined,
                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
              title: Text(
                opt.label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                opt.desc,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: isSelected
                  ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
                  : null,
              onTap: () {
                AppHaptics.selectionClick();
                settings.setTrashAutoPurgeDays(opt.days);
                Navigator.pop(context);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showThemePicker(BuildContext context, SettingsProvider settings) {
    final options = [
      (label: 'System Default', mode: ThemeMode.system, icon: Icons.brightness_auto_rounded, desc: 'Follow device dark mode settings'),
      (label: 'Light Theme', mode: ThemeMode.light, icon: Icons.light_mode_rounded, desc: 'Clean high-contrast light mode'),
      (label: 'Dark Theme', mode: ThemeMode.dark, icon: Icons.dark_mode_rounded, desc: 'Sleek dark mode surface theme'),
    ];

    AppBottomSheet.show(
      context: context,
      title: 'Choose Theme',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final isSelected = settings.themeMode == opt.mode;
          final colorScheme = Theme.of(context).colorScheme;

          return ListTile(
            leading: Icon(
              opt.icon,
              color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            title: Text(
              opt.label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              opt.desc,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: isSelected
                ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
                : null,
            onTap: () {
              AppHaptics.selectionClick();
              settings.setThemeMode(opt.mode);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showTextSizePicker(BuildContext context, SettingsProvider settings) {
    double currentSize = settings.textSize;
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final presets = [
      (label: 'Small (14px)', size: 14.0),
      (label: 'Medium (16px)', size: 16.0),
      (label: 'Large (20px)', size: 20.0),
    ];

    AppBottomSheet.show(
      context: context,
      title: 'Typography & Text Scale',
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dynamic Live Preview Card
              AppCard(
                padding: const EdgeInsets.all(AppLayout.spaceM),
                backgroundColor: colorScheme.surfaceContainerLow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.format_size_rounded, size: 18, color: colorScheme.primary),
                            const SizedBox(width: AppLayout.spaceXS),
                            Text(
                              'Live Preview',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        AppChip(
                          label: '${currentSize.toInt()}px • ${settings.textSizeLabel}',
                          backgroundColor: colorScheme.primaryContainer,
                          textColor: colorScheme.onPrimaryContainer,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppLayout.spaceM),
                    AnimatedDefaultTextStyle(
                      duration: AppLayout.animShort,
                      curve: AppLayout.curveEmphasizedDecelerate,
                      style: theme.textTheme.bodyMedium!.copyWith(
                        fontSize: currentSize,
                        height: 1.45,
                        color: colorScheme.onSurface,
                      ),
                      child: const Text(
                        'Everything App keeps your thoughts, finances, and health encrypted on-device with zero-cloud P2P sync.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppLayout.spaceL),

              // Tactile Sinusoidal Wavy Slider
              ExpressiveWavySlider(
                value: currentSize,
                min: 12.0,
                max: 24.0,
                divisions: 6,
                activeColor: colorScheme.primary,
                onChanged: (val) {
                  setSheetState(() => currentSize = val);
                  settings.setTextSize(val);
                },
              ),
              const SizedBox(height: AppLayout.spaceS),

              // Scale Label Badges
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('12px', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                  Text('18px', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                  Text('24px', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: AppLayout.spaceM),

              // Preset Quick Chips
              Wrap(
                spacing: AppLayout.spaceS,
                runSpacing: AppLayout.spaceS,
                alignment: WrapAlignment.center,
                children: presets.map((p) {
                  final isSelected = (currentSize - p.size).abs() < 0.5;
                  return ChoiceChip(
                    label: Text(p.label),
                    selected: isSelected,
                    showCheckmark: false,
                    shape: const StadiumBorder(),
                    selectedColor: colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        AppHaptics.selectionClick();
                        setSheetState(() => currentSize = p.size);
                        settings.setTextSize(p.size);
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppLayout.spaceM),
            ],
          );
        },
      ),
      actions: [
        FilledButton.tonal(
          style: FilledButton.styleFrom(shape: const StadiumBorder()),
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          final isSearching = _searchQuery.trim().isNotEmpty;
          final searchResults = isSearching ? _buildSearchResults(context, settings) : <Widget>[];

          return AnimationLimiter(
            child: CustomScrollView(
              slivers: [
                ExpressiveSliverAppBar(
                  showBackButton: true,
                  title: Container(
                    height: 44,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                              });
                            },
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: '${AppLocalizations.of(context)!.settingsTitle} / Search...',
                              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                              filled: false,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              AppHaptics.selectionClick();
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _selectedSearchCategory = 'All';
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                if (isSearching)
                  SliverToBoxAdapter(
                    child: Container(
                      height: 48,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _searchCategories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final cat = _searchCategories[index];
                          final isSelected = _selectedSearchCategory == cat;
                          return AppChip(
                            label: cat,
                            isSelected: isSelected,
                            onTap: () {
                              AppHaptics.selectionClick();
                              setState(() {
                                _selectedSearchCategory = cat;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ),

                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                      isSearching
                          ? (searchResults.isNotEmpty
                              ? searchResults
                              : [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 48),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.search_off_rounded,
                                          size: 56,
                                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No settings matching "$_searchQuery"',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Quick suggestions:',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          alignment: WrapAlignment.center,
                                          children: ['SMS', 'Theme', 'Lock', 'Backup', 'Currency', 'Tags'].map((term) {
                                            return ActionChip(
                                              label: Text(term),
                                              avatar: const Icon(Icons.search, size: 14),
                                              onPressed: () {
                                                AppHaptics.selectionClick();
                                                _searchController.text = term;
                                                setState(() {
                                                  _searchQuery = term;
                                                });
                                              },
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ])
                          : AnimationConfiguration.toStaggeredList(
                              duration: const Duration(milliseconds: 220),
                              childAnimationBuilder: (widget) => SlideAnimation(
                                verticalOffset: 24.0,
                                child: FadeInAnimation(child: widget),
                              ),
                              children: [
                                // 0. Top Hero Dashboard Card
                                SettingsHeroCard(
                                  isAppLockEnabled: settings.appLockEnabled,
                                  isFinancialManagerEnabled: settings.showFinancialManager,
                                  isPeriodTrackerEnabled: settings.isPeriodTrackerEnabled,
                                  isAiEnabled: settings.isAiActive,
                                  autoBackupEnabled: settings.autoBackupEnabled,
                                  lastAutoBackupTimeFormatted: settings.lastAutoBackupTime != null
                                      ? _formatLastBackupTime(settings.lastAutoBackupTime!)
                                      : null,
                                  currentThemeMode: settings.themeMode,
                                  onThemeModeChanged: settings.setThemeMode,
                                  onAppLockTap: () {
                                    AppHaptics.selectionClick();
                                    settings.setAppLockEnabled(!settings.appLockEnabled);
                                  },
                                  onBackupTap: () {
                                    AppHaptics.selectionClick();
                                    BackupService.exportBackup(context);
                                  },
                                ),

                                 // 1. Appearance & UI
                                SettingsSection(
                                  title: 'Appearance & UI',
                                  icon: Icons.palette_outlined,
                                  accentColor: colorScheme.primary,
                                  children: [
                                    SettingsSwitchTile(
                                      icon: Icons.color_lens_outlined,
                                      iconColor: colorScheme.secondary,
                                      title: 'Dynamic Wallpaper Theme',
                                      subtitle: 'Match app colors with device wallpaper (Android 12+)',
                                      value: settings.useDynamicColor,
                                      onChanged: settings.setUseDynamicColor,
                                    ),
                                    const _Divider(),
                                    SettingsSwitchTile(
                                      icon: Icons.vibration_rounded,
                                      iconColor: colorScheme.tertiary,
                                      title: 'Tactile Haptics',
                                      subtitle: 'Restrained physical feedback for sliders, long-press, and actions',
                                      value: settings.enableHaptics,
                                      onChanged: settings.setEnableHaptics,
                                    ),
                                    const _Divider(),
                                    SettingsSegmentedTile<double>(
                                      icon: Icons.text_fields,
                                      title: 'Text Scale',
                                      subtitle: 'Global font sizing',
                                      segments: const [
                                        ButtonSegment(value: 14.0, label: Text('Small')),
                                        ButtonSegment(value: 16.0, label: Text('Medium')),
                                        ButtonSegment(value: 20.0, label: Text('Large')),
                                      ],
                                      selectedValue: settings.textSize,
                                      onSelectionChanged: settings.setTextSize,
                                    ),
                                    const _Divider(),
                                    SettingsTile(
                                      icon: Icons.translate_rounded,
                                      iconColor: colorScheme.primary,
                                      title: 'Language',
                                      subtitle: _getLanguageDisplayName(settings.selectedLanguageCode),
                                      valueBadge: _getLanguageBadge(settings.selectedLanguageCode),
                                      showArrow: true,
                                      onTap: () => _showLanguagePicker(context, settings),
                                    ),
                                  ],
                                ),

                                // 2. Notes & Editor
                                SettingsSection(
                                  title: 'Notes & Editor',
                                  icon: Icons.edit_note_rounded,
                                  accentColor: const Color(0xFFF59E0B),
                                  children: [
                                    SettingsTile(
                                      icon: Icons.label_outline,
                                      iconColor: const Color(0xFFF59E0B),
                                      title: 'Manage Tags',
                                      subtitle: 'Rename or delete note tags',
                                      showArrow: true,
                                      onTap: () => AppRoute.push(context, const ManageTagsScreen()),
                                    ),
                                    const _Divider(),
                                    SettingsSwitchTile(
                                      icon: Icons.tag_rounded,
                                      iconColor: const Color(0xFFF59E0B),
                                      title: 'Tag Filter Bar',
                                      subtitle: 'Show quick tag filter pills at the top of the notes list',
                                      value: settings.showTagFilterBar,
                                      onChanged: settings.setShowTagFilterBar,
                                    ),
                                    const _Divider(),
                                    SettingsSwitchTile(
                                      icon: Icons.border_color_outlined,
                                      iconColor: colorScheme.secondary,
                                      title: 'Minimal Editor Mode',
                                      subtitle: 'Streamlined writing toolbar; secondary tools moved to menu',
                                      value: settings.minimalEditorMode,
                                      onChanged: settings.setMinimalEditorMode,
                                    ),
                                    const _Divider(),
                                    SettingsSwitchTile(
                                      icon: Icons.checklist_rtl_rounded,
                                      iconColor: colorScheme.secondary,
                                      title: 'Collapse Completed Checklists',
                                      subtitle: 'Move finished to-do items to a bottom section',
                                      value: settings.moveCompletedChecklistsToBottom,
                                      onChanged: settings.setMoveCompletedChecklistsToBottom,
                                    ),
                                    const _Divider(),
                                    SettingsSwitchTile(
                                      icon: Icons.celebration_outlined,
                                      iconColor: const Color(0xFFF59E0B),
                                      title: 'Milestone Celebrations',
                                      subtitle: 'Calm celebrations when reaching savings goals and settling debts',
                                      value: settings.showMilestoneDelight,
                                      onChanged: settings.setShowMilestoneDelight,
                                    ),
                                    const _Divider(),
                                    SettingsSwitchTile(
                                      icon: Icons.calendar_view_week_rounded,
                                      iconColor: colorScheme.primary,
                                      title: 'Days of Clarity Strip',
                                      subtitle: 'Visualize 14-day mindfulness activity without stressful streak countdowns',
                                      value: settings.showClarityMosaic,
                                      onChanged: settings.setShowClarityMosaic,
                                    ),
                                    const _Divider(),
                                    SettingsTile(
                                      icon: Icons.auto_delete_outlined,
                                      iconColor: colorScheme.tertiary,
                                      title: 'Trash Auto-Purge',
                                      subtitle: 'Automatic deletion schedule for trash',
                                      valueBadge: settings.trashAutoPurgeDays <= 0
                                          ? 'Disabled'
                                          : '${settings.trashAutoPurgeDays} Days',
                                      showArrow: true,
                                      onTap: () => _showTrashPurgeDialog(context, settings),
                                    ),
                                    const _Divider(),
                                    SettingsTile(
                                      icon: Icons.import_contacts_rounded,
                                      iconColor: const Color(0xFFF59E0B),
                                      title: 'Import & Migrate Notes',
                                      subtitle: 'Import from Google Keep Takeout, Markdown, or text files',
                                      showArrow: true,
                                      onTap: () => NoteMigrationSheet.show(context),
                                    ),
                                    if (settings.isDeviceAiSupported) ...[
                                      const _Divider(),
                                      SettingsSwitchTile(
                                        icon: Icons.auto_awesome_outlined,
                                        iconColor: colorScheme.primary,
                                        title: 'Gemini Nano AI',
                                        subtitle: 'Enable offline summaries, tag suggestions & smart SMS parsing',
                                        value: settings.useOnDeviceAi,
                                        onChanged: settings.setUseOnDeviceAi,
                                      ),
                                    ],
                                  ],
                                ),

                                // 3. App Modules
                                SettingsSection(
                                  title: 'App Modules',
                                  icon: Icons.apps_rounded,
                                  accentColor: colorScheme.secondary,
                                  children: [
                                    SettingsSwitchTile(
                                      icon: Icons.account_balance_wallet_outlined,
                                      iconColor: const Color(0xFF10B981),
                                      iconBackgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                                      title: 'Financial Manager',
                                      subtitle: 'Expense tracking, SMS bank ledger & budgets',
                                      value: settings.showFinancialManager,
                                      onChanged: settings.setShowFinancialManager,
                                    ),
                                    const _Divider(),
                                    SettingsSwitchTile(
                                      icon: Icons.calendar_month_outlined,
                                      iconColor: const Color(0xFFF43F5E),
                                      iconBackgroundColor: const Color(0xFFF43F5E).withValues(alpha: 0.15),
                                      title: 'Period Tracker',
                                      subtitle: 'Optional cycle tracking & predictions',
                                      value: settings.isPeriodTrackerEnabled,
                                      onChanged: settings.setIsPeriodTrackerEnabled,
                                    ),
                                  ],
                                ),

                                // 4. Finances & Bank Automation (Configured only when Financial Manager is enabled)
                                if (settings.showFinancialManager) ...[
                                  SettingsSection(
                                    title: 'Finances & Bank Automation',
                                    icon: Icons.account_balance_wallet_outlined,
                                    accentColor: const Color(0xFF10B981),
                                    children: [
                                      SettingsTile(
                                        icon: Icons.currency_exchange_outlined,
                                        iconColor: const Color(0xFF10B981),
                                        title: 'Currency',
                                        subtitle: 'Base ledger currency symbol',
                                        valueBadge: settings.currency,
                                        showArrow: true,
                                        onTap: () => _showCurrencyPicker(context, settings),
                                      ),
                                      const _Divider(),
                                      SettingsSwitchTile(
                                        icon: Icons.sms_outlined,
                                        iconColor: colorScheme.secondary,
                                        title: 'SMS Bank Import',
                                        subtitle: 'Automatically import and parse transactions from bank SMS',
                                        value: settings.enableSmsImport,
                                        onChanged: settings.setEnableSmsImport,
                                      ),
                                      if (settings.enableSmsImport) ...[
                                        const _Divider(),
                                        SettingsTile(
                                          icon: Icons.mark_chat_unread_outlined,
                                          iconColor: colorScheme.secondary,
                                          title: 'SMS & Bank Automation Rules',
                                          subtitle: 'Auto-sync, import rules, sender blocklist & parser testing',
                                          showArrow: true,
                                          onTap: () => AppRoute.push(context, const SmsRulesScreen()),
                                        ),
                                      ],
                                      const _Divider(),
                                      SettingsSwitchTile(
                                        icon: Icons.donut_large_outlined,
                                        iconColor: colorScheme.tertiary,
                                        title: 'Budgets & Financial Goals',
                                        subtitle: 'Monthly spending limits, analytics chart deck & visual targets',
                                        value: settings.enableBudgetsAndAnalytics,
                                        onChanged: settings.setEnableBudgetsAndAnalytics,
                                      ),
                                      const _Divider(),
                                      SettingsTile(
                                        icon: Icons.category_outlined,
                                        iconColor: colorScheme.tertiary,
                                        title: 'Categories & Budgets',
                                        subtitle: 'Customise keywords, budget allocations & colors',
                                        showArrow: true,
                                        onTap: () => AppRoute.push(context, const CategoryManagementScreen()),
                                      ),
                                      const _Divider(),
                                      SettingsSwitchTile(
                                        icon: Icons.event_repeat_outlined,
                                        iconColor: const Color(0xFF10B981),
                                        title: 'Recurring Subscriptions & Rules',
                                        subtitle: 'Track repeated bills, periodic income & salary reminders',
                                        value: settings.enableRecurringRules,
                                        onChanged: settings.setEnableRecurringRules,
                                      ),
                                      if (settings.enableRecurringRules) ...[
                                        const _Divider(),
                                        SettingsTile(
                                          icon: Icons.edit_calendar_outlined,
                                          iconColor: const Color(0xFF10B981),
                                          title: 'Manage Subscriptions',
                                          subtitle: 'Manage repeating bills, salaries & automated rules',
                                          showArrow: true,
                                          onTap: () => RecurringRulesSheet.show(
                                            context: context,
                                            currency: settings.currency,
                                            onRulesUpdated: () {},
                                          ),
                                        ),
                                      ],
                                      const _Divider(),
                                      SettingsSwitchTile(
                                        icon: Icons.account_balance_wallet_outlined,
                                        iconColor: colorScheme.secondary,
                                        iconBackgroundColor: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                                        title: 'Savings Vault & Dual Accounts',
                                        subtitle: 'Separate daily operating cash flow from long-term savings',
                                        value: settings.enableSavingsVault,
                                        onChanged: settings.setEnableSavingsVault,
                                      ),
                                      if (settings.enableSavingsVault) ...[
                                        const _Divider(),
                                        SettingsTile(
                                          icon: Icons.drive_file_rename_outline_rounded,
                                          iconColor: colorScheme.primary,
                                          title: 'Account Names & Routing',
                                          subtitle: '${settings.account1Name} & ${settings.account2Name} • Category defaults',
                                          showArrow: true,
                                          onTap: () => _showAccountNamingAndRoutingSheet(context, settings),
                                        ),
                                      ],
                                      const _Divider(),
                                      SettingsSwitchTile(
                                        icon: Icons.pie_chart_outline_rounded,
                                        iconColor: colorScheme.tertiary,
                                        iconBackgroundColor: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                                        title: 'Split Bills & Shared Debts',
                                        subtitle: 'Group bill splitting, friend balances & receipt scanner',
                                        value: settings.showSplitBills,
                                        onChanged: settings.setShowSplitBills,
                                      ),
                                      if (settings.showSplitBills) ...[
                                        const _Divider(),
                                        SettingsTile(
                                          icon: Icons.account_balance_outlined,
                                          iconColor: colorScheme.secondary,
                                          title: 'Default Payment Details',
                                          subtitle: settings.defaultPaymentInfo.isNotEmpty
                                              ? settings.defaultPaymentInfo
                                              : 'Set bank / mobile pay details for WhatsApp split reminders',
                                          showArrow: true,
                                          onTap: () => _showDefaultPaymentInfoDialog(context, settings),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],

                                // 5. Health & Period Tracker (Configured only when Period Tracker is enabled)
                                if (settings.isPeriodTrackerEnabled) ...[
                                  SettingsSection(
                                    title: 'Health & Period Tracker',
                                    icon: Icons.calendar_month_outlined,
                                    accentColor: theme.extension<AppSemanticColors>()?.phaseMenstrual ?? colorScheme.tertiary,
                                    children: [
                                      SettingsSwitchTile(
                                        icon: Icons.visibility_off_outlined,
                                        iconColor: theme.extension<AppSemanticColors>()?.phaseMenstrual ?? colorScheme.tertiary,
                                        title: 'Discreet Privacy Mode',
                                        subtitle: 'Conceal cycle day numbers and phases on dashboard with tap-to-reveal',
                                        value: settings.isDiscreetHealthMode,
                                        onChanged: settings.setIsDiscreetHealthMode,
                                      ),
                                      const _Divider(),
                                      SettingsTile(
                                        icon: Icons.notifications_none_outlined,
                                        iconColor: theme.extension<AppSemanticColors>()?.phaseMenstrual ?? colorScheme.tertiary,
                                        title: 'Discreet Notification Text',
                                        subtitle: 'Text shown in cycle prediction alerts',
                                        valueBadge: settings.discreetNotificationText,
                                        showArrow: true,
                                        onTap: () => _showNotificationTextDialog(context, settings),
                                      ),
                                    ],
                                  ),
                                ],

                                // 6. Privacy & Security
                                SettingsSection(
                                  title: 'Privacy & Security',
                                  icon: Icons.security_outlined,
                                  accentColor: colorScheme.primary,
                                  children: [
                                    SettingsSwitchTile(
                                      icon: Icons.lock_outline,
                                      iconColor: colorScheme.primary,
                                      title: 'App Lock',
                                      subtitle: 'Require authentication to open app',
                                      value: settings.appLockEnabled,
                                      onChanged: settings.setAppLockEnabled,
                                    ),
                                    if (settings.appLockEnabled) ...[
                                      const _Divider(),
                                      SettingsSwitchTile(
                                        icon: Icons.fingerprint_outlined,
                                        iconColor: colorScheme.secondary,
                                        title: 'Use Biometrics',
                                        subtitle: 'Require biometric scan specifically',
                                        value: settings.useBiometrics,
                                        onChanged: settings.setUseBiometrics,
                                      ),
                                      const _Divider(),
                                      SettingsTile(
                                        icon: Icons.timer_outlined,
                                        iconColor: colorScheme.tertiary,
                                        title: 'Auto-Lock Timeout',
                                        subtitle: 'Inactivity delay before locking',
                                        valueBadge: _getTimeoutLabel(settings.appLockTimeout),
                                        showArrow: true,
                                        onTap: () => _showTimeoutPicker(context, settings),
                                      ),
                                    ],
                                  ],
                                ),

                                // 7. Data, Sync & Backups
                                SettingsSection(
                                  title: 'Data, Sync & Backups',
                                  icon: Icons.cloud_sync_outlined,
                                  accentColor: const Color(0xFF0EA5E9),
                                  children: [
                                    SettingsTile(
                                      icon: Icons.devices_rounded,
                                      iconColor: const Color(0xFF0EA5E9),
                                      title: 'P2P Device Sync',
                                      subtitle: 'Sync notes between devices (Local / Relay)',
                                      showArrow: true,
                                      onTap: () => AppRoute.push(context, const P2pSyncScreen()),
                                    ),
                                    const _Divider(),
                                    SettingsTile(
                                      icon: Icons.download_outlined,
                                      iconColor: colorScheme.primary,
                                      title: 'Export Backup',
                                      subtitle: 'Save notes to an encrypted JSON file',
                                      showArrow: true,
                                      onTap: () => BackupService.exportBackup(context),
                                    ),
                                    const _Divider(),
                                    SettingsTile(
                                      icon: Icons.upload_outlined,
                                      iconColor: colorScheme.secondary,
                                      title: 'Import Backup',
                                      subtitle: 'Restore from a JSON backup file',
                                      showArrow: true,
                                      onTap: () => BackupService.importBackup(context),
                                    ),
                                    if (!kIsWeb && Platform.isAndroid) ...[
                                      const _Divider(),
                                      SettingsSwitchTile(
                                        icon: Icons.cloud_sync_outlined,
                                        iconColor: const Color(0xFF0EA5E9),
                                        title: 'Automatic Backups',
                                        subtitle: 'Schedule regular encrypted local backups',
                                        value: settings.autoBackupEnabled,
                                        onChanged: (value) async {
                                          await settings.setAutoBackupEnabled(value);
                                          await syncAutoBackupSchedule();
                                        },
                                      ),
                                      if (settings.autoBackupEnabled) ...[
                                        const _Divider(),
                                        SettingsTile(
                                          icon: Icons.schedule_outlined,
                                          iconColor: colorScheme.primary,
                                          title: 'Backup Frequency',
                                          subtitle: 'Frequency of automated backup tasks',
                                          valueBadge: _getFrequencyLabel(settings.autoBackupFrequency),
                                          showArrow: true,
                                          onTap: () => _showFrequencyPicker(context, settings),
                                        ),
                                        const _Divider(),
                                        SettingsTile(
                                          icon: Icons.folder_outlined,
                                          iconColor: colorScheme.secondary,
                                          title: 'Backup Location',
                                          subtitle: settings.autoBackupPath ?? 'Secure App Storage (Resilient)',
                                          showArrow: true,
                                          onTap: () => _showBackupLocationPicker(context, settings),
                                        ),
                                        if (settings.lastAutoBackupTime != null) ...[
                                          const _Divider(),
                                          SettingsTile(
                                            icon: Icons.history_outlined,
                                            iconColor: colorScheme.tertiary,
                                            title: 'Last Auto Backup',
                                            subtitle: 'Most recent successful backup',
                                            valueBadge: _formatLastBackupTime(settings.lastAutoBackupTime!),
                                          ),
                                        ],
                                        const _Divider(),
                                        SettingsTile(
                                          icon: Icons.play_arrow_rounded,
                                          iconColor: colorScheme.primary,
                                          title: 'Run Auto-Backup Now',
                                          subtitle: 'Trigger and verify background auto-backup immediately',
                                          showArrow: true,
                                          onTap: () async {
                                            AppHaptics.selectionClick();
                                            if (context.mounted) {
                                              await BackupService.performAutoBackupNow(context);
                                            }
                                          },
                                        ),
                                      ],
                                    ],
                                  ],
                                ),

                                // 8. About Section
                                SettingsSection(
                                  title: 'About',
                                  icon: Icons.info_outline_rounded,
                                  accentColor: colorScheme.onSurfaceVariant,
                                  children: [
                                    SettingsTile(
                                      icon: Icons.star_outline_rounded,
                                      iconColor: Colors.amber.shade700,
                                      iconBackgroundColor: Colors.amber.withValues(alpha: 0.2),
                                      title: 'Rate & Feedback',
                                      subtitle: 'Love the app? Rate us on the Play Store',
                                      trailing: Icon(
                                        Icons.open_in_new_rounded,
                                        size: 18,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      onTap: () => _launchUrl(
                                        'https://play.google.com/store/apps/details?id=com.saadhjawwadh.notebook',
                                      ),
                                    ),
                                    const _Divider(),
                                    SettingsTile(
                                      icon: Icons.history_rounded,
                                      iconColor: colorScheme.primary,
                                      title: 'Changelog',
                                      subtitle: 'View version release logs',
                                      showArrow: true,
                                      onTap: () => AppRoute.push(context, const ChangelogScreen()),
                                    ),
                                    const _Divider(),
                                    SettingsTile(
                                      icon: Icons.notifications_active_outlined,
                                      iconColor: colorScheme.primary,
                                      title: 'Test Notifications',
                                      subtitle: 'Trigger a sample diagnostic alert immediately',
                                      showArrow: true,
                                      onTap: () async {
                                        AppHaptics.selectionClick();
                                        await NotificationService.showTestNotification();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).clearSnackBars();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Test notification sent! Check your notification shade.'),
                                              behavior: SnackBarBehavior.floating,
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                    const _Divider(),
                                    SettingsTile(
                                      icon: Icons.rocket_launch_outlined,
                                      iconColor: colorScheme.secondary,
                                      title: 'Replay Setup & Intro',
                                      subtitle: 'Configure theme, modules, and AI assistant',
                                      showArrow: true,
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => const OnboardingScreen(isReplay: true),
                                          ),
                                        );
                                      },
                                    ),
                                    const _Divider(),
                                    FutureBuilder<PackageInfo>(
                                      future: PackageInfo.fromPlatform(),
                                      builder: (context, snapshot) {
                                        final version = snapshot.hasData
                                            ? 'v${snapshot.data!.version}+${snapshot.data!.buildNumber}'
                                            : 'Loading...';
                                        return SettingsTile(
                                          icon: Icons.info_outline_rounded,
                                          iconColor: colorScheme.tertiary,
                                          title: 'Version',
                                          subtitle: version,
                                          showArrow: true,
                                          onTap: () => _launchUrl(AppConstants.releaseUrl),
                                        );
                                      },
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 24),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildSearchResults(BuildContext context, SettingsProvider settings) {
    final query = _searchQuery.toLowerCase().trim();
    final catFilter = _selectedSearchCategory;

    final items = <Widget>[];

    bool matchesCategory(String categoryName) {
      if (catFilter == 'All') return true;
      return categoryName.toLowerCase() == catFilter.toLowerCase();
    }

    void addTile(
      Widget tile,
      String categoryName,
      String title, [
      String? subtitle,
      List<String>? keywords,
    ]) {
      if (!matchesCategory(categoryName)) return;

      // Look up indexed synonyms and keywords for this setting
      final registered = SettingsSearchIndex.items.firstWhere(
        (it) =>
            it.title.toLowerCase() == title.toLowerCase() ||
            (it.section.toLowerCase() == categoryName.toLowerCase() &&
                it.title.toLowerCase().contains(title.toLowerCase())),
        orElse: () => SettingsIndexItem(
          id: '',
          title: title,
          subtitle: subtitle ?? '',
          section: categoryName,
          icon: Icons.settings,
          keywords: keywords ?? [],
        ),
      );

      final combinedKeywords = <String>{
        categoryName.toLowerCase(),
        title.toLowerCase(),
        if (subtitle != null) subtitle.toLowerCase(),
        ...registered.keywords.map((k) => k.toLowerCase()),
        if (keywords != null) ...keywords.map((k) => k.toLowerCase()),
      };

      final matches = title.toLowerCase().contains(query) ||
          (subtitle != null && subtitle.toLowerCase().contains(query)) ||
          categoryName.toLowerCase().contains(query) ||
          combinedKeywords.any((k) => k.contains(query) || query.contains(k));

      if (matches) {
        if (items.isNotEmpty) items.add(const _Divider());
        items.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 56, top: 4, bottom: 2),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(AppLayout.radiusXS),
                  ),
                  child: Text(
                    categoryName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              tile,
            ],
          ),
        );
      }
    }

    // 1. Appearance
    addTile(
      SettingsTile(
        icon: Icons.palette_outlined,
        title: 'Theme',
        subtitle: _getThemeLabel(settings.themeMode),
        valueBadge: _getThemeLabel(settings.themeMode),
        showArrow: true,
        onTap: () => _showThemePicker(context, settings),
      ),
      'Appearance',
      'Theme',
      _getThemeLabel(settings.themeMode),
    );
    addTile(
      SettingsSwitchTile(
        icon: Icons.color_lens_outlined,
        title: 'Dynamic Wallpaper Theme',
        subtitle: 'Match app colors with device wallpaper (Android 12+)',
        value: settings.useDynamicColor,
        onChanged: settings.setUseDynamicColor,
      ),
      'Appearance',
      'Dynamic Wallpaper Theme',
      'Match app colors with device wallpaper (Android 12+)',
    );
    addTile(
      SettingsSwitchTile(
        icon: Icons.vibration_rounded,
        title: 'Tactile Haptics',
        subtitle: 'Restrained physical feedback for sliders, long-press, and actions',
        value: settings.enableHaptics,
        onChanged: settings.setEnableHaptics,
      ),
      'Appearance',
      'Tactile Haptics',
      'Restrained physical feedback for sliders, long-press, and actions vibration',
    );
    addTile(
      SettingsTile(
        icon: Icons.text_fields,
        title: 'Text Size',
        subtitle: settings.textSizeLabel,
        valueBadge: settings.textSizeLabel,
        showArrow: true,
        onTap: () => _showTextSizePicker(context, settings),
      ),
      'Appearance',
      'Text Size',
      settings.textSizeLabel,
    );
    addTile(
      SettingsSwitchTile(
        icon: Icons.lightbulb_outline_rounded,
        title: 'Show Pro-Tips',
        subtitle: 'Rotate actionable powerup tips every 3 days',
        value: settings.showProTips,
        onChanged: settings.setShowProTips,
      ),
      'Appearance',
      'Show Pro-Tips',
      'Rotate actionable powerup tips every 3 days',
    );
    addTile(
      SettingsTile(
        icon: Icons.translate_rounded,
        title: 'Language',
        subtitle: _getLanguageDisplayName(settings.selectedLanguageCode),
        valueBadge: _getLanguageBadge(settings.selectedLanguageCode),
        showArrow: true,
        onTap: () => _showLanguagePicker(context, settings),
      ),
      'Appearance',
      'Language',
      'English, தமிழ், Tamil, 中文, Chinese, Português, Portuguese, Español, Spanish, Français, French, Deutsch, German, System Default, Localize',
    );

    // 2. Features & Modules
    addTile(
      SettingsTile(
        icon: Icons.label_outline,
        title: 'Manage Tags',
        subtitle: 'Rename or delete note tags',
        showArrow: true,
        onTap: () => AppRoute.push(context, const ManageTagsScreen()),
      ),
      'Features',
      'Manage Tags',
      'Rename or delete note tags',
    );
    addTile(
      SettingsTile(
        icon: Icons.auto_delete_outlined,
        title: 'Trash Auto-Purge',
        subtitle: settings.trashAutoPurgeDays <= 0
            ? 'Disabled'
            : 'Auto-delete after ${settings.trashAutoPurgeDays} days',
        valueBadge: settings.trashAutoPurgeDays <= 0
            ? 'Disabled'
            : '${settings.trashAutoPurgeDays} Days',
        showArrow: true,
        onTap: () => _showTrashPurgeDialog(context, settings),
      ),
      'Features',
      'Trash Auto-Purge',
      'Automatic deletion schedule for trash',
    );
    if (settings.isDeviceAiSupported) {
      addTile(
        SettingsSwitchTile(
          icon: Icons.auto_awesome_outlined,
          title: 'Gemini Nano AI',
          subtitle: 'Enable offline summaries, tag suggestions & smart SMS parsing',
          value: settings.useOnDeviceAi,
          onChanged: settings.setUseOnDeviceAi,
        ),
        'Features',
        'Gemini Nano AI',
        'Enable offline summaries, tag suggestions & smart SMS parsing',
      );
    }
    addTile(
      SettingsSwitchTile(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Financial Manager',
        subtitle: 'Expense tracking, SMS bank ledger & budgets',
        value: settings.showFinancialManager,
        onChanged: settings.setShowFinancialManager,
      ),
      'Features',
      'Financial Manager',
      'Expense tracking, SMS bank ledger & budgets',
    );
    if (settings.showFinancialManager) {
      addTile(
        SettingsTile(
          icon: Icons.currency_exchange_outlined,
          title: 'Currency',
          subtitle: settings.currency,
          valueBadge: settings.currency,
          showArrow: true,
          onTap: () => _showCurrencyPicker(context, settings),
        ),
        'Features',
        'Currency',
        settings.currency,
      );
      addTile(
        SettingsTile(
          icon: Icons.mark_chat_unread_outlined,
          title: 'SMS & Bank Automation',
          subtitle: 'Auto-sync, import rules, sender blocklist & parser testing',
          showArrow: true,
          onTap: () => AppRoute.push(context, const SmsRulesScreen()),
        ),
        'Features',
        'SMS & Bank Automation',
        'Auto-sync, import rules, sender blocklist & parser testing',
      );
      addTile(
        SettingsTile(
          icon: Icons.category_outlined,
          title: 'Categories & Budgets',
          subtitle: 'Customise keywords, budget allocations & colors',
          showArrow: true,
          onTap: () => AppRoute.push(context, const CategoryManagementScreen()),
        ),
        'Features',
        'Categories & Budgets',
        'Customise keywords, budget allocations & colors',
      );
      addTile(
        SettingsTile(
          icon: Icons.event_repeat_outlined,
          title: 'Recurring Subscriptions',
          subtitle: 'Manage repeating bills, salaries & automated rules',
          showArrow: true,
          onTap: () => RecurringRulesSheet.show(
            context: context,
            currency: settings.currency,
            onRulesUpdated: () {},
          ),
        ),
        'Features',
        'Recurring Subscriptions',
        'Manage repeating bills, salaries & automated rules',
      );
      addTile(
        SettingsSwitchTile(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Savings Vault & Dual Accounts',
          subtitle: 'Separate daily operating cash flow from long-term savings',
          value: settings.enableSavingsVault,
          onChanged: settings.setEnableSavingsVault,
        ),
        'Features',
        'Savings Vault & Dual Accounts',
        'Separate daily operating cash flow from long-term savings',
      );
      if (settings.enableSavingsVault) {
        addTile(
          SettingsTile(
            icon: Icons.drive_file_rename_outline_rounded,
            title: 'Account Names & Routing',
            subtitle: '${settings.account1Name} & ${settings.account2Name} • Category defaults',
            showArrow: true,
            onTap: () => _showAccountNamingAndRoutingSheet(context, settings),
          ),
          'Features',
          'Account Names & Routing',
          '${settings.account1Name} ${settings.account2Name}',
        );
      }
      addTile(
        SettingsSwitchTile(
          icon: Icons.pie_chart_outline_rounded,
          title: 'Split Bills & Shared Debts',
          subtitle: 'Group bill splitting, friend balances & receipt scanner',
          value: settings.showSplitBills,
          onChanged: settings.setShowSplitBills,
        ),
        'Features',
        'Split Bills & Shared Debts',
        'Group bill splitting, friend balances & receipt scanner',
      );
      if (settings.showSplitBills) {
        addTile(
          SettingsTile(
            icon: Icons.account_balance_outlined,
            title: 'Default Payment Details',
            subtitle: settings.defaultPaymentInfo.isNotEmpty
                ? settings.defaultPaymentInfo
                : 'Set bank / mobile pay details for WhatsApp split reminders',
            showArrow: true,
            onTap: () => _showDefaultPaymentInfoDialog(context, settings),
          ),
          'Features',
          'Default Payment Details',
          settings.defaultPaymentInfo,
        );
      }
    }
    addTile(
      SettingsSwitchTile(
        icon: Icons.calendar_month_outlined,
        title: 'Period Tracker',
        subtitle: 'Optional cycle tracking & predictions',
        value: settings.isPeriodTrackerEnabled,
        onChanged: settings.setIsPeriodTrackerEnabled,
      ),
      'Features',
      'Period Tracker',
      'Optional cycle tracking & predictions',
    );
    if (settings.isPeriodTrackerEnabled) {
      addTile(
        SettingsSwitchTile(
          icon: Icons.visibility_off_outlined,
          title: 'Discreet Privacy Mode',
          subtitle: 'Conceal cycle day numbers and phases on dashboard with tap-to-reveal',
          value: settings.isDiscreetHealthMode,
          onChanged: settings.setIsDiscreetHealthMode,
        ),
        'Features',
        'Discreet Privacy Mode',
        'Conceal cycle day numbers and phases on dashboard with tap-to-reveal health period tracker',
      );
      addTile(
        SettingsTile(
          icon: Icons.notifications_none_outlined,
          title: 'Discreet Notification Text',
          subtitle: settings.discreetNotificationText,
          valueBadge: settings.discreetNotificationText,
          showArrow: true,
          onTap: () => _showNotificationTextDialog(context, settings),
        ),
        'Features',
        'Discreet Notification Text',
        settings.discreetNotificationText,
      );
    }

    // 3. Privacy & Security
    addTile(
      SettingsSwitchTile(
        icon: Icons.lock_outline,
        title: 'App Lock',
        subtitle: 'Require authentication to open app',
        value: settings.appLockEnabled,
        onChanged: settings.setAppLockEnabled,
      ),
      'Security',
      'App Lock',
      'Require authentication to open app',
    );
    if (settings.appLockEnabled) {
      addTile(
        SettingsSwitchTile(
          icon: Icons.fingerprint_outlined,
          title: 'Use Biometrics',
          subtitle: 'Require biometric scan specifically',
          value: settings.useBiometrics,
          onChanged: settings.setUseBiometrics,
        ),
        'Security',
        'Use Biometrics',
        'Require biometric scan specifically',
      );
      addTile(
        SettingsTile(
          icon: Icons.timer_outlined,
          title: 'Auto-Lock Timeout',
          subtitle: _getTimeoutLabel(settings.appLockTimeout),
          valueBadge: _getTimeoutLabel(settings.appLockTimeout),
          showArrow: true,
          onTap: () => _showTimeoutPicker(context, settings),
        ),
        'Security',
        'Auto-Lock Timeout',
        _getTimeoutLabel(settings.appLockTimeout),
      );
    }

    // 4. Data, Sync & Backups
    addTile(
      SettingsTile(
        icon: Icons.devices_rounded,
        title: 'P2P Device Sync',
        subtitle: 'Sync notes between devices (Local / Relay)',
        showArrow: true,
        onTap: () => AppRoute.push(context, const P2pSyncScreen()),
      ),
      'Data',
      'P2P Device Sync',
      'Sync notes between devices (Local / Relay)',
    );
    addTile(
      SettingsTile(
        icon: Icons.download_outlined,
        title: 'Export Backup',
        subtitle: 'Save notes to an encrypted JSON file',
        showArrow: true,
        onTap: () => BackupService.exportBackup(context),
      ),
      'Data',
      'Export Backup',
      'Save notes to an encrypted JSON file',
    );
    addTile(
      SettingsTile(
        icon: Icons.upload_outlined,
        title: 'Import Backup',
        subtitle: 'Restore from a JSON backup file',
        showArrow: true,
        onTap: () => BackupService.importBackup(context),
      ),
      'Data',
      'Import Backup',
      'Restore from a JSON backup file',
    );
    if (!kIsWeb && Platform.isAndroid) {
      addTile(
        SettingsSwitchTile(
          icon: Icons.backup_outlined,
          title: 'Auto Backup',
          subtitle: 'Schedule automatic backups',
          value: settings.autoBackupEnabled,
          onChanged: (value) async {
            await settings.setAutoBackupEnabled(value);
            await syncAutoBackupSchedule();
          },
        ),
        'Data',
        'Auto Backup',
        'Schedule automatic backups',
      );
      if (settings.autoBackupEnabled) {
        addTile(
          SettingsTile(
            icon: Icons.schedule_outlined,
            title: 'Backup Frequency',
            subtitle: _getFrequencyLabel(settings.autoBackupFrequency),
            valueBadge: _getFrequencyLabel(settings.autoBackupFrequency),
            showArrow: true,
            onTap: () => _showFrequencyPicker(context, settings),
          ),
          'Data',
          'Backup Frequency',
          _getFrequencyLabel(settings.autoBackupFrequency),
        );
        addTile(
          SettingsTile(
            icon: Icons.folder_outlined,
            title: 'Backup Location',
            subtitle: settings.autoBackupPath ?? 'Secure App Storage (Resilient)',
            showArrow: true,
            onTap: () => _showBackupLocationPicker(context, settings),
          ),
          'Data',
          'Backup Location',
          settings.autoBackupPath ?? 'Secure App Storage (Resilient)',
        );
      }
    }

    // 5. About
    addTile(
      SettingsTile(
        icon: Icons.star_outline_rounded,
        title: 'Rate & Feedback',
        subtitle: 'Love the app? Rate us on the Play Store',
        trailing: Icon(
          Icons.open_in_new_rounded,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        onTap: () => _launchUrl('https://play.google.com/store/apps/details?id=com.saadhjawwadh.notebook'),
      ),
      'About',
      'Rate & Feedback',
      'Love the app? Rate us on the Play Store',
    );
    addTile(
      SettingsTile(
        icon: Icons.history_rounded,
        title: 'Changelog',
        subtitle: 'View version release logs',
        showArrow: true,
        onTap: () => AppRoute.push(context, const ChangelogScreen()),
      ),
      'About',
      'Changelog',
      'View version release logs',
    );
    addTile(
      SettingsTile(
        icon: Icons.notifications_active_outlined,
        title: 'Test Notifications',
        subtitle: 'Trigger a sample diagnostic alert immediately',
        showArrow: true,
        onTap: () async {
          AppHaptics.selectionClick();
          await NotificationService.showTestNotification();
          if (context.mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Test notification sent! Check your notification shade.'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
      ),
      'About',
      'Test Notifications',
      'Trigger a sample diagnostic alert immediately test notifications',
    );
    addTile(
      SettingsTile(
        icon: Icons.rocket_launch_outlined,
        title: 'Replay Setup & Intro',
        subtitle: 'Configure theme, modules, and AI assistant',
        showArrow: true,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const OnboardingScreen(isReplay: true),
            ),
          );
        },
      ),
      'About',
      'Replay Setup & Intro',
      'Configure theme, modules, and AI assistant',
    );

    if (items.isEmpty) return [];

    final matchingCount = (items.length / 2).ceil();

    return [
      SettingsSection(
        title: 'Matching Results ($matchingCount)',
        icon: Icons.search_rounded,
        children: items,
      ),
    ];
  }

  String _getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System Default';
    }
  }

  String _getLanguageDisplayName(String code) {
    switch (code) {
      case 'ta':
        return 'தமிழ் (Tamil)';
      case 'zh':
        return '中文 (Chinese)';
      case 'pt':
        return 'Português (Portuguese)';
      case 'es':
        return 'Español (Spanish)';
      case 'fr':
        return 'Français (French)';
      case 'de':
        return 'Deutsch (German)';
      case 'en':
        return 'English';
      case 'system':
      default:
        return 'System Default';
    }
  }

  String _getLanguageBadge(String code) {
    switch (code) {
      case 'ta':
        return 'தமிழ்';
      case 'zh':
        return '中文';
      case 'pt':
        return 'PT';
      case 'es':
        return 'ES';
      case 'fr':
        return 'FR';
      case 'de':
        return 'DE';
      case 'en':
        return 'EN';
      case 'system':
      default:
        return 'Auto';
    }
  }

  void _showLanguagePicker(BuildContext context, SettingsProvider settings) {
    final colorScheme = Theme.of(context).colorScheme;
    final languages = [
      {
        'code': 'system',
        'name': 'System Default',
        'native': 'Follow Device Language',
        'icon': Icons.brightness_auto_rounded,
      },
      {
        'code': 'en',
        'name': 'English',
        'native': 'English (United States)',
        'icon': Icons.language_rounded,
      },
      {
        'code': 'zh',
        'name': '中文',
        'native': 'Chinese (Simplified)',
        'icon': Icons.translate_rounded,
      },
      {
        'code': 'pt',
        'name': 'Português',
        'native': 'Portuguese (Portugal / Brazil)',
        'icon': Icons.public_rounded,
      },
      {
        'code': 'es',
        'name': 'Español',
        'native': 'Spanish (Latin America / Spain)',
        'icon': Icons.travel_explore_rounded,
      },
      {
        'code': 'fr',
        'name': 'Français',
        'native': 'French (France / Canada)',
        'icon': Icons.language_rounded,
      },
      {
        'code': 'de',
        'name': 'Deutsch',
        'native': 'German (Germany / Austria)',
        'icon': Icons.translate_rounded,
      },
      {
        'code': 'ta',
        'name': 'தமிழ்',
        'native': 'Tamil (Sri Lanka / India)',
        'icon': Icons.translate_rounded,
      },
    ];

    AppBottomSheet.show(
      context: context,
      title: 'Select Language',
      child: Container(
        constraints: const BoxConstraints(maxHeight: 460),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: languages.length,
          separatorBuilder: (_, __) => const SizedBox(height: 4.0),
          itemBuilder: (context, index) {
            final lang = languages[index];
            final code = lang['code'] as String;
            final isSelected = settings.selectedLanguageCode == code;

            return ListTile(
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  lang['icon'] as IconData,
                  size: 20,
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              title: Text(
                lang['name'] as String,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                lang['native'] as String,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              trailing: isSelected
                  ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
                  : null,
              onTap: () {
                AppHaptics.selectionClick();
                settings.setSelectedLanguage(code);
                Navigator.pop(context);
              },
            );
          },
        ),
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context, SettingsProvider settings) {
    final colorScheme = Theme.of(context).colorScheme;
    const curated = AppConstants.curatedCurrencies;

    AppBottomSheet.show(
      context: context,
      title: 'Select Currency',
      child: Container(
        constraints: const BoxConstraints(maxHeight: 420),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: curated.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 4.0),
          itemBuilder: (context, index) {
            if (index == curated.length) {
              // Custom currency entry
              final isCustom = !curated.any((c) => c.code == settings.currency);
              return ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isCustom
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.add_rounded,
                    size: 20,
                    color: isCustom
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                title: Text(
                  isCustom ? 'Custom (${settings.currency})' : 'Custom Currency Code',
                  style: TextStyle(
                    fontWeight: isCustom ? FontWeight.bold : FontWeight.w500,
                    color: isCustom ? colorScheme.primary : colorScheme.onSurface,
                  ),
                ),
                subtitle: const Text('Enter any 3-letter currency (e.g. BRL, KRW, THB)'),
                trailing: isCustom
                    ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
                    : null,
                onTap: () {
                  AppHaptics.selectionClick();
                  Navigator.pop(context);
                  _showCustomCurrencyDialog(context, settings);
                },
              );
            }

            final info = curated[index];
            final isSelected = settings.currency.toUpperCase() == info.code;

            return ListTile(
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  info.symbol,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              title: Text(
                info.code,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                info.name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              trailing: isSelected
                  ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
                  : null,
              onTap: () {
                AppHaptics.selectionClick();
                settings.setCurrency(info.code);
                WidgetHelper.updateWidgetData();
                Navigator.pop(context);
              },
            );
          },
        ),
      ),
    );
  }

  void _showCustomCurrencyDialog(BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController(text: settings.currency);
    AppBottomSheet.show(
      context: context,
      title: 'Custom Currency',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter the 3-letter currency code or custom symbol you want to use for ledgers.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            maxLength: 5,
            decoration: InputDecoration(
              hintText: 'e.g. BRL, KRW, THB',
              labelText: 'Currency Code / Symbol',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  AppHaptics.selectionClick();
                  final val = controller.text.trim().toUpperCase();
                  if (val.isNotEmpty) {
                    settings.setCurrency(val);
                    WidgetHelper.updateWidgetData();
                  }
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showNotificationTextDialog(BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController(text: settings.discreetNotificationText);

    AppBottomSheet.show(
      context: context,
      title: 'Discreet Notification Text',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customize the discreet notification message for upcoming period predictions.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'e.g., Check the app',
              labelText: 'Alert Text',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  AppHaptics.selectionClick();
                  if (controller.text.trim().isNotEmpty) {
                    settings.setDiscreetNotificationText(controller.text.trim());
                  }
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getFrequencyLabel(String frequency) {
    switch (frequency) {
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      default:
        return 'Daily';
    }
  }

  String _formatLastBackupTime(String isoTime) {
    final dt = DateTime.tryParse(isoTime);
    if (dt == null) return 'Unknown';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  void _showFrequencyPicker(BuildContext context, SettingsProvider settings) {
    final options = [
      (label: 'Daily', value: 'daily', desc: 'Automatic backup generated every 24 hours'),
      (label: 'Weekly', value: 'weekly', desc: 'Automatic backup generated once per week'),
      (label: 'Monthly', value: 'monthly', desc: 'Automatic backup generated once per month'),
    ];

    AppBottomSheet.show(
      context: context,
      title: 'Backup Frequency',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final isSelected = settings.autoBackupFrequency == opt.value;
          final colorScheme = Theme.of(context).colorScheme;

          return ListTile(
            leading: Icon(
              Icons.schedule_outlined,
              color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            title: Text(
              opt.label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              opt.desc,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: isSelected
                ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
                : null,
            onTap: () async {
              AppHaptics.selectionClick();
              await settings.setAutoBackupFrequency(opt.value);
              await syncAutoBackupSchedule();
              if (context.mounted) Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showBackupLocationPicker(BuildContext context, SettingsProvider settings) {
    final colorScheme = Theme.of(context).colorScheme;
    AppBottomSheet.show(
      context: context,
      title: 'Backup Storage Location',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              Icons.security_outlined,
              color: settings.autoBackupPath == null ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            title: Text(
              'Secure App Storage (Default)',
              style: TextStyle(
                fontWeight: settings.autoBackupPath == null ? FontWeight.bold : FontWeight.w500,
                color: settings.autoBackupPath == null ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              'Always active & preserved by Google Cloud. Protected across OS updates.',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: settings.autoBackupPath == null
                ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
                : null,
            onTap: () async {
              AppHaptics.selectionClick();
              await settings.setAutoBackupPath(null);
              await syncAutoBackupSchedule();
              if (context.mounted) Navigator.pop(context);
            },
          ),
          ListTile(
            leading: Icon(
              Icons.folder_open_outlined,
              color: settings.autoBackupPath != null ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            title: Text(
              'Custom Folder Mirror (Dual-Save)',
              style: TextStyle(
                fontWeight: settings.autoBackupPath != null ? FontWeight.bold : FontWeight.w500,
                color: settings.autoBackupPath != null ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              settings.autoBackupPath ?? 'Also save an accessible copy to an external device folder',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: settings.autoBackupPath != null
                ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
                : null,
            onTap: () async {
              AppHaptics.selectionClick();
              if (context.mounted) Navigator.pop(context);
              AppLockScreen.ignoreNextResumeLock();
              final dir = await FilePicker.platform.getDirectoryPath();
              if (dir != null) {
                await settings.setAutoBackupPath(dir);
                await syncAutoBackupSchedule();
              }
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    AppLockScreen.ignoreNextResumeLock();
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  String _getTimeoutLabel(int seconds) {
    if (seconds == 0) return 'Immediately';
    if (seconds < 60) return '$seconds seconds';
    return '${seconds ~/ 60} minute${seconds >= 120 ? "s" : ""}';
  }

  void _showTimeoutPicker(BuildContext context, SettingsProvider settings) {
    final options = [
      (label: 'Immediately', value: 0, desc: 'Lock as soon as app leaves foreground'),
      (label: '10 seconds', value: 10, desc: 'Lock after 10s of background inactivity'),
      (label: '30 seconds', value: 30, desc: 'Lock after 30s of background inactivity'),
      (label: '1 minute', value: 60, desc: 'Lock after 1m of background inactivity'),
      (label: '5 minutes', value: 300, desc: 'Lock after 5m of background inactivity'),
    ];

    AppBottomSheet.show(
      context: context,
      title: 'Auto-Lock Timeout',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final isSelected = settings.appLockTimeout == opt.value;
          final colorScheme = Theme.of(context).colorScheme;

          return ListTile(
            leading: Icon(
              Icons.timer_outlined,
              color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            title: Text(
              opt.label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              opt.desc,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: isSelected
                ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
                : null,
            onTap: () {
              AppHaptics.selectionClick();
              settings.setAppLockTimeout(opt.value);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  void _showDefaultPaymentInfoDialog(BuildContext context, SettingsProvider settings) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController(text: settings.defaultPaymentInfo);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Default Payment Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your bank account, UPI ID, or mobile pay instructions to automatically attach to WhatsApp split reminders:',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. Bank: Commercial Bank\nAcc: 1234567890\nName: Alex',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await settings.setDefaultPaymentInfo(controller.text.trim());
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Payment details saved.')),
        );
      }
    }
  }

  void _showAccountNamingAndRoutingSheet(BuildContext context, SettingsProvider settings) {
    final acc1Controller = TextEditingController(text: settings.account1Name);
    final acc2Controller = TextEditingController(text: settings.account2Name);
    final routingMap = Map<String, String>.from(settings.categoryAccountRouting);

    Future<void> saveAndClose(BuildContext ctx) async {
      AppHaptics.mediumImpact();
      await settings.setAccount1Name(acc1Controller.text.trim());
      await settings.setAccount2Name(acc2Controller.text.trim());
      for (final cat in TransactionCategory.allNames) {
        await settings.setCategoryAccountRouting(cat, routingMap[cat]);
      }
      if (context.mounted) {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account settings and category routing saved.')),
        );
      }
    }

    AppBottomSheet.show(
      context: context,
      title: 'Account Names & Routing',
      actions: [
        FilledButton.tonal(
          onPressed: () => saveAndClose(context),
          child: const Text('Save'),
        ),
      ],
      child: StatefulBuilder(
        builder: (ctx, setModalState) {
          final cs = Theme.of(ctx).colorScheme;
          final tt = Theme.of(ctx).textTheme;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Customize presentation names for your dual accounts and assign default target accounts for categories.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppLayout.spaceL),

                // Account 1 Name
                Text('Account 1 (Daily Operating)', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: acc1Controller,
                  onChanged: (_) => setModalState(() {}),
                  decoration: InputDecoration(
                    hintText: 'e.g. Daily, Commercial Bank, Cash Wallet',
                    prefixIcon: const Icon(Icons.credit_card_outlined),
                    filled: true,
                    fillColor: cs.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppLayout.radiusM),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppLayout.spaceM),

                // Account 2 Name
                Text('Account 2 (Savings Vault)', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: acc2Controller,
                  onChanged: (_) => setModalState(() {}),
                  decoration: InputDecoration(
                    hintText: 'e.g. Savings, HNB Vault, Emergency Fund',
                    prefixIcon: const Icon(Icons.account_balance_outlined),
                    filled: true,
                    fillColor: cs.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppLayout.radiusM),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppLayout.spaceL),

                // Category Default Routing
                Text('Category Default Routing', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Transactions with these categories will default to the selected account.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppLayout.spaceS),
                ...TransactionCategory.allNames.map((cat) {
                  final currentAccount = routingMap[cat];
                  final catIcon = TransactionCategory.iconFor(cat);
                  final catColor = TransactionCategory.colorFor(cat);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(catIcon, size: 18, color: catColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(cat, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                        ),
                        SegmentedButton<String?>(
                          showSelectedIcon: false,
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          segments: [
                            const ButtonSegment<String?>(
                              value: null,
                              label: Text('Auto'),
                            ),
                            ButtonSegment<String?>(
                              value: 'daily',
                              label: Text(acc1Controller.text.trim().isNotEmpty ? acc1Controller.text.trim() : 'Daily'),
                            ),
                            ButtonSegment<String?>(
                              value: 'savings',
                              label: Text(acc2Controller.text.trim().isNotEmpty ? acc2Controller.text.trim() : 'Savings'),
                            ),
                          ],
                          selected: {currentAccount},
                          onSelectionChanged: (selected) {
                            AppHaptics.selectionClick();
                            setModalState(() {
                              final sel = selected.first;
                              if (sel == null) {
                                routingMap.remove(cat);
                              } else {
                                routingMap[cat] = sel;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: AppLayout.spaceXL),

                FilledButton(
                  onPressed: () => saveAndClose(ctx),
                  child: const Text('Save Settings'),
                ),
                const SizedBox(height: AppLayout.spaceM),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

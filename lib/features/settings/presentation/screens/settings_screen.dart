import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_card.dart';
import '../../../../core/ui/app_chip.dart';
import '../../../../core/ui/expressive_sliver_app_bar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../screens/changelog_screen.dart';
import '../../../../services/backup_service.dart';
import '../../../../services/notification_service.dart';
import '../../../../utils/app_route.dart';
import '../../../../widgets/bouncing_widget.dart';
import '../../../../widgets/settings_widgets.dart';
import '../../../finances/presentation/screens/category_management_screen.dart';
import '../../../finances/presentation/screens/sms_rules_screen.dart';
import '../../../finances/presentation/widgets/recurring_rules_sheet.dart';
import '../../../notes/presentation/screens/manage_tags_screen.dart';
import '../../../notes/presentation/widgets/note_migration_sheet.dart';
import '../../../sync/presentation/screens/p2p_sync_screen.dart';
import '../../data/settings_search_index.dart';
import '../../providers/settings_provider.dart';
import 'onboarding_screen.dart';
import 'sections/about_settings_screen.dart';
import 'sections/appearance_settings_screen.dart';
import 'sections/finances_settings_screen.dart';
import 'sections/notes_settings_screen.dart';
import 'sections/security_settings_screen.dart';
import 'sections/sync_backup_settings_screen.dart';
import 'settings_dialogs.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isSearching = _searchQuery.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          final searchResults = isSearching
              ? _buildSearchResults(context, settings)
              : <Widget>[];

          return SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                ExpressiveSliverAppBar(
                  titleText: AppLocalizations.of(context)?.settingsTitle ?? 'Settings',
                  showBackButton: true,
                ),

                // Search Bar Bar inside Header
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppLayout.spaceXL,
                      vertical: AppLayout.spaceS,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppLayout.spaceL,
                      vertical: AppLayout.spaceS,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppLayout.radiusMAX),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.4),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppLayout.spaceS),
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
                              hintText: '${AppLocalizations.of(context)?.settingsTitle ?? 'Settings'} / Search...',
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppLayout.spaceXL,
                    vertical: AppLayout.spaceM,
                  ),
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
                                // 0. Top Hero Dashboard Status Card
                                SettingsHeroCard(
                                  isAppLockEnabled: settings.appLockEnabled,
                                  isFinancialManagerEnabled: settings.showFinancialManager,
                                  isPeriodTrackerEnabled: settings.isPeriodTrackerEnabled,
                                  isAiEnabled: settings.isAiActive,
                                  autoBackupEnabled: settings.autoBackupEnabled,
                                  lastAutoBackupTimeFormatted: settings.lastAutoBackupTime != null
                                      ? SettingsDialogs.formatLastBackupTime(settings.lastAutoBackupTime!)
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
                                const SizedBox(height: AppLayout.spaceL),

                                // Section Header Label
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: AppLayout.spaceS,
                                    bottom: AppLayout.spaceM,
                                  ),
                                  child: Text(
                                    'Preferences & Workspaces',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),

                                // 1. Appearance & UI Hub Card
                                _buildDomainHubCard(
                                  context: context,
                                  title: 'Appearance & UI',
                                  subtitle: '${SettingsDialogs.getThemeLabel(settings.themeMode)} Mode • ${settings.useDynamicColor ? 'Dynamic Wallpaper' : 'Standard'} • ${SettingsDialogs.getLanguageDisplayName(settings.selectedLanguageCode)}',
                                  icon: Icons.palette_outlined,
                                  accentColor: colorScheme.primary,
                                  onTap: () => AppRoute.push(context, const AppearanceSettingsScreen()),
                                ),
                                const SizedBox(height: AppLayout.spaceM),

                                // 2. Notes & Editor Workspace Hub Card
                                _buildDomainHubCard(
                                  context: context,
                                  title: 'Notes & Editor Workspace',
                                  subtitle: '${settings.minimalEditorMode ? 'Minimal Toolbar' : 'Standard Writing'} • ${settings.showTagFilterBar ? 'Tags Active' : 'Clean List'} • ${settings.trashAutoPurgeDays <= 0 ? 'Purge Off' : '${settings.trashAutoPurgeDays}d Auto-Purge'}',
                                  icon: Icons.edit_note_rounded,
                                  accentColor: const Color(0xFFF59E0B),
                                  onTap: () => AppRoute.push(context, const NotesSettingsScreen()),
                                ),
                                const SizedBox(height: AppLayout.spaceM),

                                // 3. Finances & Health Modules Hub Card
                                _buildDomainHubCard(
                                  context: context,
                                  title: 'Finances & Health Modules',
                                  subtitle: 'Finances ${settings.showFinancialManager ? 'Active (${settings.currency})' : 'Disabled'} • Period Tracker ${settings.isPeriodTrackerEnabled ? 'Active' : 'Disabled'}',
                                  icon: Icons.apps_rounded,
                                  accentColor: const Color(0xFF10B981),
                                  onTap: () => AppRoute.push(context, const FinancesSettingsScreen()),
                                ),
                                const SizedBox(height: AppLayout.spaceM),

                                // 4. Privacy & Security Hub Card
                                _buildDomainHubCard(
                                  context: context,
                                  title: 'Privacy & Security',
                                  subtitle: 'App Lock ${settings.appLockEnabled ? 'Active (${SettingsDialogs.getTimeoutLabel(settings.appLockTimeout)})' : 'Disabled'} • ${settings.useBiometrics ? 'Biometrics' : 'PIN / Passcode'}',
                                  icon: Icons.security_outlined,
                                  accentColor: colorScheme.primary,
                                  onTap: () => AppRoute.push(context, const SecuritySettingsScreen()),
                                ),
                                const SizedBox(height: AppLayout.spaceM),

                                // 5. Data, Sync & Backups Hub Card
                                _buildDomainHubCard(
                                  context: context,
                                  title: 'Data, Sync & Backups',
                                  subtitle: 'P2P Device Sync • Encrypted JSON • ${settings.autoBackupEnabled ? 'Auto-Backup (${SettingsDialogs.getFrequencyLabel(settings.autoBackupFrequency)})' : 'Manual Backup'}',
                                  icon: Icons.cloud_sync_outlined,
                                  accentColor: const Color(0xFF0EA5E9),
                                  onTap: () => AppRoute.push(context, const SyncBackupSettingsScreen()),
                                ),
                                const SizedBox(height: AppLayout.spaceM),

                                // 6. About & Guides Hub Card
                                _buildDomainHubCard(
                                  context: context,
                                  title: 'About & Guides',
                                  subtitle: 'Everything App v2.46.0 • Changelog • Diagnostics & Setup',
                                  icon: Icons.info_outline_rounded,
                                  accentColor: colorScheme.onSurfaceVariant,
                                  onTap: () => AppRoute.push(context, const AboutSettingsScreen()),
                                ),

                                const SizedBox(height: AppLayout.fabBottomPadding),
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

  Widget _buildDomainHubCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return BouncingWidget(
      onTap: () {
        AppHaptics.selectionClick();
        onTap();
      },
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppLayout.spaceL,
          vertical: AppLayout.spaceM,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
              ),
              child: Icon(
                icon,
                color: accentColor,
                size: 24,
              ),
            ),
            const SizedBox(width: AppLayout.spaceL),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppLayout.spaceS),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              size: 22,
            ),
          ],
        ),
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

      final combinedKeywords = [
        ...registered.keywords,
        if (keywords != null) ...keywords,
      ];

      final matchTitle = title.toLowerCase().contains(query);
      final matchSubtitle = subtitle != null && subtitle.toLowerCase().contains(query);
      final matchCat = categoryName.toLowerCase().contains(query);
      final matchKeywords = combinedKeywords.any((k) => k.toLowerCase().contains(query));

      if (matchTitle || matchSubtitle || matchCat || matchKeywords) {
        items.add(tile);
      }
    }

    // 1. Appearance & UI
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
      'Restrained physical feedback for sliders, long-press, and actions',
    );
    addTile(
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
      'Appearance',
      'Text Scale',
      'Global font sizing',
    );
    addTile(
      SettingsTile(
        icon: Icons.translate_rounded,
        title: 'Language',
        subtitle: SettingsDialogs.getLanguageDisplayName(settings.selectedLanguageCode),
        valueBadge: SettingsDialogs.getLanguageBadge(settings.selectedLanguageCode),
        showArrow: true,
        onTap: () => SettingsDialogs.showLanguagePicker(context, settings),
      ),
      'Appearance',
      'Language',
      SettingsDialogs.getLanguageDisplayName(settings.selectedLanguageCode),
    );

    // 2. Notes & Editor
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
      SettingsSwitchTile(
        icon: Icons.tag_rounded,
        title: 'Tag Filter Bar',
        subtitle: 'Show quick tag filter pills at the top of the notes list',
        value: settings.showTagFilterBar,
        onChanged: settings.setShowTagFilterBar,
      ),
      'Features',
      'Tag Filter Bar',
      'Show quick tag filter pills at the top of the notes list',
    );
    addTile(
      SettingsSwitchTile(
        icon: Icons.border_color_outlined,
        title: 'Minimal Editor Mode',
        subtitle: 'Streamlined writing toolbar; secondary tools moved to menu',
        value: settings.minimalEditorMode,
        onChanged: settings.setMinimalEditorMode,
      ),
      'Features',
      'Minimal Editor Mode',
      'Streamlined writing toolbar; secondary tools moved to menu',
    );
    addTile(
      SettingsSwitchTile(
        icon: Icons.checklist_rtl_rounded,
        title: 'Collapse Completed Checklists',
        subtitle: 'Move finished to-do items to a bottom section',
        value: settings.moveCompletedChecklistsToBottom,
        onChanged: settings.setMoveCompletedChecklistsToBottom,
      ),
      'Features',
      'Collapse Completed Checklists',
      'Move finished to-do items to a bottom section',
    );
    addTile(
      SettingsSwitchTile(
        icon: Icons.celebration_outlined,
        title: 'Milestone Celebrations',
        subtitle: 'Calm celebrations when reaching savings goals and settling debts',
        value: settings.showMilestoneDelight,
        onChanged: settings.setShowMilestoneDelight,
      ),
      'Features',
      'Milestone Celebrations',
      'Calm celebrations when reaching savings goals and settling debts',
    );
    addTile(
      SettingsSwitchTile(
        icon: Icons.calendar_view_week_rounded,
        title: 'Days of Clarity Strip',
        subtitle: 'Visualize 14-day mindfulness activity without stressful streak countdowns',
        value: settings.showClarityMosaic,
        onChanged: settings.setShowClarityMosaic,
      ),
      'Features',
      'Days of Clarity Strip',
      'Visualize 14-day mindfulness activity without stressful streak countdowns',
    );
    addTile(
      SettingsTile(
        icon: Icons.auto_delete_outlined,
        title: 'Trash Auto-Purge',
        subtitle: 'Automatic deletion schedule for trash',
        valueBadge: settings.trashAutoPurgeDays <= 0
            ? 'Disabled'
            : '${settings.trashAutoPurgeDays} Days',
        showArrow: true,
        onTap: () => SettingsDialogs.showTrashPurgeDialog(context, settings),
      ),
      'Features',
      'Trash Auto-Purge',
      'Automatic deletion schedule for trash',
    );
    addTile(
      SettingsTile(
        icon: Icons.import_contacts_rounded,
        title: 'Import & Migrate Notes',
        subtitle: 'Import from Google Keep Takeout, Markdown, or text files',
        showArrow: true,
        onTap: () => NoteMigrationSheet.show(context),
      ),
      'Features',
      'Import & Migrate Notes',
      'Import from Google Keep Takeout, Markdown, or text files',
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

    // 3. Finances & Modules
    addTile(
      SettingsSwitchTile(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Financial Manager',
        subtitle: 'Expense tracking, SMS bank ledger & budgets',
        value: settings.showFinancialManager,
        onChanged: settings.setShowFinancialManager,
      ),
      'Finances',
      'Financial Manager',
      'Expense tracking, SMS bank ledger & budgets',
    );
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
    if (settings.showFinancialManager) {
      addTile(
        SettingsTile(
          icon: Icons.currency_exchange_outlined,
          title: 'Currency',
          subtitle: 'Base ledger currency symbol',
          valueBadge: settings.currency,
          showArrow: true,
          onTap: () => SettingsDialogs.showCurrencyPicker(context, settings),
        ),
        'Finances',
        'Currency',
        'Base ledger currency symbol',
      );
      addTile(
        SettingsSwitchTile(
          icon: Icons.sms_outlined,
          title: 'SMS Bank Import',
          subtitle: 'Automatically import and parse transactions from bank SMS',
          value: settings.enableSmsImport,
          onChanged: settings.setEnableSmsImport,
        ),
        'Finances',
        'SMS Bank Import',
        'Automatically import and parse transactions from bank SMS',
      );
      if (settings.enableSmsImport) {
        addTile(
          SettingsTile(
            icon: Icons.mark_chat_unread_outlined,
            title: 'SMS & Bank Automation Rules',
            subtitle: 'Auto-sync, import rules, sender blocklist & parser testing',
            showArrow: true,
            onTap: () => AppRoute.push(context, const SmsRulesScreen()),
          ),
          'Finances',
          'SMS & Bank Automation Rules',
          'Auto-sync, import rules, sender blocklist & parser testing',
        );
      }
      addTile(
        SettingsSwitchTile(
          icon: Icons.donut_large_outlined,
          title: 'Budgets & Financial Goals',
          subtitle: 'Monthly spending limits, analytics chart deck & visual targets',
          value: settings.enableBudgetsAndAnalytics,
          onChanged: settings.setEnableBudgetsAndAnalytics,
        ),
        'Finances',
        'Budgets & Financial Goals',
        'Monthly spending limits, analytics chart deck & visual targets',
      );
      addTile(
        SettingsTile(
          icon: Icons.category_outlined,
          title: 'Categories & Budgets',
          subtitle: 'Customise keywords, budget allocations & colors',
          showArrow: true,
          onTap: () => AppRoute.push(context, const CategoryManagementScreen()),
        ),
        'Finances',
        'Categories & Budgets',
        'Customise keywords, budget allocations & colors',
      );
      addTile(
        SettingsSwitchTile(
          icon: Icons.event_repeat_outlined,
          title: 'Recurring Subscriptions & Rules',
          subtitle: 'Track repeated bills, periodic income & salary reminders',
          value: settings.enableRecurringRules,
          onChanged: settings.setEnableRecurringRules,
        ),
        'Finances',
        'Recurring Subscriptions & Rules',
        'Track repeated bills, periodic income & salary reminders',
      );
      if (settings.enableRecurringRules) {
        addTile(
          SettingsTile(
            icon: Icons.edit_calendar_outlined,
            title: 'Manage Subscriptions',
            subtitle: 'Manage repeating bills, salaries & automated rules',
            showArrow: true,
            onTap: () => RecurringRulesSheet.show(
              context: context,
              currency: settings.currency,
              onRulesUpdated: () {},
            ),
          ),
          'Finances',
          'Manage Subscriptions',
          'Manage repeating bills, salaries & automated rules',
        );
      }
      addTile(
        SettingsSwitchTile(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Savings Vault & Dual Accounts',
          subtitle: 'Separate daily operating cash flow from long-term savings',
          value: settings.enableSavingsVault,
          onChanged: settings.setEnableSavingsVault,
        ),
        'Finances',
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
            onTap: () => SettingsDialogs.showAccountNamingAndRoutingSheet(context, settings),
          ),
          'Finances',
          'Account Names & Routing',
          '${settings.account1Name} & ${settings.account2Name} • Category defaults',
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
        'Finances',
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
            onTap: () => SettingsDialogs.showDefaultPaymentInfoDialog(context, settings),
          ),
          'Finances',
          'Default Payment Details',
          'Set bank / mobile pay details for WhatsApp split reminders',
        );
      }
    }

    // 4. Privacy & Security
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
          subtitle: 'Inactivity delay before locking',
          valueBadge: SettingsDialogs.getTimeoutLabel(settings.appLockTimeout),
          showArrow: true,
          onTap: () => SettingsDialogs.showTimeoutPicker(context, settings),
        ),
        'Security',
        'Auto-Lock Timeout',
        'Inactivity delay before locking',
      );
    }

    // 5. Data & Sync
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
          icon: Icons.cloud_sync_outlined,
          title: 'Automatic Backups',
          subtitle: 'Schedule regular encrypted local backups',
          value: settings.autoBackupEnabled,
          onChanged: (value) async {
            await settings.setAutoBackupEnabled(value);
            await syncAutoBackupSchedule();
          },
        ),
        'Data',
        'Automatic Backups',
        'Schedule regular encrypted local backups',
      );
      if (settings.autoBackupEnabled) {
        addTile(
          SettingsTile(
            icon: Icons.schedule_outlined,
            title: 'Backup Frequency',
            subtitle: 'Frequency of automated backup tasks',
            valueBadge: SettingsDialogs.getFrequencyLabel(settings.autoBackupFrequency),
            showArrow: true,
            onTap: () => SettingsDialogs.showFrequencyPicker(context, settings),
          ),
          'Data',
          'Backup Frequency',
          'Frequency of automated backup tasks',
        );
        addTile(
          SettingsTile(
            icon: Icons.folder_outlined,
            title: 'Backup Location',
            subtitle: settings.autoBackupPath ?? 'Secure App Storage (Resilient)',
            showArrow: true,
            onTap: () => SettingsDialogs.showBackupLocationPicker(context, settings),
          ),
          'Data',
          'Backup Location',
          settings.autoBackupPath ?? 'Secure App Storage (Resilient)',
        );
      }
    }

    // 6. About
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
        onTap: () => SettingsDialogs.launchExternalUrl('https://play.google.com/store/apps/details?id=com.saadhjawwadh.notebook'),
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
}

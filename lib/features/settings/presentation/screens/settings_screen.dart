import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_card.dart';
import '../../../../core/ui/app_chip.dart';
import '../../../../core/ui/expressive_sliver_app_bar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../utils/app_route.dart';
import '../../../../widgets/bouncing_widget.dart';
import '../../../../widgets/settings_widgets.dart';
import '../../../finances/presentation/screens/category_management_screen.dart';
import '../../../finances/presentation/screens/sms_rules_screen.dart';
import '../../../notes/presentation/screens/manage_tags_screen.dart';
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
  String _appVersion = '';

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
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() {
          _appVersion = 'v${info.version}';
        });
      }
    });
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
    final l10n = AppLocalizations.of(context);

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
                  titleText: l10n?.settingsTitle ?? 'Settings',
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
                              hintText: '${l10n?.settingsTitle ?? 'Settings'} / ${l10n?.search ?? 'Search'}...',
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
                          Semantics(
                            button: true,
                            label: 'Clear search',
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                AppHaptics.selectionClick();
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _selectedSearchCategory = 'All';
                                });
                              },
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 36,
                                ),
                                child: const Align(
                                  alignment: Alignment.centerRight,
                                  child: Icon(Icons.close_rounded, size: 18),
                                ),
                              ),
                            ),
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
                                          l10n?.noSettingsFound(_searchQuery) ?? 'No settings matching "$_searchQuery"',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          l10n?.quickSuggestions ?? 'Quick suggestions:',
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
                              duration: AppLayout.animShort,
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
                                      ? SettingsDialogs.formatLastBackupTime(context, settings.lastAutoBackupTime!)
                                      : null,
                                  currentThemeMode: settings.themeMode,
                                  onThemeModeChanged: settings.setThemeMode,
                                  onAppLockTap: () {
                                    AppHaptics.selectionClick();
                                    AppRoute.push(context, const SecuritySettingsScreen());
                                  },
                                  onFinancesTap: () {
                                    AppHaptics.selectionClick();
                                    AppRoute.push(context, const FinancesSettingsScreen());
                                  },
                                  onHealthTap: () {
                                    AppHaptics.selectionClick();
                                    AppRoute.push(context, const FinancesSettingsScreen());
                                  },
                                  onAiTap: () {
                                    AppHaptics.selectionClick();
                                    AppRoute.push(context, const NotesSettingsScreen());
                                  },
                                  onBackupTap: () {
                                    AppHaptics.selectionClick();
                                    AppRoute.push(context, const SyncBackupSettingsScreen());
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
                                    l10n?.preferencesAndWorkspaces ?? 'Preferences & Workspaces',
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
                                  title: l10n?.appearance ?? 'Appearance & UI',
                                  subtitle: () {
                                    final themeLabel = settings.themeMode == ThemeMode.system
                                        ? 'Auto Theme'
                                        : '${SettingsDialogs.getThemeLabel(settings.themeMode)} Theme';
                                    final colorLabel = settings.useDynamicColor ? 'Dynamic Color' : 'Standard Palette';
                                    final langLabel = settings.selectedLanguageCode == 'system'
                                        ? 'System Language'
                                        : SettingsDialogs.getLanguageDisplayName(settings.selectedLanguageCode);
                                    return '$themeLabel • $colorLabel • $langLabel';
                                  }(),
                                  icon: Icons.palette_outlined,
                                  accentColor: colorScheme.primary,
                                  onTap: () => AppRoute.push(context, const AppearanceSettingsScreen()),
                                ),
                                const SizedBox(height: AppLayout.spaceM),

                                // 2. Notes & Editor Workspace Hub Card
                                _buildDomainHubCard(
                                  context: context,
                                  title: l10n?.notesAndEditorWorkspace ?? 'Notes & Editor Workspace',
                                  subtitle: '${settings.minimalEditorMode ? 'Minimal Toolbar' : 'Standard Writing'} • ${settings.showTagFilterBar ? 'Tags Active' : 'Clean List'} • ${settings.trashAutoPurgeDays <= 0 ? 'Purge Off' : '${settings.trashAutoPurgeDays}d Auto-Purge'}',
                                  icon: Icons.edit_note_rounded,
                                  accentColor: const Color(0xFFF59E0B),
                                  onTap: () => AppRoute.push(context, const NotesSettingsScreen()),
                                ),
                                const SizedBox(height: AppLayout.spaceM),

                                // 3. Finances & Health Modules Hub Card
                                _buildDomainHubCard(
                                  context: context,
                                  title: l10n?.financesAndHealthModules ?? 'Finances & Health Modules',
                                  subtitle: 'Finances ${settings.showFinancialManager ? 'Active (${settings.currencySymbol})' : 'Disabled'} • Period Tracker ${settings.isPeriodTrackerEnabled ? 'Active' : 'Disabled'}',
                                  icon: Icons.apps_rounded,
                                  accentColor: const Color(0xFF10B981),
                                  onTap: () => AppRoute.push(context, const FinancesSettingsScreen()),
                                ),
                                const SizedBox(height: AppLayout.spaceM),

                                // 4. Privacy & Security Hub Card
                                _buildDomainHubCard(
                                  context: context,
                                  title: l10n?.privacyAndSecurity ?? l10n?.security ?? 'Privacy & Security',
                                  subtitle: 'App Lock ${settings.appLockEnabled ? 'Active (${SettingsDialogs.getTimeoutLabel(context, settings.appLockTimeout)})' : 'Disabled'} • ${settings.useBiometrics ? 'Biometrics' : 'PIN / Passcode'}',
                                  icon: Icons.security_outlined,
                                  accentColor: colorScheme.primary,
                                  onTap: () => AppRoute.push(context, const SecuritySettingsScreen()),
                                ),
                                const SizedBox(height: AppLayout.spaceM),

                                // 5. Data, Sync & Backups Hub Card
                                _buildDomainHubCard(
                                  context: context,
                                  title: l10n?.syncAndBackups ?? l10n?.backupRestore ?? 'Data, Sync & Backups',
                                  subtitle: 'P2P Device Sync • Encrypted JSON • ${settings.autoBackupEnabled ? 'Auto-Backup (${SettingsDialogs.getFrequencyLabel(settings.autoBackupFrequency)})' : 'Manual Backup'}',
                                  icon: Icons.cloud_sync_outlined,
                                  accentColor: const Color(0xFF0EA5E9),
                                  onTap: () => AppRoute.push(context, const SyncBackupSettingsScreen()),
                                ),
                                const SizedBox(height: AppLayout.spaceM),

                                // 6. About & Guides Hub Card
                                _buildDomainHubCard(
                                  context: context,
                                  title: l10n?.aboutAndDeviceAi ?? l10n?.about ?? 'About & Guides',
                                  subtitle: _appVersion.isNotEmpty
                                      ? 'Everything App $_appVersion • Changelog • Diagnostics'
                                      : 'Changelog • Diagnostics & Setup Guides',
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
    final results = SettingsSearchIndex.search(
      _searchQuery,
      section: _selectedSearchCategory,
    );

    if (results.isEmpty) return [];

    final colorScheme = Theme.of(context).colorScheme;
    final sectionMeta = <String, ({String label, IconData icon, Color color})>{
      'Appearance': (
        label: 'Appearance & UI',
        icon: Icons.palette_outlined,
        color: colorScheme.primary,
      ),
      'Features': (
        label: 'Features & Modules',
        icon: Icons.dashboard_customize_outlined,
        color: colorScheme.secondary,
      ),
      'Finances': (
        label: 'Financial Manager & SMS',
        icon: Icons.account_balance_wallet_outlined,
        color: const Color(0xFF2E7D32),
      ),
      'Security': (
        label: 'Privacy & Security',
        icon: Icons.security_outlined,
        color: colorScheme.primary,
      ),
      'Data': (
        label: 'Data, Sync & Backups',
        icon: Icons.cloud_sync_outlined,
        color: const Color(0xFF0EA5E9),
      ),
      'About': (
        label: 'About & Diagnostics',
        icon: Icons.info_outline_rounded,
        color: colorScheme.onSurfaceVariant,
      ),
    };

    final groupedItems = <String, List<SettingsIndexItem>>{};
    for (final item in results) {
      groupedItems.putIfAbsent(item.section, () => []).add(item);
    }

    return groupedItems.entries.map((entry) {
      final meta = sectionMeta[entry.key] ??
          (
            label: entry.key,
            icon: Icons.settings_outlined,
            color: colorScheme.primary,
          );
      return SettingsSection(
        title: '${meta.label} (${entry.value.length})',
        icon: meta.icon,
        accentColor: meta.color,
        children: entry.value.map((item) {
          return SettingsTile(
            icon: item.icon,
            title: item.title,
            subtitle: item.subtitle,
            showArrow: true,
            onTap: () => _navigateToSetting(context, item, settings),
          );
        }).toList(),
      );
    }).toList();
  }

  void _navigateToSetting(BuildContext context, SettingsIndexItem item, SettingsProvider settings) {
    AppHaptics.selectionClick();
    switch (item.section.toLowerCase()) {
      case 'appearance':
        AppRoute.push(context, const AppearanceSettingsScreen());
        break;
      case 'features':
        if (item.id == 'manage_tags') {
          AppRoute.push(context, const ManageTagsScreen());
        } else {
          AppRoute.push(context, const NotesSettingsScreen());
        }
        break;
      case 'finances':
        if (item.id == 'sms_rules') {
          AppRoute.push(context, const SmsRulesScreen());
        } else if (item.id == 'categories') {
          AppRoute.push(context, const CategoryManagementScreen());
        } else {
          AppRoute.push(context, const FinancesSettingsScreen());
        }
        break;
      case 'security':
        AppRoute.push(context, const SecuritySettingsScreen());
        break;
      case 'data':
        if (item.id == 'p2p_sync') {
          AppRoute.push(context, const P2pSyncScreen());
        } else {
          AppRoute.push(context, const SyncBackupSettingsScreen());
        }
        break;
      case 'about':
        if (item.id == 'onboarding_replay') {
          AppRoute.push(context, const OnboardingScreen());
        } else {
          AppRoute.push(context, const AboutSettingsScreen());
        }
        break;
      default:
        break;
    }
  }
}

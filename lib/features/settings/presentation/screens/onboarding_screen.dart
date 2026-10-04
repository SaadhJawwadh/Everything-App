import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/services/app_haptics.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_card.dart';
import '../../../../widgets/bouncing_widget.dart';
import '../../providers/settings_provider.dart';
import '../../../../providers/note_provider.dart';
import '../../../sync/presentation/widgets/qr_scanner_dialog.dart';
import '../../../sync/providers/p2p_sync_provider.dart';
import '../../../sync/presentation/screens/p2p_sync_screen.dart';
import '../../../finances/presentation/screens/sms_rules_screen.dart';
import '../../../notes/presentation/widgets/note_migration_sheet.dart';

/// Full-Screen Interactive Onboarding Wizard
class OnboardingScreen extends StatefulWidget {
  final bool isReplay;

  const OnboardingScreen({
    super.key,
    this.isReplay = false,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalPages = 5;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    AppHaptics.selectionClick();
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: AppLayout.animDefault,
        curve: AppLayout.curveFast,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _previousPage() {
    AppHaptics.selectionClick();
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: AppLayout.animDefault,
        curve: AppLayout.curveFast,
      );
    }
  }

  void _finishOnboarding() async {
    final settings = context.read<SettingsProvider>();
    AppHaptics.mediumImpact();
    await settings.setHasSeenOnboarding(true);
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      await settings.setLastSeenVersion(packageInfo.version);
    } catch (_) {}

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.maxContentWidth),
            child: Column(
              children: [
                // Top Action & Progress Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppLayout.spaceXL,
                    vertical: AppLayout.spaceM,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Replay Tag / Step Progress Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppLayout.spaceM,
                          vertical: AppLayout.spaceXS,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(AppLayout.radiusS),
                        ),
                        child: Text(
                          widget.isReplay
                              ? 'Step ${_currentPage + 1} of $_totalPages'
                              : 'Welcome ${_currentPage + 1}/$_totalPages',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      // Skip / Close Button
                      TextButton(
                        onPressed: _finishOnboarding,
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                        ),
                        child: Text(
                          _currentPage == _totalPages - 1 ? 'Done' : 'Skip',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Page View Content
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    children: [
                      _buildWelcomeSlide(theme),
                      _buildPersonalizationSlide(theme),
                      _buildModulesSlide(theme),
                      _buildAiSlide(theme),
                      _buildTipsSlide(theme),
                    ],
                  ),
                ),

                // Bottom Controls: Page Indicators & Navigation Buttons
                Padding(
                  padding: const EdgeInsets.all(AppLayout.spaceXL),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button (when page > 0)
                      AnimatedOpacity(
                        duration: AppLayout.animShort,
                        opacity: _currentPage > 0 ? 1.0 : 0.0,
                        child: IgnorePointer(
                          ignoring: _currentPage == 0,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                            child: IconButton.outlined(
                              onPressed: _previousPage,
                              icon: const Icon(Icons.arrow_back_rounded),
                              tooltip: 'Back',
                            ),
                          ),
                        ),
                      ),

                      // Animated Page Indicator Dots
                      Row(
                        children: List.generate(_totalPages, (index) {
                          final isActive = index == _currentPage;
                          return AnimatedContainer(
                            duration: AppLayout.animShort,
                            margin: const EdgeInsets.only(right: AppLayout.spaceS),
                            width: isActive ? 28 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant.withValues(alpha: isDark ? 0.3 : 0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),

                      // Primary Action Button (Next / Get Started)
                      BouncingWidget(
                        onTap: _nextPage,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 48, minWidth: 100),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppLayout.spaceXL,
                              vertical: AppLayout.spaceM,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                              boxShadow: AppLayout.softShadow(context),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _currentPage == _totalPages - 1 ? 'Get Started' : 'Next',
                                  style: TextStyle(
                                    color: theme.colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: AppLayout.spaceS),
                                Icon(
                                  _currentPage == _totalPages - 1
                                      ? Icons.check_circle_rounded
                                      : Icons.arrow_forward_rounded,
                                  color: theme.colorScheme.onPrimary,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Page 1: Welcome & Vision ---
  Widget _buildWelcomeSlide(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppLayout.spaceXL),
      child: Column(
        children: [
          const SizedBox(height: AppLayout.spaceL),
          // Circle App Logo
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.note_alt_rounded,
              color: theme.colorScheme.onPrimary,
              size: 52,
            ),
          ),
          const SizedBox(height: AppLayout.spaceXXL),
          Text(
            'Welcome to Everything App',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppLayout.spaceM),
          Text(
            'Your minimalist, private, offline-first workspace. Write notes, track finances, and manage your health seamlessly.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppLayout.spaceXXL),
          // Device Setup Mode Selection
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'How would you like to set up this device?',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: AppLayout.spaceS),
          BouncingWidget(
            onTap: _nextPage,
            child: AppCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppLayout.spaceS),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.phone_android_rounded, color: theme.colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: AppLayout.spaceM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Primary Device (New Notebook)', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text('Set up as main device. Create notes here to sync to other devices.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 16, color: theme.colorScheme.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppLayout.spaceS),
          BouncingWidget(
            onTap: () async {
              final scanned = await Navigator.push<String>(
                context,
                MaterialPageRoute(builder: (_) => const QrScannerScreen()),
              );
              if (scanned != null && scanned.isNotEmpty && mounted) {
                try {
                  final map = json.decode(scanned) as Map<String, dynamic>;
                  final pairCode = map['code']?.toString() ?? scanned;
                  final ip = map['ip']?.toString();
                  if (ip != null) {
                    final syncProvider = Provider.of<P2pSyncProvider>(context, listen: false);
                    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
                    await syncProvider.pairNewDevice(
                      deviceName: map['name']?.toString() ?? 'Primary Phone',
                      pairCode: pairCode,
                      targetIp: ip,
                      targetPort: map['port'] is int ? map['port'] as int : int.tryParse('${map['port']}') ?? 8765,
                      remoteDeviceId: map['deviceId']?.toString(),
                      role: 'SECONDARY',
                    );
                    await syncProvider.syncBiDirectional(
                      onCompleted: () {
                        noteProvider.refreshNotes();
                      },
                    );
                    _finishOnboarding();
                  }
                } catch (_) {}
              }
            },
            child: AppCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppLayout.spaceS),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.qr_code_scanner_rounded, color: theme.colorScheme.onSecondaryContainer),
                  ),
                  const SizedBox(width: AppLayout.spaceM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pair & Import from Primary Device', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text('Scan Primary device QR code to pull notes, ledgers, and settings instantly.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Icon(Icons.qr_code_scanner_rounded, size: 20, color: theme.colorScheme.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppLayout.spaceS),
          BouncingWidget(
            onTap: () => NoteMigrationSheet.show(context),
            child: AppCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppLayout.spaceS),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.import_contacts_rounded, color: theme.colorScheme.onTertiaryContainer),
                  ),
                  const SizedBox(width: AppLayout.spaceM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Migrate from Google Keep or Markdown', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text('Import Takeout ZIPs directly with pre-selected link, clean headings & undo.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 16, color: theme.colorScheme.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppLayout.spaceXL),
          _buildFeatureCard(
            theme,
            icon: Icons.shield_outlined,
            title: '100% Private & Offline',
            desc: 'Your data is encrypted locally using SQLCipher. Zero cloud lock-in.',
          ),
          const SizedBox(height: AppLayout.spaceM),
          _buildFeatureCard(
            theme,
            icon: Icons.edit_note_rounded,
            title: 'Rich WYSIWYG Notes & Story Studio',
            desc: 'Format text with bold, italic, code blocks, checklists, voice notes, and export high-res social Story Cards.',
          ),
          const SizedBox(height: AppLayout.spaceM),
          _buildFeatureCard(
            theme,
            icon: Icons.grid_view_rounded,
            title: 'Modular Ecosystem',
            desc: 'Enable or disable finance tracking and health features according to your workflow.',
          ),
        ],
      ),
    );
  }

  // --- Page 2: Personalization & Theme (Interactive Live Preview) ---
  Widget _buildPersonalizationSlide(ThemeData theme) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppLayout.spaceXL),
          child: Column(
            children: [
              const SizedBox(height: AppLayout.spaceM),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.palette_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 30,
                ),
              ),
              const SizedBox(height: AppLayout.spaceL),
              Text(
                'Personalize Your Look',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppLayout.spaceXS),
              Text(
                'Select your preferred appearance mode. Changes apply immediately in real-time.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppLayout.spaceL),

              // Theme Mode Options
              AppCard(
                padding: AppLayout.paddingAllM,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Theme Mode',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppLayout.spaceM),
                    Row(
                      children: [
                        _buildThemeOptionTile(
                          theme,
                          title: 'System',
                          icon: Icons.brightness_auto_rounded,
                          isSelected: settings.themeMode == ThemeMode.system,
                          onTap: () => settings.setThemeMode(ThemeMode.system),
                        ),
                        const SizedBox(width: AppLayout.spaceS),
                        _buildThemeOptionTile(
                          theme,
                          title: 'Light',
                          icon: Icons.light_mode_rounded,
                          isSelected: settings.themeMode == ThemeMode.light,
                          onTap: () => settings.setThemeMode(ThemeMode.light),
                        ),
                        const SizedBox(width: AppLayout.spaceS),
                        _buildThemeOptionTile(
                          theme,
                          title: 'Dark',
                          icon: Icons.dark_mode_rounded,
                          isSelected: settings.themeMode == ThemeMode.dark,
                          onTap: () => settings.setThemeMode(ThemeMode.dark),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppLayout.spaceS),

              // Dynamic Color & Haptics Grouped Card
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppLayout.spaceL,
                  vertical: AppLayout.spaceXS,
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        Icons.color_lens_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      title: Text(
                        'Material You Dynamic Colors',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Extract colors dynamically from your device wallpaper (Android 12+).',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      value: settings.useDynamicColor,
                      onChanged: (val) {
                        AppHaptics.selectionClick();
                        settings.setUseDynamicColor(val);
                      },
                    ),
                    Divider(
                      height: 1,
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        Icons.vibration_rounded,
                        color: theme.colorScheme.secondary,
                      ),
                      title: Text(
                        'Tactile Haptics',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Restrained physical micro-feedback for sliders, toggles, and actions.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      value: settings.enableHaptics,
                      onChanged: (val) {
                        if (val) {
                          AppHaptics.mediumImpact();
                        }
                        settings.setEnableHaptics(val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppLayout.spaceS),

              // App Language Choice Card
              AppCard(
                padding: AppLayout.paddingAllL,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.language_rounded, color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: AppLayout.spaceM),
                        Expanded(
                          child: Text(
                            'App Language',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppLayout.spaceXS),
                    Text(
                      'Choose your language. Updates immediately across all tabs and tools.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppLayout.spaceM),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildLanguageChip(theme, 'System', 'system', settings),
                          _buildLanguageChip(theme, 'English', 'en', settings),
                          _buildLanguageChip(theme, 'தமிழ்', 'ta', settings),
                          _buildLanguageChip(theme, 'Español', 'es', settings),
                          _buildLanguageChip(theme, 'Português', 'pt', settings),
                          _buildLanguageChip(theme, 'Deutsch', 'de', settings),
                          _buildLanguageChip(theme, 'Français', 'fr', settings),
                          _buildLanguageChip(theme, '中文', 'zh', settings),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Page 3: Modular Powerups (Interactive Module Toggles) ---
  Widget _buildModulesSlide(ThemeData theme) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppLayout.spaceXL),
          child: Column(
            children: [
              const SizedBox(height: AppLayout.spaceL),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.extension_outlined,
                  color: theme.colorScheme.onSecondaryContainer,
                  size: 32,
                ),
              ),
              const SizedBox(height: AppLayout.spaceXL),
              Text(
                'Modular Powerups',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppLayout.spaceS),
              Text(
                'Activate specialized modules now or toggle them anytime in Settings.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppLayout.spaceXL),

              // Notes & Writing Experience Modular Options
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppLayout.spaceL,
                  vertical: AppLayout.spaceS,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.edit_note_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: AppLayout.spaceM),
                        Expanded(
                          child: Text(
                            'Notes & Writing Experience',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppLayout.spaceXS),
                    Text(
                      'Tailor your writing space. Keep it feature-packed or streamline for pure focus.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppLayout.spaceM),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        Icons.tag_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      title: Text(
                        'Tag Filter Bar',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Show quick tag filter carousel at the top of notes list.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      value: settings.showTagFilterBar,
                      onChanged: (val) {
                        AppHaptics.selectionClick();
                        settings.setShowTagFilterBar(val);
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        Icons.edit_outlined,
                        color: theme.colorScheme.secondary,
                        size: 20,
                      ),
                      title: Text(
                        'Minimal Editor Mode',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Streamlined writing dock; secondary tools tucked in top menu.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      value: settings.minimalEditorMode,
                      onChanged: (val) {
                        AppHaptics.selectionClick();
                        settings.setMinimalEditorMode(val);
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        Icons.calendar_view_week_rounded,
                        color: theme.colorScheme.tertiary,
                        size: 20,
                      ),
                      title: Text(
                        'Days of Clarity Strip',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Visualize 14-day mindfulness progression without stressful streak countdowns.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      value: settings.showClarityMosaic,
                      onChanged: (val) {
                        AppHaptics.selectionClick();
                        settings.setShowClarityMosaic(val);
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        Icons.checklist_rtl_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      title: Text(
                        'Collapse Completed Checklists',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Move finished to-do items to a bottom section.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      value: settings.moveCompletedChecklistsToBottom,
                      onChanged: (val) {
                        AppHaptics.selectionClick();
                        settings.setMoveCompletedChecklistsToBottom(val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppLayout.spaceM),

              // Finance Module Toggle Card
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppLayout.spaceL,
                  vertical: AppLayout.spaceS,
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(
                    Icons.account_balance_wallet_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Financial Manager',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppLayout.spaceS),
                      if (settings.showFinancialManager)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Active',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    'Track expenses, dual bank accounts (Daily & Savings), interactive donut charts, budgets, and bank SMS auto-import.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  value: settings.showFinancialManager,
                  onChanged: (val) {
                    AppHaptics.selectionClick();
                    settings.setShowFinancialManager(val);
                  },
                ),
              ),
              if (settings.showFinancialManager) ...[
                const SizedBox(height: AppLayout.spaceS),
                AppCard(
                  margin: const EdgeInsets.only(left: AppLayout.spaceL),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppLayout.spaceL,
                    vertical: AppLayout.spaceXS,
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(
                      Icons.sms_outlined,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    title: Text(
                      'SMS Bank Import',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Automatically parse bank alerts into transactions.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    value: settings.enableSmsImport,
                    onChanged: (val) {
                      AppHaptics.selectionClick();
                      settings.setEnableSmsImport(val);
                    },
                  ),
                ),
                if (settings.enableSmsImport) ...[
                  const SizedBox(height: AppLayout.spaceS),
                  AppCard(
                    margin: const EdgeInsets.only(left: AppLayout.spaceL),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppLayout.spaceL,
                      vertical: AppLayout.spaceXS,
                    ),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        Icons.sync_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      title: Text(
                        'Auto SMS Background Sync',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Non-blocking background sync for bank debit/credit notifications.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      value: settings.dailySyncEnabled,
                      onChanged: (val) {
                        AppHaptics.selectionClick();
                        settings.setDailySyncEnabled(val);
                      },
                    ),
                  ),
                ],
                const SizedBox(height: AppLayout.spaceS),
                AppCard(
                  margin: const EdgeInsets.only(left: AppLayout.spaceL),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppLayout.spaceL,
                    vertical: AppLayout.spaceXS,
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(
                      Icons.donut_large_outlined,
                      color: theme.colorScheme.tertiary,
                      size: 20,
                    ),
                    title: Text(
                      'Budgets & Visual Analytics',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Monthly category spending limits and interactive visual analytics.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    value: settings.enableBudgetsAndAnalytics,
                    onChanged: (val) {
                      AppHaptics.selectionClick();
                      settings.setEnableBudgetsAndAnalytics(val);
                    },
                  ),
                ),
                const SizedBox(height: AppLayout.spaceS),
                AppCard(
                  margin: const EdgeInsets.only(left: AppLayout.spaceL),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppLayout.spaceL,
                    vertical: AppLayout.spaceXS,
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(
                      Icons.event_repeat_outlined,
                      color: theme.colorScheme.secondary,
                      size: 20,
                    ),
                    title: Text(
                      'Recurring Subscriptions',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Track repeating bills, periodic income & payment reminders.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    value: settings.enableRecurringRules,
                    onChanged: (val) {
                      AppHaptics.selectionClick();
                      settings.setEnableRecurringRules(val);
                    },
                  ),
                ),
                const SizedBox(height: AppLayout.spaceS),
                AppCard(
                  margin: const EdgeInsets.only(left: AppLayout.spaceL),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppLayout.spaceL,
                    vertical: AppLayout.spaceXS,
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(
                      Icons.account_balance_wallet_outlined,
                      color: theme.colorScheme.secondary,
                      size: 20,
                    ),
                    title: Text(
                      'Savings Vault & Dual Accounts',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Separate daily cash flow from long-term savings.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    value: settings.enableSavingsVault,
                    onChanged: (val) {
                      AppHaptics.selectionClick();
                      settings.setEnableSavingsVault(val);
                    },
                  ),
                ),
                const SizedBox(height: AppLayout.spaceS),
                AppCard(
                  margin: const EdgeInsets.only(left: AppLayout.spaceL),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppLayout.spaceL,
                    vertical: AppLayout.spaceXS,
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(
                      Icons.call_split_rounded,
                      color: theme.colorScheme.tertiary,
                      size: 20,
                    ),
                    title: Text(
                      'Split Bills & Shared Debts',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Split expenses, balance pennies, scan receipts with OCR, and track settlements.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    value: settings.showSplitBills,
                    onChanged: (val) {
                      AppHaptics.selectionClick();
                      settings.setShowSplitBills(val);
                    },
                  ),
                ),
                const SizedBox(height: AppLayout.spaceS),
                AppCard(
                  margin: const EdgeInsets.only(left: AppLayout.spaceL),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppLayout.spaceL,
                    vertical: AppLayout.spaceS,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: AppLayout.spaceM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Custom Bank SMS Training',
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Teach custom rules for unique bank SMS and OTP formats.',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          AppHaptics.selectionClick();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SmsRulesScreen()),
                          );
                        },
                        child: const Text('Configure'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppLayout.spaceM),

              // Period Tracker Toggle Card
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppLayout.spaceL,
                  vertical: AppLayout.spaceS,
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(
                    Icons.water_drop_outlined,
                    color: theme.colorScheme.tertiary,
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Period & Health Tracker',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppLayout.spaceS),
                      if (settings.isPeriodTrackerEnabled)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Active',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onTertiaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    'Offline cycle logging, predictions, regularity analytics, and discreet alerts.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  value: settings.isPeriodTrackerEnabled,
                  onChanged: (val) {
                    AppHaptics.selectionClick();
                    settings.setIsPeriodTrackerEnabled(val);
                  },
                ),
              ),
              const SizedBox(height: AppLayout.spaceM),

              // Split Bills Powerup Card
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppLayout.spaceL,
                  vertical: AppLayout.spaceS,
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(
                    Icons.pie_chart_outline_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Split Bills & Shared Debts',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppLayout.spaceS),
                      if (settings.showSplitBills)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Active',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    'Group bill splitting, equal & exact shares, 100% offline receipt OCR, WhatsApp breakdowns, and debt tracking.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  value: settings.showSplitBills,
                  onChanged: (val) {
                    AppHaptics.selectionClick();
                    settings.setShowSplitBills(val);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Page 4: On-Device Gemini AI Setup ---
  Widget _buildAiSlide(ThemeData theme) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        final isSupported = settings.isDeviceAiSupported;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppLayout.spaceXL),
          child: Column(
            children: [
              const SizedBox(height: AppLayout.spaceL),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: theme.colorScheme.onTertiaryContainer,
                  size: 32,
                ),
              ),
              const SizedBox(height: AppLayout.spaceXL),
              Text(
                'On-Device AI Assistant',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppLayout.spaceS),
              Text(
                'Private intelligence powered by Google AICore and on-device NLP.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppLayout.spaceXL),

              // Hardware Status Badge Card
              AppCard(
                padding: AppLayout.paddingAllL,
                child: Row(
                  children: [
                    Icon(
                      isSupported ? Icons.memory_rounded : Icons.info_outline_rounded,
                      color: isSupported ? theme.colorScheme.primary : theme.colorScheme.outline,
                    ),
                    const SizedBox(width: AppLayout.spaceM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSupported ? 'Hardware NPU Detected' : 'Offline Rule-Based AI Engine',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: AppLayout.spaceXS),
                          Text(
                            isSupported
                                ? 'Your device supports local Gemini Nano hardware acceleration.'
                                : 'Using high-speed local regular expression engines & heuristics.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppLayout.spaceL),

              // AI Feature Toggle Card
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppLayout.spaceL,
                  vertical: AppLayout.spaceS,
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: Icon(
                    Icons.psychology_outlined,
                    color: theme.colorScheme.tertiary,
                  ),
                  title: Text(
                    'On-Device AI Assistance',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Enables note summaries, title suggestions, and smart SMS auto-categorization.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  value: settings.useOnDeviceAi,
                  onChanged: (val) {
                    AppHaptics.selectionClick();
                    settings.setUseOnDeviceAi(val);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Page 5: Ready to Explore & Pro-Tips ---
  Widget _buildTipsSlide(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppLayout.spaceXL),
      child: Column(
        children: [
          const SizedBox(height: AppLayout.spaceL),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.tips_and_updates_rounded,
              color: theme.colorScheme.onPrimaryContainer,
              size: 32,
            ),
          ),
          const SizedBox(height: AppLayout.spaceXL),
          Text(
            'Ready to Explore!',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppLayout.spaceS),
          Text(
            'Here are a few quick tips to get the most out of Everything App.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppLayout.spaceXL),
          _buildFeatureCard(
            theme,
            icon: Icons.dashboard_customize_outlined,
            title: 'Modular Sub-Features Architecture',
            desc: 'Tailor every screen to your taste. Keep everything enabled for complete control, or turn off budgets, charts, and tags for pure minimalist simplicity.',
          ),
          const SizedBox(height: AppLayout.spaceM),
          _buildFeatureCard(
            theme,
            icon: Icons.checklist_rounded,
            title: 'Interactive Home Screen Widget',
            desc: 'Add the To-Do widget to your home screen to tick off tasks, view completion progress, and quick-add tasks directly with instant offline sync.',
          ),
          const SizedBox(height: AppLayout.spaceM),
          _buildFeatureCard(
            theme,
            icon: Icons.calendar_view_week_rounded,
            title: 'Days of Clarity & Mindful Focus',
            desc: 'Build focus without anxiety. An ambient 14-day mosaic strip celebrates your daily consistency without streak shaming or broken-chain guilt.',
          ),
          const SizedBox(height: AppLayout.spaceM),
          _buildFeatureCard(
            theme,
            icon: Icons.vibration_rounded,
            title: 'Restrained Tactile Haptics',
            desc: 'Satisfying mechanical micro-vibrations for sliders, chips, and actions synthesize the feel of physical tools. Turn off anytime in Settings.',
          ),
          const SizedBox(height: AppLayout.spaceM),
          _buildFeatureCard(
            theme,
            icon: Icons.savings_outlined,
            title: 'Savings Pockets & Split Calculator',
            desc: 'Organize goal-oriented savings with daily pacing, or split shared expenses fairly with ML Kit offline receipt OCR scanning and automatic penny balancing.',
          ),
          const SizedBox(height: AppLayout.spaceM),
          _buildFeatureCard(
            theme,
            icon: Icons.photo_library_outlined,
            title: 'Story Card Studio & Article Reader',
            desc: 'Turn quotes, full notes, or multi-item checklists into high-resolution social media cards with dedicated Reader & Quote layouts and 1-tap sharing.',
          ),
          const SizedBox(height: AppLayout.spaceM),
          _buildFeatureCard(
            theme,
            icon: Icons.link_rounded,
            title: 'In-Note Wiki Links & Expense Embeds',
            desc: 'Interconnect your notes using [[Note Title]] links and embed quick financial totals directly in your text with {{\$amount}} tags.',
          ),
          const SizedBox(height: AppLayout.spaceM),
          _buildFeatureCard(
            theme,
            icon: Icons.sync_lock_rounded,
            title: 'P2P Device Sync & Backups',
            desc: 'Bi-directional P2P Wi-Fi sync, non-blocking background SMS auto-parsing, and encrypted AES-256 backups.',
            actionLabel: 'Configure P2P Sync ➔',
            onAction: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const P2pSyncScreen()),
              );
            },
          ),
          const SizedBox(height: AppLayout.spaceM),
          _buildFeatureCard(
            theme,
            icon: Icons.import_contacts_rounded,
            title: 'Google Keep & Markdown Import',
            desc: 'Direct 1-tap Google Takeout link with Keep pre-selected, smart clean headings, duplicate prevention, and undo rollback.',
            actionLabel: 'Import Notes Now ➔',
            onAction: () {
              NoteMigrationSheet.show(context);
            },
          ),
          const SizedBox(height: AppLayout.spaceM),
          _buildFeatureCard(
            theme,
            icon: Icons.unfold_more_rounded,
            title: 'Precision Text Editing & Gestures',
            desc: 'Floating symmetrical formatting pill with single-tap character nudges, double-tap word jumps, and line-level navigation.',
          ),
          const SizedBox(height: AppLayout.spaceM),
          _buildFeatureCard(
            theme,
            icon: Icons.lock_outline_rounded,
            title: 'App Lock & Resilient Security',
            desc: 'Protect private notes, financial ledgers, and health logs with biometric authentication and built-in graceful recovery.',
          ),
          const SizedBox(height: AppLayout.spaceM),
          _buildFeatureCard(
            theme,
            icon: Icons.gesture_rounded,
            title: 'Multi-Select Batch Actions',
            desc: 'Long press any note card to select multiple notes for tagging, archiving, or deleting in bulk.',
          ),
          const SizedBox(height: AppLayout.spaceM),
          _buildFeatureCard(
            theme,
            icon: Icons.navigation_outlined,
            title: 'Responsive Navigation',
            desc: 'Enabling modules reveals a bottom navigation bar on phones or a sleek side rail on larger screens.',
          ),
        ],
      ),
    );
  }

  // Helper Widget for Feature Cards
  Widget _buildFeatureCard(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String desc,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return AppCard(
      padding: AppLayout.paddingAllL,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppLayout.spaceS),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppLayout.radiusM),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 24),
          ),
          const SizedBox(width: AppLayout.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppLayout.spaceXS),
                Text(
                  desc,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: AppLayout.spaceS),
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      minimumSize: const Size(0, 48),
                      backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                      foregroundColor: theme.colorScheme.primary,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      actionLabel,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widget for Theme Selection Segment Tiles
  Widget _buildThemeOptionTile(
    ThemeData theme, {
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: BouncingWidget(
        onTap: () {
          AppHaptics.selectionClick();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppLayout.spaceM,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppLayout.radiusM),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
                size: 22,
              ),
              const SizedBox(height: AppLayout.spaceXS),
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageChip(
    ThemeData theme,
    String label,
    String code,
    SettingsProvider settings,
  ) {
    final isSelected = settings.selectedLanguageCode == code;
    return Padding(
      padding: const EdgeInsets.only(right: AppLayout.spaceS),
      child: FilterChip(
        selected: isSelected,
        showCheckmark: false,
        label: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        selectedColor: theme.colorScheme.primaryContainer,
        shape: const StadiumBorder(),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: isSelected ? 1.5 : 1.0,
        ),
        onSelected: (_) {
          AppHaptics.selectionClick();
          settings.setSelectedLanguage(code);
        },
      ),
    );
  }
}

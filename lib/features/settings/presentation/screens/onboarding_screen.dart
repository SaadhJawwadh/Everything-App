import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/edge_fade_mask.dart';
import '../../../../widgets/bouncing_widget.dart';
import '../../providers/settings_provider.dart';
import '../widgets/onboarding_slides.dart';

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
                  child: EdgeFadeMask(
                    axis: EdgeFadeAxis.verticalBottom,
                    fadeStop: 0.94,
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() => _currentPage = index);
                      },
                      children: [
                        OnboardingWelcomeSlide(
                          theme: theme,
                          onNextPage: _nextPage,
                          onFinishOnboarding: _finishOnboarding,
                        ),
                        OnboardingPersonalizationSlide(theme: theme),
                        OnboardingModulesSlide(theme: theme),
                        OnboardingAiSlide(theme: theme),
                        OnboardingTipsSlide(theme: theme),
                      ],
                    ),
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
}

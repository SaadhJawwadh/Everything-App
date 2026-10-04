import 'package:flutter/material.dart';
import '../../../../core/services/app_haptics.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/app_bottom_sheet.dart';
import '../../../../utils/app_route.dart';
import '../../../../widgets/skeleton_card.dart';
import 'package:note_taking_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import '../../providers/period_tracker_provider.dart';
import '../widgets/cycle_phase_hero_card.dart';
import '../widgets/cycle_insights_card.dart';
import '../widgets/period_log_dashboard_card.dart';
import '../widgets/period_calendar_card.dart';
import '../widgets/period_log_editor_sheet.dart';

class PeriodTrackerScreen extends StatefulWidget {
  static final ValueNotifier<DateTime?> openLogEditorNotifier = ValueNotifier<DateTime?>(null);
  static final ValueNotifier<int> selectTodayNotifier = ValueNotifier<int>(0);

  const PeriodTrackerScreen({super.key});

  @override
  State<PeriodTrackerScreen> createState() => _PeriodTrackerScreenState();
}

class _PeriodTrackerScreenState extends State<PeriodTrackerScreen> with WidgetsBindingObserver {
  DateTime _focusedDay = DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime? _selectedDay;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    PeriodTrackerScreen.openLogEditorNotifier.addListener(_handleLogEditorNotifier);
    PeriodTrackerScreen.selectTodayNotifier.addListener(_handleSelectTodayNotifier);
  }

  void _handleSelectTodayNotifier() {
    if (!mounted) return;
    setState(() {
      _focusedDay = DateTime.now();
      _selectedDay = DateTime.now();
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: AppLayout.animDefault,
        curve: AppLayout.curveExpressive,
      );
    }
  }

  void _handleLogEditorNotifier() {
    final date = PeriodTrackerScreen.openLogEditorNotifier.value;
    if (date != null && mounted) {
      PeriodTrackerScreen.openLogEditorNotifier.value = null; // consume
      final provider = context.read<PeriodTrackerProvider>();
      PeriodLogEditorSheet.show(
        context: context,
        defaultStartDate: date,
        provider: provider,
      );
    }
  }

  @override
  void dispose() {
    PeriodTrackerScreen.openLogEditorNotifier.removeListener(_handleLogEditorNotifier);
    PeriodTrackerScreen.selectTodayNotifier.removeListener(_handleSelectTodayNotifier);
    _scrollController.dispose();
    super.dispose();
  }

  Color _resolvePhaseColor(BuildContext context, String phase) {
    final semantic = Theme.of(context).extension<AppSemanticColors>();
    switch (phase) {
      case 'Menstrual Phase':
        return semantic?.phaseMenstrual ?? const Color(0xFFD32F2F);
      case 'Follicular Phase':
        return semantic?.phaseFollicular ?? const Color(0xFF1976D2);
      case 'Ovulatory Phase':
        return semantic?.phaseOvulatory ?? const Color(0xFFF57C00);
      case 'Luteal Phase':
        return semantic?.phaseLuteal ?? const Color(0xFF7B1FA2);
      default:
        return Theme.of(context).colorScheme.outline;
    }
  }

  void _showPhaseGuideDialog(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = theme.extension<AppSemanticColors>();

    final phases = [
      (
        'Menstrual Phase',
        'Days 1–5',
        'Uterine lining sheds. Energy is lower; prioritize rest, hydration, and gentle movement.',
        semantic?.phaseMenstrual ?? const Color(0xFFD32F2F),
        Icons.water_drop_rounded,
      ),
      (
        'Follicular Phase',
        'Days 6–13',
        'Estrogen rises as follicles mature. Energy, mood, and creative focus naturally peak.',
        semantic?.phaseFollicular ?? const Color(0xFF1976D2),
        Icons.wb_sunny_rounded,
      ),
      (
        'Ovulatory Phase',
        'Days 14–16',
        'Luteinizing hormone surge triggers egg release. Peak confidence, social energy, and fertility.',
        semantic?.phaseOvulatory ?? const Color(0xFFF57C00),
        Icons.local_fire_department_rounded,
      ),
      (
        'Luteal Phase',
        'Days 17–28',
        'Progesterone rises. Energy turns inward; PMS symptoms may occur. Prioritize winding down.',
        semantic?.phaseLuteal ?? const Color(0xFF7B1FA2),
        Icons.nightlight_round,
      ),
    ];

    AppBottomSheet.show(
      context: context,
      title: 'Cycle Phase Guide',
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: phases.map((p) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.$4.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
                border: Border.all(color: p.$4.withValues(alpha: 0.25), width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: p.$4.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(p.$5, color: p.$4, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.$1,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: p.$4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              p.$2,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.$3,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        FilledButton.tonal(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PeriodTrackerProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return Scaffold(
            body: SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  SkeletonCard(height: 64),
                  SizedBox(height: 12),
                  SkeletonCard(height: 180),
                  SizedBox(height: 12),
                  SkeletonCard(height: 120),
                  SizedBox(height: 12),
                  SkeletonCard(height: 320),
                ],
              ),
            ),
          );
        }

        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final isDark = theme.brightness == Brightness.dark;
        final phaseColor = _resolvePhaseColor(context, provider.currentPhase);
        final settings = context.watch<SettingsProvider>();
        final isDiscreet = settings.isDiscreetHealthMode;

        final daysUntilNext = provider.daysUntilNext;
        final predictionStatus = provider.isPeriodActive
            ? 'Period Ongoing'
            : (daysUntilNext == null
                ? 'Not enough data'
                : (daysUntilNext > 0
                    ? 'Period in $daysUntilNext days'
                    : 'Period overdue by ${daysUntilNext.abs()} days'));

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: AnimationLimiter(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // ── Seamless Borderless Top Bar ────────────────────────────
                SliverAppBar(
                  pinned: true,
                  floating: false,
                  snap: false,
                  primary: false,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  toolbarHeight: MediaQuery.of(context).padding.top + 72.0,
                  titleSpacing: 0,
                  automaticallyImplyLeading: false,
                  flexibleSpace: Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 6,
                      left: 16,
                      right: 16,
                      bottom: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      border: null,
                    ),
                    child: SizedBox(
                      height: 60,
                      child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isDiscreet ? 'Wellness Tracker' : 'Period Tracker',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Semantics(
                                      button: true,
                                      label: 'View cycle phase guide and details',
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                                        onTap: () {
                                          _showPhaseGuideDialog(context);
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                          decoration: BoxDecoration(
                                            color: phaseColor.withValues(alpha: isDark ? 0.22 : 0.16),
                                            borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                                            border: Border.all(
                                              color: phaseColor.withValues(alpha: 0.35),
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.spa_rounded,
                                                size: 13,
                                                color: phaseColor,
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  isDiscreet
                                                      ? 'Wellness Insights'
                                                      : (provider.currentCycleDay != null
                                                          ? 'Day ${provider.currentCycleDay} • ${provider.currentPhase}'
                                                          : provider.currentPhase),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: theme.textTheme.bodySmall?.copyWith(
                                                    color: phaseColor,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 2),
                                              Icon(
                                                Icons.keyboard_arrow_down_rounded,
                                                size: 13,
                                                color: phaseColor,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.today_outlined),
                                tooltip: 'Today',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                visualDensity: VisualDensity.compact,
                                onPressed: () async {
                                  setState(() {
                                    _focusedDay = DateTime.now();
                                    _selectedDay = DateTime.now();
                                  });
                                  if (_scrollController.hasClients) {
                                    await _scrollController.animateTo(
                                      0,
                                      duration: AppLayout.animDefault,
                                      curve: AppLayout.curveExpressive,
                                    );
                                  }
                                },
                              ),
                              IconButton(
                                icon: Icon(
                                  isDiscreet ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                  color: isDiscreet ? colorScheme.primary : colorScheme.onSurfaceVariant,
                                ),
                                tooltip: isDiscreet ? 'Discreet Mode (Active)' : 'Enable Discreet Mode',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  AppHaptics.lightImpact();
                                  settings.setIsDiscreetHealthMode(!isDiscreet);
                                },
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded),
                                tooltip: 'Health Tools',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                elevation: 3,
                                shadowColor: colorScheme.shadow.withValues(alpha: 0.15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppLayout.radiusXL),
                                  side: BorderSide(
                                    color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                                    width: 1,
                                  ),
                                ),
                                color: colorScheme.surfaceContainerHigh,
                                onSelected: (value) {
                                  if (value == 'toggle_discreet') {
                                    AppHaptics.lightImpact();
                                    settings.setIsDiscreetHealthMode(!isDiscreet);
                                  } else if (value == 'log_period') {
                                    PeriodLogEditorSheet.show(
                                      context: context,
                                      defaultStartDate: _selectedDay ?? DateTime.now(),
                                      provider: provider,
                                    );
                                  } else if (value == 'phase_guide') {
                                    _showPhaseGuideDialog(context);
                                  } else if (value == 'cycle_settings') {
                                    AppRoute.push(context, const SettingsScreen())
                                        .then((_) => provider.loadData());
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  PopupMenuItem(
                                    value: 'toggle_discreet',
                                    height: 48,
                                    child: Row(
                                      children: [
                                        Icon(
                                          isDiscreet ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                          size: 20,
                                          color: colorScheme.primary,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          isDiscreet ? 'Disable Discreet Mode' : 'Discreet Privacy Mode',
                                          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                                                color: colorScheme.onSurface,
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'log_period',
                                    height: 48,
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_calendar_rounded, size: 20, color: colorScheme.primary),
                                        const SizedBox(width: 12),
                                        Text('Log Cycle & Symptoms', style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'phase_guide',
                                    height: 48,
                                    child: Row(
                                      children: [
                                        Icon(Icons.menu_book_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                                        const SizedBox(width: 12),
                                        Text('Cycle Phase Guide', style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'cycle_settings',
                                    height: 48,
                                    child: Row(
                                      children: [
                                        Icon(Icons.tune_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                                        const SizedBox(width: 12),
                                        Text('Cycle Preferences', style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.settings_outlined),
                                tooltip: 'Settings',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  AppRoute.push(context, const SettingsScreen())
                                      .then((_) => provider.loadData());
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                // ── Hero Moon Phase Card ──────────────────────────────────
                SliverToBoxAdapter(
                  child: AnimationConfiguration.staggeredList(
                    position: 0,
                    duration: const Duration(milliseconds: 220),
                    child: SlideAnimation(
                      verticalOffset: 24.0,
                      child: FadeInAnimation(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: CyclePhaseHeroCard(
                            phase: provider.currentPhase,
                            description: provider.phaseDescription,
                            cycleDay: provider.currentCycleDay,
                            avgCycleLength: provider.avgCycleLength,
                            phaseColor: phaseColor,
                            predictionStatus: predictionStatus,
                            isDiscreetMode: isDiscreet,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Cycle Statistical Insights Card ───────────────────────
                SliverToBoxAdapter(
                  child: AnimationConfiguration.staggeredList(
                    position: 1,
                    duration: const Duration(milliseconds: 220),
                    child: SlideAnimation(
                      verticalOffset: 24.0,
                      child: FadeInAnimation(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: CycleInsightsCard(
                            stats: provider.cycleStats,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Selected-Day Logging Dashboard Card ───────────────────
                SliverToBoxAdapter(
                  child: AnimationConfiguration.staggeredList(
                    position: 2,
                    duration: const Duration(milliseconds: 220),
                    child: SlideAnimation(
                      verticalOffset: 24.0,
                      child: FadeInAnimation(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: PeriodLogDashboardCard(
                            selectedDay: _selectedDay ?? _focusedDay,
                            provider: provider,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Period & Ovulation Calendar Card ──────────────────────
                SliverToBoxAdapter(
                  child: AnimationConfiguration.staggeredList(
                    position: 3,
                    duration: const Duration(milliseconds: 220),
                    child: SlideAnimation(
                      verticalOffset: 24.0,
                      child: FadeInAnimation(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, AppLayout.fabBottomPadding),
                          child: PeriodCalendarCard(
                            focusedDay: _focusedDay,
                            selectedDay: _selectedDay,
                            provider: provider,
                            onDaySelected: (selected, focused) {
                              AppHaptics.selectionClick();
                              setState(() {
                                _selectedDay = selected;
                                _focusedDay = focused;
                              });
                            },
                            onPageChanged: (focused) {
                              setState(() {
                                _focusedDay = focused;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

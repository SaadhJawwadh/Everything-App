import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';

import '../data/note_model.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import 'package:note_taking_app/features/notes/providers/note_provider.dart';
import '../core/theme/app_layout.dart';
import '../core/services/app_haptics.dart';
import '../core/services/app_intent_dispatcher.dart';
import '../core/services/app_function_inbox_service.dart';
import '../core/ui/app_morphing_fab.dart';
import '../core/ui/expressive_floating_toolbar.dart';
import '../core/ui/module_lock_gate.dart';
import '../utils/app_globals.dart';
import '../widgets/tag_filter_bar.dart';
import '../widgets/home/home_app_bar.dart';
import '../widgets/home/home_tag_folder_dialogs.dart';
import '../widgets/home/keyboard_shortcuts_dialog.dart';
import '../widgets/home/note_view_builder.dart';
import '../widgets/home/universal_search_overlay.dart';
export 'package:note_taking_app/features/notes/presentation/widgets/note_card.dart';
import 'package:note_taking_app/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:note_taking_app/features/finances/presentation/screens/financial_manager_screen.dart';
import 'package:note_taking_app/features/finances/providers/financial_manager_provider.dart';
import 'package:note_taking_app/features/finances/presentation/widgets/ledger_floating_toolbar.dart';
import 'package:note_taking_app/features/health/presentation/screens/period_tracker_screen.dart';
import 'app_lock_screen.dart';
import 'package:note_taking_app/features/finances/presentation/screens/category_management_screen.dart';
import 'package:note_taking_app/features/finances/presentation/screens/transaction_editor_screen.dart';
import 'package:note_taking_app/features/finances/presentation/screens/split_bill_editor_screen.dart';
import '../core/routes/app_router.dart';
import '../features/notes/data/note_repository.dart';
import '../features/settings/presentation/screens/onboarding_screen.dart';
import '../utils/widget_helper.dart';
import '../l10n/app_localizations.dart';
import '../widgets/whats_new_sheet.dart';
import '../services/update_rating_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isFabExpanded = ValueNotifier<bool>(true);
  bool _onboardingChecked = false;
  bool _whatsNewChecked = false;
  StreamSubscription? _intentDataStreamSubscription;

  bool _onScrollNotification(UserScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification.direction == ScrollDirection.reverse && _isFabExpanded.value) {
      _isFabExpanded.value = false;
    } else if (notification.direction == ScrollDirection.forward && !_isFabExpanded.value) {
      _isFabExpanded.value = true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_scrollListener);

    AppLockScreen.sessionAuthenticated.addListener(_handleSessionUnlock);
    AppLockScreen.sharedMediaTick.addListener(_handleSharedMediaTick);
    AppLockScreen.moduleSessionEpoch.addListener(_onModuleSessionChanged);
    appTabNavigationRequest.addListener(_handleTabNavigationRequest);

    _intentDataStreamSubscription =
        ReceiveSharingIntent.instance.getMediaStream().listen((files) {
      if (files.isEmpty || !mounted) return;
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final isLocked =
          settings.appLockEnabled && !AppLockScreen.sessionAuthenticated.value;
      if (!isLocked) {
        unawaited(AppIntentDispatcher.handleSharedMedia(context, files));
      }
    }, onError: (err) {
      debugPrint('getMediaStream error: $err');
    });

    const widgetChannel = MethodChannel('com.saadhjawwadh.notebook/widget');
    widgetChannel.setMethodCallHandler((call) async {
      if (call.method == 'onWidgetToggle') {
        await WidgetHelper.syncPendingTodoToggles();
        if (mounted) {
          await Provider.of<NoteProvider>(context, listen: false).refreshNotes();
          if (mounted) {
            unawaited(AppFunctionInboxService.drainPendingQueue(context));
          }
        }
      } else if (call.method == 'onPendingAction') {
        if (mounted) {
          final settings = Provider.of<SettingsProvider>(context, listen: false);
          final isLocked = settings.appLockEnabled && !AppLockScreen.sessionAuthenticated.value;
          if (!isLocked) {
            unawaited(_checkAndProcessPendingIntents());
          } else {
            unawaited(AppIntentDispatcher.processBackgroundQuickCaptureIfAny(context));
          }
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        unawaited(WidgetHelper.syncWidgetConfig(
          showFinancialManager: settings.showFinancialManager,
          appLockEnabled: settings.appLockEnabled,
          lockFinances: settings.lockFinances,
          hideWidgetDataWhenLocked: settings.hideWidgetDataWhenLocked,
          screenshotShieldEnabled: settings.screenshotShieldEnabled,
          languageCode: settings.selectedLanguageCode,
        ));
        unawaited(WidgetHelper.updateWidgetData());
        unawaited(WidgetHelper.updateTodoWidgetData());
        unawaited(AppFunctionInboxService.drainPendingQueue(context));
        final isLocked = settings.appLockEnabled && !AppLockScreen.sessionAuthenticated.value;
        if (!isLocked) {
          unawaited(_checkAndProcessPendingIntents());
        } else {
          unawaited(AppIntentDispatcher.processBackgroundQuickCaptureIfAny(context));
        }
      }
    });
  }

  void _handleSessionUnlock() {
    if (AppLockScreen.sessionAuthenticated.value && mounted) {
      _checkAndProcessPendingIntents();
    }
  }

  void _onModuleSessionChanged() {
    if (mounted) setState(() {});
  }

  void _handleTabNavigationRequest() {
    final target = appTabNavigationRequest.value;
    if (target == null || !mounted) return;
    appTabNavigationRequest.value = null;

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    int? targetIndex;
    if (target == 'notes') {
      targetIndex = 0;
    } else if (target == 'finances' && settings.showFinancialManager) {
      targetIndex = 1;
    } else if (target == 'health' && settings.isPeriodTrackerEnabled) {
      targetIndex = settings.showFinancialManager ? 2 : 1;
    }
    if (targetIndex == null) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
    if (_currentIndex != targetIndex) {
      setState(() => _currentIndex = targetIndex!);
    }
  }

  void _handleSharedMediaTick() {
    if (!mounted) return;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final isLocked =
        settings.appLockEnabled && !AppLockScreen.sessionAuthenticated.value;
    if (!isLocked) {
      _checkAndProcessPendingIntents();
    }
  }

  Future<void> _checkAndProcessPendingIntents() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    await AppIntentDispatcher.processPendingIntents(
      context: context,
      onSwitchTab: (idx) {
        if (mounted) setState(() => _currentIndex = idx);
      },
      destinations: _buildDestinations(settings),
    );
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    unawaited(WidgetHelper.updateWidgetData());
    unawaited(WidgetHelper.updateTodoWidgetData());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(AppFunctionInboxService.drainPendingQueue(context));
      unawaited(() async {
        await WidgetHelper.syncPendingTodoToggles();
        if (mounted) {
          await context.read<NoteProvider>().refreshNotes();
        }
      }());
      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final bool isLocked = settings.appLockEnabled && !AppLockScreen.sessionAuthenticated.value;
      if (!isLocked) {
        _checkAndProcessPendingIntents();
      } else {
        unawaited(AppIntentDispatcher.processBackgroundQuickCaptureIfAny(context));
      }
    }
  }

  @override
  void dispose() {
    unawaited(_intentDataStreamSubscription?.cancel());
    _scrollController.dispose();
    _isFabExpanded.dispose();
    AppLockScreen.sessionAuthenticated.removeListener(_handleSessionUnlock);
    AppLockScreen.sharedMediaTick.removeListener(_handleSharedMediaTick);
    AppLockScreen.moduleSessionEpoch.removeListener(_onModuleSessionChanged);
    appTabNavigationRequest.removeListener(_handleTabNavigationRequest);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _bulkDeleteWithUndo(NoteProvider noteProvider) async {
    final ids = await noteProvider.bulkDelete();
    if (ids.isEmpty || !mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(AppLocalizations.of(context)?.notesMovedToTrash(ids.length) ??
            (ids.length == 1
                ? 'Note moved to Trash'
                : '${ids.length} notes moved to Trash')),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            for (final id in ids) {
              await NoteRepository.instance.restoreNote(id);
            }
            await refreshNotes(scrollOnModified: true);
          },
        ),
      ),
    );
  }

  void _cycleViewMode(SettingsProvider settings) {
    const values = NoteViewMode.values;
    final nextIndex = (settings.noteViewMode.index + 1) % values.length;
    settings.setNoteViewMode(values[nextIndex]);
  }

  Future<void> refreshNotes({bool scrollOnModified = false}) async {
    if (!mounted) return;
    final reduceMotion = AppLayout.shouldReduceMotion(context);
    final provider = context.read<NoteProvider>();
    await provider.refreshNotes();
    if (scrollOnModified && provider.sortMode == 'modified' && _scrollController.hasClients) {
      if (reduceMotion) {
        _scrollController.jumpTo(0);
      } else {
        await _scrollController.animateTo(
          0,
          duration: AppLayout.animDefault,
          curve: AppLayout.curveEmphasizedDecelerate,
        );
      }
    }
  }

  void onNoteTap(Note note, VoidCallback openContainer) {
    if (context.read<NoteProvider>().isSelectionMode) {
      context.read<NoteProvider>().toggleSelection(note.id);
    } else {
      openContainer();
    }
  }

  void onNoteLongPress(Note note) {
    context.read<NoteProvider>().toggleSelection(note.id);
  }

  Future<void> bulkMoveToFolder() => HomeTagFolderDialogs.bulkMoveToFolder(
        context: context,
        onRefreshNotes: refreshNotes,
      );

  Future<void> bulkTag() => HomeTagFolderDialogs.bulkTag(context);

  void _showTagOptions(String tag) =>
      HomeTagFolderDialogs.showTagOptions(context, tag);

  void _scrollListener() {
    if (_scrollController.hasClients && _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 500) {
      context.read<NoteProvider>().loadMoreNotes();
    }
  }

  void _showOnboardingSheet() {
    AppRouter.push(context, const OnboardingScreen());
  }

  /// Shows the What's New sheet once per version after an update, and kicks
  /// off the (silent) Play in-app-update and rating-milestone checks.
  Future<void> _maybeShowWhatsNew(SettingsProvider settings) async {
    unawaited(UpdateRatingService.checkForUpdates());
    unawaited(UpdateRatingService.incrementMilestoneAndCheckRating());

    final info = await PackageInfo.fromPlatform();
    final currentVersion = info.version;
    if (settings.lastSeenVersion == currentVersion) return;

    if (_onboardingChecked) {
      // Fresh install: onboarding is showing this session — everything is
      // new to them anyway, so just record the version silently.
      await settings.setLastSeenVersion(currentVersion);
      return;
    }

    if (!mounted) return;
    final reduceMotion = AppLayout.shouldReduceMotion(context);
    unawaited(
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        sheetAnimationStyle: reduceMotion
            ? AnimationStyle.noAnimation
            : const AnimationStyle(
                duration: AppLayout.animModal,
                reverseDuration: AppLayout.animFast,
                curve: AppLayout.curveSheet,
                reverseCurve: AppLayout.curveEmphasizedAccelerate,
              ),
        builder: (context) => WhatsNewSheet(currentVersion: currentVersion),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Selector<
        SettingsProvider,
        ({
          bool isInitialized,
          bool hasSeenOnboarding,
          bool showFinancialManager,
          bool isPeriodTrackerEnabled,
          bool lockFinances,
          bool lockHealth,
        })>(
      selector: (_, s) => (
        isInitialized: s.isInitialized,
        hasSeenOnboarding: s.hasSeenOnboarding,
        showFinancialManager: s.showFinancialManager,
        isPeriodTrackerEnabled: s.isPeriodTrackerEnabled,
        lockFinances: s.lockFinances,
        lockHealth: s.lockHealth,
      ),
      builder: (context, shell, child) {
        final settings = context.read<SettingsProvider>();
        if (shell.isInitialized && !shell.hasSeenOnboarding && !_onboardingChecked) {
          _onboardingChecked = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showOnboardingSheet();
          });
        }

        if (shell.isInitialized && !_whatsNewChecked) {
          _whatsNewChecked = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _maybeShowWhatsNew(settings);
          });
        }

        final isNotesSelection = _currentIndex == 0 &&
            context.select<NoteProvider, bool>((p) => p.isSelectionMode);
        final isFinancesSelection = shell.showFinancialManager &&
            _currentIndex == 1 &&
            context.select<FinancialManagerProvider, bool>((p) => p.isSelectionMode);
        final isSelectionMode = isNotesSelection || isFinancesSelection;

        Widget? activeToolbar;
        if (isNotesSelection) {
          activeToolbar = _buildSelectionToolbar(context, context.read<NoteProvider>());
        } else if (isFinancesSelection) {
          activeToolbar = LedgerFloatingToolbar(
            onActionCompleted: () => context.read<FinancialManagerProvider>().loadTransactions(),
          );
        }

        final bool hasExtraFeatures = shell.showFinancialManager || shell.isPeriodTrackerEnabled;

        if (!hasExtraFeatures) {
          _currentIndex = 0;
          return _wrapWithKeyboardShortcuts(
            context: context,
            settings: settings,
            destinationsCount: 1,
            child: Scaffold(
              extendBody: true,
              body: NotificationListener<UserScrollNotification>(
                onNotification: _onScrollNotification,
                child: _buildNotesScaffold(context, settings),
              ),
              floatingActionButton: isSelectionMode ? null : _buildFAB(context),
              bottomNavigationBar: isSelectionMode
                  ? activeToolbar
                  : null,
            ),
          );
        }

        final List<Widget> destinations = _buildDestinations(settings);
        _currentIndex = _currentIndex.clamp(0, destinations.length - 1);

        final bool isTablet = AppLayout.isDualPane(context);

        if (isTablet) {
          return _wrapWithKeyboardShortcuts(
            context: context,
            settings: settings,
            destinationsCount: destinations.length,
            child: Scaffold(
              extendBody: true,
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (index) {
                      AppHaptics.selectionClick();
                      final nProvider = context.read<NoteProvider>();
                      if (nProvider.isSelectionMode) nProvider.clearSelection();
                      final fProvider = context.read<FinancialManagerProvider>();
                      if (fProvider.isSelectionMode) fProvider.clearSelection();
                      setState(() => _currentIndex = index);
                    },
                    labelType: NavigationRailLabelType.all,
                    destinations: _buildNavRailDestinations(settings),
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                    trailing: Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: AppLayout.spaceM),
                          child: IconButton(
                            key: const ValueKey('keyboard_shortcuts_rail_button'),
                            tooltip: 'Keyboard Shortcuts (Ctrl + /)',
                            icon: const Icon(Icons.keyboard_alt_outlined),
                            onPressed: () => KeyboardShortcutsDialog.show(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: NotificationListener<UserScrollNotification>(
                      onNotification: _onScrollNotification,
                      child: IndexedStack(
                        index: _currentIndex,
                        children: _buildFeatureScreens(settings),
                      ),
                    ),
                  ),
                ],
              ),
              floatingActionButton: isSelectionMode ? null : _buildCurrentFAB(context, settings),
              bottomNavigationBar: isSelectionMode
                  ? activeToolbar
                  : null,
            ),
          );
        }

        final reduceMotion = AppLayout.shouldReduceMotion(context);
        return _wrapWithKeyboardShortcuts(
          context: context,
          settings: settings,
          destinationsCount: destinations.length,
          child: Scaffold(
            extendBody: true,
            body: NotificationListener<UserScrollNotification>(
              onNotification: _onScrollNotification,
              child: IndexedStack(
                index: _currentIndex,
                children: _buildFeatureScreens(settings),
              ),
            ),
            floatingActionButton: isSelectionMode ? null : _buildCurrentFAB(context, settings),
            bottomNavigationBar: AnimatedSwitcher(
              duration: reduceMotion ? Duration.zero : AppLayout.animFast,
              switchInCurve: AppLayout.curveStrongEaseOut,
              switchOutCurve: AppLayout.curveEmphasizedAccelerate,
              transitionBuilder: (child, animation) {
                if (reduceMotion) {
                  return FadeTransition(opacity: animation, child: child);
                }
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 1.0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                );
              },
              child: isSelectionMode
                  ? (activeToolbar ?? const SizedBox.shrink())
                  : Container(
                      key: const ValueKey('navigation_bar'),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerLow,
                        border: null,
                      ),
                      child: NavigationBar(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        selectedIndex: _currentIndex,
                        onDestinationSelected: (index) {
                          AppHaptics.selectionClick();
                          final nProvider = context.read<NoteProvider>();
                          if (nProvider.isSelectionMode) nProvider.clearSelection();
                          final fProvider = context.read<FinancialManagerProvider>();
                          if (fProvider.isSelectionMode) fProvider.clearSelection();
                          setState(() => _currentIndex = index);
                        },
                        destinations: _buildNavDestinations(settings),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _wrapWithKeyboardShortcuts({
    required BuildContext context,
    required SettingsProvider settings,
    required int destinationsCount,
    required Widget child,
  }) {
    void openNewNote() async {
      AppHaptics.lightImpact();
      final nProvider = context.read<NoteProvider>();
      final returned = await AppRouter.push<bool>(context, NoteEditorScreen(initialFolder: nProvider.selectedFolder));
      if (returned == true) await refreshNotes(scrollOnModified: true);
    }

    void openNewTransaction() async {
      if (!settings.showFinancialManager ||
          ModuleLockGate.isModuleCurrentlyLocked(settings, 'finances')) {
        return;
      }
      AppHaptics.lightImpact();
      await AppRouter.push(context, const TransactionEditorScreen());
      if (context.mounted) {
        await context.read<FinancialManagerProvider>().loadTransactions();
      }
    }

    void focusSearch() {
      AppHaptics.selectionClick();
      if (_currentIndex != 0) {
        setState(() => _currentIndex = 0);
      }
      HomeAppBar.searchRequestedNotifier.value = true;
    }

    void switchTab(int target) {
      if (target >= 0 && target < destinationsCount && _currentIndex != target) {
        AppHaptics.selectionClick();
        final nProvider = context.read<NoteProvider>();
        if (nProvider.isSelectionMode) nProvider.clearSelection();
        final fProvider = context.read<FinancialManagerProvider>();
        if (fProvider.isSelectionMode) fProvider.clearSelection();
        setState(() => _currentIndex = target);
      }
    }

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): openNewNote,
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): openNewNote,
        const SingleActivator(LogicalKeyboardKey.keyT, control: true): openNewTransaction,
        const SingleActivator(LogicalKeyboardKey.keyT, meta: true): openNewTransaction,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): focusSearch,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): focusSearch,
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () => switchTab(0),
        const SingleActivator(LogicalKeyboardKey.digit1, meta: true): () => switchTab(0),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () => switchTab(1),
        const SingleActivator(LogicalKeyboardKey.digit2, meta: true): () => switchTab(1),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () => switchTab(2),
        const SingleActivator(LogicalKeyboardKey.digit3, meta: true): () => switchTab(2),
        const SingleActivator(LogicalKeyboardKey.slash, control: true): () =>
            KeyboardShortcutsDialog.show(context),
        const SingleActivator(LogicalKeyboardKey.slash, meta: true): () =>
            KeyboardShortcutsDialog.show(context),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          final noteProvider = context.read<NoteProvider>();
          final finProvider = context.read<FinancialManagerProvider>();
          if (noteProvider.isSelectionMode) {
            noteProvider.clearSelection();
          } else if (finProvider.isSelectionMode) {
            finProvider.clearSelection();
          } else if (noteProvider.searchQuery.isNotEmpty) {
            noteProvider.setSearchQuery('');
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: child,
      ),
    );
  }

  Widget _buildSelectionToolbar(BuildContext context, NoteProvider noteProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: ExpressiveFloatingToolbar(
        key: const ValueKey('selection_toolbar'),
        isVibrant: true,
        mainAxisSize: MainAxisSize.min,
        children: [
          ExpressiveFloatingToolbar.actionButton(
            icon: Icons.push_pin_outlined,
            tooltip: 'Pin / unpin selected',
            onPressed: () {
              AppHaptics.lightImpact();
              noteProvider.bulkTogglePin();
            },
          ),
          ExpressiveFloatingToolbar.actionButton(
            icon: Icons.archive_outlined,
            tooltip: 'Archive selected',
            onPressed: () {
              AppHaptics.lightImpact();
              noteProvider.bulkArchive();
            },
          ),
          ExpressiveFloatingToolbar.actionButton(
            icon: Icons.label_outline,
            tooltip: 'Tag selected',
            onPressed: () {
              AppHaptics.selectionClick();
              bulkTag();
            },
          ),
          ExpressiveFloatingToolbar.actionButton(
            icon: Icons.drive_file_move_outlined,
            tooltip: 'Move to folder',
            onPressed: () {
              AppHaptics.selectionClick();
              bulkMoveToFolder();
            },
          ),
          ExpressiveFloatingToolbar.spacer(),
          ExpressiveFloatingToolbar.actionButton(
            icon: Icons.delete_outline,
            tooltip: 'Delete selected',
            color: colorScheme.error,
            onPressed: () {
              AppHaptics.mediumImpact();
              _bulkDeleteWithUndo(noteProvider);
            },
          ),
        ],
      ),
    );
  }

  List<NavigationRailDestination> _buildNavRailDestinations(SettingsProvider settings) {
    final l10n = AppLocalizations.of(context)!;
    return [
      NavigationRailDestination(
        icon: const Icon(Icons.note_alt_outlined),
        selectedIcon: const Icon(Icons.note_alt),
        label: Text(l10n.navNotes),
      ),
      if (settings.showFinancialManager)
        NavigationRailDestination(
          icon: const Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: const Icon(Icons.account_balance_wallet),
          label: Text(l10n.navFinances),
        ),
      if (settings.isPeriodTrackerEnabled)
        NavigationRailDestination(
          icon: const Icon(Icons.water_drop_outlined),
          selectedIcon: const Icon(Icons.water_drop),
          label: Text(l10n.navTracker),
        ),
    ];
  }

  List<Widget> _buildNavDestinations(SettingsProvider settings) {
    final l10n = AppLocalizations.of(context)!;
    return [
      NavigationDestination(icon: const Icon(Icons.note_alt_outlined), selectedIcon: const Icon(Icons.note_alt), label: l10n.navNotes),
      if (settings.showFinancialManager) NavigationDestination(icon: const Icon(Icons.account_balance_wallet_outlined), selectedIcon: const Icon(Icons.account_balance_wallet), label: l10n.navFinances),
      if (settings.isPeriodTrackerEnabled) NavigationDestination(icon: const Icon(Icons.water_drop_outlined), selectedIcon: const Icon(Icons.water_drop), label: l10n.navTracker),
    ];
  }

  List<Widget> _buildDestinations(SettingsProvider settings) {
    final List<Widget> list = [const SizedBox()]; // Placeholder for Notes
    if (settings.showFinancialManager) list.add(const FinancialManagerScreen());
    if (settings.isPeriodTrackerEnabled) list.add(const PeriodTrackerScreen());
    return list;
  }

  List<Widget> _buildFeatureScreens(SettingsProvider settings) {
    final int financesIndex = settings.showFinancialManager ? 1 : -1;
    final int trackerIndex = settings.isPeriodTrackerEnabled
        ? (settings.showFinancialManager ? 2 : 1)
        : -1;
    return [
      TickerMode(
        enabled: _currentIndex == 0,
        child: _buildNotesScaffold(context, settings),
      ),
      if (settings.showFinancialManager)
        TickerMode(
          enabled: _currentIndex == financesIndex,
          child: ModuleLockGate(
            moduleKey: 'finances',
            moduleTitle: 'Finances',
            isLockedSettingEnabled: settings.lockFinances,
            isActive: _currentIndex == financesIndex,
            child: const FinancialManagerScreen(),
          ),
        ),
      if (settings.isPeriodTrackerEnabled)
        TickerMode(
          enabled: _currentIndex == trackerIndex,
          child: ModuleLockGate(
            moduleKey: 'health',
            moduleTitle: 'Health',
            isLockedSettingEnabled: settings.lockHealth,
            isActive: _currentIndex == trackerIndex,
            child: const PeriodTrackerScreen(),
          ),
        ),
    ];
  }

  Widget _buildNotesScaffold(BuildContext context, SettingsProvider settings) {
    return _NotesTabBody(
      scrollController: _scrollController,
      onClearSelection: () => context.read<NoteProvider>().clearSelection(),
      onBulkArchive: () => context.read<NoteProvider>().bulkArchive(),
      onBulkDelete: () => _bulkDeleteWithUndo(context.read<NoteProvider>()),
      onBulkTag: bulkTag,
      onBulkMoveToFolder: bulkMoveToFolder,
      onCycleViewMode: () => _cycleViewMode(settings),
      onRefresh: refreshNotes,
      onTagLongPress: _showTagOptions,
      onNoteTap: onNoteTap,
      onNoteLongPress: onNoteLongPress,
    );
  }

  Widget? _buildCurrentFAB(BuildContext context, SettingsProvider settings) {
    if (_currentIndex == 0) {
      return _buildFAB(context);
    }

    int financesIndex = -1;
    if (settings.showFinancialManager) financesIndex = 1;

    int trackerIndex = -1;
    if (settings.isPeriodTrackerEnabled) {
      trackerIndex = settings.showFinancialManager ? 2 : 1;
    }

    if (_currentIndex == financesIndex) {
      if (ModuleLockGate.isModuleCurrentlyLocked(settings, 'finances')) return null;
      return _buildFinancesFAB(context);
    }

    if (_currentIndex == trackerIndex) {
      if (ModuleLockGate.isModuleCurrentlyLocked(settings, 'health')) return null;
      return _buildTrackerFAB(context);
    }

    return null;
  }

  Widget _buildFinancesFAB(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: _isFabExpanded,
      builder: (context, isExpanded, _) {
        return ValueListenableBuilder<String>(
          valueListenable: FinancialManagerScreen.activeTabNotifier,
          builder: (context, activeTab, _) {
            final isSplitTab = activeTab == 'Split Bills';
            final l10n = AppLocalizations.of(context);
            return AppMorphingFab(
              isExpanded: isExpanded,
              icon: isSplitTab ? Icons.pie_chart_outline_rounded : Icons.add,
              label: isSplitTab
                  ? (l10n?.splitBillsTitle ?? 'New Split Bill')
                  : (l10n?.newTransaction ?? 'New Transaction'),
              onPressed: () async {
                if (isSplitTab) {
                  await AppRouter.push(context, const SplitBillEditorScreen());
                  if (context.mounted) {
                    await context.read<FinancialManagerProvider>().loadTransactions();
                  }
                } else {
                  await AppRouter.push(context, const TransactionEditorScreen());
                  if (context.mounted) {
                    await context.read<FinancialManagerProvider>().loadTransactions();
                  }
                }
              },
              secondaryAction: isSplitTab
                  ? null
                  : IconButton(
                      tooltip: l10n?.categories ?? 'Categories',
                      icon: Icon(Icons.category_outlined, color: colorScheme.onPrimaryContainer, size: 20),
                      onPressed: () {
                        AppRouter.push(context, const CategoryManagementScreen());
                      },
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildTrackerFAB(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: _isFabExpanded,
      builder: (context, isExpanded, _) {
        return AppMorphingFab(
          isExpanded: isExpanded,
          icon: Icons.add,
          label: l10n?.periodLog ?? 'Log Period',
          backgroundColor: colorScheme.tertiaryContainer,
          foregroundColor: colorScheme.onTertiaryContainer,
          onPressed: () {
            PeriodTrackerScreen.openLogEditorNotifier.value = DateTime.now();
          },
          secondaryAction: IconButton(
            tooltip: 'Jump to Today',
            icon: Icon(Icons.today, color: colorScheme.onTertiaryContainer, size: 20),
            onPressed: () async {
              PeriodTrackerScreen.selectTodayNotifier.value++;
            },
          ),
        );
      },
    );
  }

  Widget _buildFAB(BuildContext context) {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: _isFabExpanded,
      builder: (context, isExpanded, _) {
        return AppMorphingFab(
          isExpanded: isExpanded,
          icon: Icons.add,
          label: l10n?.newNote ?? 'New Note',
          onPressed: () async {
            final returned = await AppRouter.push<bool>(context, NoteEditorScreen(initialFolder: noteProvider.selectedFolder));
            if (returned == true) await refreshNotes(scrollOnModified: true);
          },
          secondaryAction: IconButton(
            tooltip: AppLocalizations.of(context)?.startFromTemplate ?? 'Templates',
            icon: Icon(Icons.style_outlined, color: colorScheme.onPrimaryContainer, size: 20),
            onPressed: () {
              _showTemplateSheet();
            },
          ),
        );
      },
    );
  }

  void _showTemplateSheet() => HomeTagFolderDialogs.showTemplateSheet(
        context: context,
        onRefreshNotes: refreshNotes,
      );
}

class _NotesTabBody extends StatelessWidget {
  final ScrollController scrollController;
  final VoidCallback onClearSelection;
  final VoidCallback onBulkArchive;
  final VoidCallback onBulkDelete;
  final VoidCallback onBulkTag;
  final VoidCallback onBulkMoveToFolder;
  final VoidCallback onCycleViewMode;
  final Future<void> Function({bool scrollOnModified}) onRefresh;
  final void Function(String) onTagLongPress;
  final void Function(Note, VoidCallback) onNoteTap;
  final void Function(Note) onNoteLongPress;

  const _NotesTabBody({
    required this.scrollController,
    required this.onClearSelection,
    required this.onBulkArchive,
    required this.onBulkDelete,
    required this.onBulkTag,
    required this.onBulkMoveToFolder,
    required this.onCycleViewMode,
    required this.onRefresh,
    required this.onTagLongPress,
    required this.onNoteTap,
    required this.onNoteLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final searchQuery = context.select<NoteProvider, String>((p) => p.searchQuery);
    final showTagFilterBar = context.select<SettingsProvider, bool>((s) => s.showTagFilterBar);
    final isSearching = searchQuery.isNotEmpty;

    return PopScope(
      canPop: !isSearching,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (isSearching) {
          context.read<NoteProvider>().setSearchQuery('');
        }
      },
      child: AnimationLimiter(
        child: CustomScrollView(
          key: const PageStorageKey<String>('home_notes_scroll_view'),
          controller: scrollController,
          scrollCacheExtent: const ScrollCacheExtent.pixels(600.0),
          slivers: [
            HomeAppBar(
              onClearSelection: onClearSelection,
              onBulkArchive: onBulkArchive,
              onBulkDelete: onBulkDelete,
              onBulkTag: onBulkTag,
              onBulkMoveToFolder: onBulkMoveToFolder,
              onCycleViewMode: onCycleViewMode,
              onRefresh: onRefresh,
            ),
            if (isSearching)
              SliverToBoxAdapter(
                child: UniversalSearchOverlay(query: searchQuery),
              ),
            if (showTagFilterBar && !isSearching)
              SliverToBoxAdapter(child: TagFilterBar(onTagLongPress: onTagLongPress)),
            if (!isSearching)
              NoteViewBuilder(
                onRefresh: onRefresh,
                onNoteTap: onNoteTap,
                onNoteLongPress: onNoteLongPress,
              ),
          ],
        ),
      ),
    );
  }
}


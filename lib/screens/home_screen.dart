import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
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
import '../utils/app_route.dart';
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
  bool _isFabExpanded = true;
  bool _onboardingChecked = false;
  bool _whatsNewChecked = false;
  StreamSubscription? _intentDataStreamSubscription;

  bool _onScrollNotification(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.reverse && _isFabExpanded) {
      setState(() => _isFabExpanded = false);
    } else if (notification.direction == ScrollDirection.forward && !_isFabExpanded) {
      setState(() => _isFabExpanded = true);
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
        unawaited(WidgetHelper.updateWidgetData());
        unawaited(WidgetHelper.updateTodoWidgetData());
        unawaited(AppFunctionInboxService.drainPendingQueue(context));
        final settings = Provider.of<SettingsProvider>(context, listen: false);
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
      FinancialManagerScreen.refreshNotifier.value++;
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
    AppLockScreen.sessionAuthenticated.removeListener(_handleSessionUnlock);
    AppLockScreen.sharedMediaTick.removeListener(_handleSharedMediaTick);
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
    final provider = context.read<NoteProvider>();
    await provider.refreshNotes();
    if (scrollOnModified && provider.sortMode == 'modified' && _scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: AppLayout.animDefault,
        curve: AppLayout.curveEmphasizedDecelerate,
      );
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const OnboardingScreen(),
      ),
    );
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
    unawaited(
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => WhatsNewSheet(currentVersion: currentVersion),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(builder: (context, settings, child) {
      if (settings.isInitialized && !settings.hasSeenOnboarding && !_onboardingChecked) {
        _onboardingChecked = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showOnboardingSheet();
        });
      }

      if (settings.isInitialized && !_whatsNewChecked) {
        _whatsNewChecked = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _maybeShowWhatsNew(settings);
        });
      }

      final isNotesSelection = _currentIndex == 0 &&
          context.select<NoteProvider, bool>((p) => p.isSelectionMode);
      final isFinancesSelection = settings.showFinancialManager &&
          _currentIndex == 1 &&
          context.select<FinancialManagerProvider, bool>((p) => p.isSelectionMode);
      final isSelectionMode = isNotesSelection || isFinancesSelection;

      Widget? activeToolbar;
      if (isNotesSelection) {
        activeToolbar = _buildSelectionToolbar(context, context.read<NoteProvider>());
      } else if (isFinancesSelection) {
        activeToolbar = LedgerFloatingToolbar(
          onActionCompleted: () => FinancialManagerScreen.refreshNotifier.value++,
        );
      }

      final bool hasExtraFeatures = settings.showFinancialManager || settings.isPeriodTrackerEnabled;
      
      if (!hasExtraFeatures) {
        return _wrapWithKeyboardShortcuts(
          context: context,
          settings: settings,
          destinationsCount: 1,
          child: Scaffold(
            extendBody: true,
            body: _buildNotesScaffold(context, settings),
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
            duration: AppLayout.animDefault,
            switchInCurve: AppLayout.curveExpressiveSpatial,
            switchOutCurve: AppLayout.curveEmphasizedAccelerate,
            transitionBuilder: (child, animation) {
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
    });
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
      final returned = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) =>
              NoteEditorScreen(initialFolder: nProvider.selectedFolder),
        ),
      );
      if (returned == true) await refreshNotes(scrollOnModified: true);
    }

    void openNewTransaction() async {
      if (!settings.showFinancialManager) return;
      AppHaptics.lightImpact();
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TransactionEditorScreen()),
      );
      if (context.mounted) {
        await context.read<FinancialManagerProvider>().loadTransactions();
        FinancialManagerScreen.refreshNotifier.value++;
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
    return [
      _buildNotesScaffold(context, settings),
      if (settings.showFinancialManager) const FinancialManagerScreen(),
      if (settings.isPeriodTrackerEnabled) const PeriodTrackerScreen(),
    ];
  }

  Widget _buildNotesScaffold(BuildContext context, SettingsProvider settings) {
    final noteProvider = context.watch<NoteProvider>();
    return PopScope(
      canPop: noteProvider.searchQuery.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (noteProvider.searchQuery.isNotEmpty) {
          noteProvider.setSearchQuery('');
        }
      },
      child: NotificationListener<UserScrollNotification>(
        onNotification: _onScrollNotification,
        child: CustomScrollView(
          key: const PageStorageKey<String>('home_notes_scroll_view'),
          controller: _scrollController,
          slivers: [
            HomeAppBar(
              onClearSelection: () => noteProvider.clearSelection(),
              onBulkArchive: () => noteProvider.bulkArchive(),
              onBulkDelete: () => _bulkDeleteWithUndo(noteProvider),
              onBulkTag: bulkTag,
              onBulkMoveToFolder: bulkMoveToFolder,
              onCycleViewMode: () => _cycleViewMode(settings),
              onRefresh: refreshNotes,
            ),
            if (noteProvider.searchQuery.isNotEmpty)
              SliverToBoxAdapter(
                child: UniversalSearchOverlay(query: noteProvider.searchQuery),
              ),
            if (settings.showTagFilterBar && noteProvider.searchQuery.isEmpty)
              SliverToBoxAdapter(child: TagFilterBar(onTagLongPress: _showTagOptions)),
            if (noteProvider.searchQuery.isEmpty)
              NoteViewBuilder(
                onRefresh: refreshNotes,
                onNoteTap: onNoteTap,
                onNoteLongPress: onNoteLongPress,
              ),
          ],
        ),
      ),
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
      return _buildFinancesFAB(context);
    }

    if (_currentIndex == trackerIndex) {
      return _buildTrackerFAB(context);
    }

    return null;
  }

  Widget _buildFinancesFAB(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<String>(
      valueListenable: FinancialManagerScreen.activeTabNotifier,
      builder: (context, activeTab, _) {
        final isSplitTab = activeTab == 'Split Bills';
        final l10n = AppLocalizations.of(context);
        return AppMorphingFab(
          isExpanded: _isFabExpanded,
          icon: isSplitTab ? Icons.pie_chart_outline_rounded : Icons.add,
          label: isSplitTab
              ? (l10n?.splitBillsTitle ?? 'New Split Bill')
              : (l10n?.newTransaction ?? 'New Transaction'),
          onPressed: () async {
            if (isSplitTab) {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SplitBillEditorScreen()),
              );
              if (context.mounted) {
                await context.read<FinancialManagerProvider>().loadTransactions();
                FinancialManagerScreen.refreshNotifier.value++;
              }
            } else {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const TransactionEditorScreen()),
              );
              if (context.mounted) {
                await context.read<FinancialManagerProvider>().loadTransactions();
                FinancialManagerScreen.refreshNotifier.value++;
              }
            }
          },
          secondaryAction: isSplitTab
              ? null
              : IconButton(
                  tooltip: l10n?.categories ?? 'Categories',
                  icon: Icon(Icons.category_outlined, color: colorScheme.onPrimaryContainer, size: 20),
                  onPressed: () {
                    AppRoute.push(context, const CategoryManagementScreen());
                  },
                ),
        );
      },
    );
  }

  Widget _buildTrackerFAB(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return AppMorphingFab(
      isExpanded: _isFabExpanded,
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
  }

  Widget _buildFAB(BuildContext context) {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return AppMorphingFab(
      isExpanded: _isFabExpanded,
      icon: Icons.add,
      label: l10n?.newNote ?? 'New Note',
      onPressed: () async {
        final returned = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => NoteEditorScreen(initialFolder: noteProvider.selectedFolder),
          ),
        );
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
  }

  void _showTemplateSheet() => HomeTagFolderDialogs.showTemplateSheet(
        context: context,
        onRefreshNotes: refreshNotes,
      );
}


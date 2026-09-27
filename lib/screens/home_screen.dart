import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'dart:io';

import '../data/note_model.dart';
import '../data/note_templates.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import '../providers/note_provider.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_layout.dart';
import '../core/services/app_haptics.dart';
import '../core/ui/app_chip.dart';
import '../core/ui/app_morphing_fab.dart';
import '../core/ui/expressive_floating_toolbar.dart';
import '../widgets/tag_filter_bar.dart';
import '../widgets/clarity_mosaic_strip.dart';
import '../widgets/home/home_app_bar.dart';
import '../widgets/home/note_view_builder.dart';
import '../widgets/home/quick_add_todo_sheet.dart';
import '../widgets/home/universal_search_overlay.dart';
import '../widgets/home/home_tip_card.dart';
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
import '../widgets/bouncing_widget.dart';
import '../features/settings/presentation/screens/onboarding_screen.dart';
import '../utils/widget_helper.dart';
import '../l10n/app_localizations.dart';
import '../widgets/whats_new_sheet.dart';
import '../services/update_rating_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:note_taking_app/features/finances/presentation/widgets/receipt_scanner_sheet.dart';
import 'package:note_taking_app/features/sync/presentation/screens/p2p_sync_screen.dart';
import 'package:note_taking_app/data/transaction_model.dart';
import 'package:note_taking_app/data/category_constants.dart';

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
        unawaited(_openSharedAsNote(files));
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
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(WidgetHelper.updateWidgetData());
        unawaited(WidgetHelper.updateTodoWidgetData());
        unawaited(_checkAndProcessPendingIntents());
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

  /// Turns shared media (text, links, images) into a prefilled new note.
  Future<void> _openSharedAsNote(List<SharedMediaFile> files) async {
    final textParts = <String>[];
    final imagePaths = <String>[];

    for (final file in files) {
      switch (file.type) {
        case SharedMediaType.text:
        case SharedMediaType.url:
          if (file.path.trim().isNotEmpty) textParts.add(file.path.trim());
          break;
        case SharedMediaType.image:
          final copied = await _copySharedImage(file.path);
          if (copied != null) imagePaths.add(copied);
          break;
        default:
          break;
      }
    }

    if (textParts.isEmpty && imagePaths.isEmpty) return;
    if (!mounted) return;

    unawaited(
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) {
            final noteProvider = Provider.of<NoteProvider>(context, listen: false);
            return NoteEditorScreen(
              initialSharedText: textParts.isEmpty ? null : textParts.join('\n'),
              initialSharedImagePaths: imagePaths.isEmpty ? null : imagePaths,
              initialFolder: noteProvider.selectedFolder,
            );
          },
        ),
      ),
    );
  }

  /// Copies a shared image out of the transient share cache into app
  /// documents so the note's embed doesn't break when the cache is purged.
  Future<String?> _copySharedImage(String sourcePath) async {
    try {
      final source = File(sourcePath);
      if (!await source.exists()) return null;
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(docs.path, 'shared_images'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final target = p.join(dir.path,
          '${DateTime.now().millisecondsSinceEpoch}_${p.basename(sourcePath)}');
      await source.copy(target);
      return target;
    } catch (e) {
      debugPrint('Error copying shared image: $e');
      return sourcePath; // fall back to the cache path rather than dropping it
    }
  }

  Future<void> _checkAndProcessPendingIntents() async {
    // Shares parked by AppLockScreen (cold start or arrived-while-locked).
    final pendingShared = AppLockScreen.pendingSharedMedia;
    if (pendingShared != null && pendingShared.isNotEmpty) {
      AppLockScreen.pendingSharedMedia = null;
      unawaited(_openSharedAsNote(pendingShared));
      return;
    }

    try {
      const widgetChannel = MethodChannel('com.saadhjawwadh.notebook/widget');
      final String? action = await widgetChannel.invokeMethod<String>('getPendingAction');
      if (action == 'add_transaction' && mounted) {
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        if (settings.showFinancialManager) {
          final List<Widget> destinations = _buildDestinations(settings);
          int financesIndex = -1;
          for (int i = 0; i < destinations.length; i++) {
            if (destinations[i] is FinancialManagerScreen) {
              financesIndex = i;
              break;
            }
          }
          if (financesIndex != -1) {
            setState(() {
              _currentIndex = financesIndex;
            });
          }
        }
        if (mounted) {
          unawaited(
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TransactionEditorScreen()),
            ),
          );
        }
      } else if ((action == 'view_trends' || action == 'view_budgets' || action == 'view_ledger') && mounted) {
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        if (settings.showFinancialManager) {
          final List<Widget> destinations = _buildDestinations(settings);
          int financesIndex = -1;
          for (int i = 0; i < destinations.length; i++) {
            if (destinations[i] is FinancialManagerScreen) {
              financesIndex = i;
              break;
            }
          }
          if (financesIndex != -1) {
            setState(() {
              _currentIndex = financesIndex;
            });
            FinancialManagerScreen.tabRedirectNotifier.value =
                action == 'view_budgets' ? 'Budgets' : 'Ledger';
          }
        }
      } else if (action == 'new_note' && mounted) {
        final noteProvider = Provider.of<NoteProvider>(context, listen: false);
        unawaited(
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NoteEditorScreen(initialFolder: noteProvider.selectedFolder),
            ),
          ),
        );
      } else if (action == 'search' && mounted) {
        HomeAppBar.searchRequestedNotifier.value = true;
      } else if (action == 'scan_receipt' && mounted) {
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        if (settings.showFinancialManager) {
          final List<Widget> destinations = _buildDestinations(settings);
          int financesIndex = -1;
          for (int i = 0; i < destinations.length; i++) {
            if (destinations[i] is FinancialManagerScreen) {
              financesIndex = i;
              break;
            }
          }
          if (financesIndex != -1) {
            setState(() {
              _currentIndex = financesIndex;
            });
          }
        }
        unawaited(
          ReceiptScannerSheet.show(context).then((res) {
            if (res != null && mounted) {
              final double? total = res['total'] as double?;
              final String? merchant = res['merchant'] as String?;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TransactionEditorScreen(
                    transaction: TransactionModel(
                      amount: total ?? 0.0,
                      description: merchant ?? 'Scanned Receipt',
                      date: DateTime.now(),
                      isExpense: true,
                      category: CategoryConstants.shopping,
                    ),
                  ),
                ),
              );
            }
          }),
        );
      } else if (action == 'sync_devices' && mounted) {
        unawaited(
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const P2pSyncScreen()),
          ),
        );
      } else if (action == 'process_text' && mounted) {
        final String? sharedText =
            await widgetChannel.invokeMethod<String>('getPendingSharedText');
        if (sharedText != null && sharedText.trim().isNotEmpty && mounted) {
          final noteProvider = Provider.of<NoteProvider>(context, listen: false);
          unawaited(
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    NoteEditorScreen(
                      initialSharedText: sharedText,
                      initialFolder: noteProvider.selectedFolder,
                    ),
              ),
            ),
          );
        }
      } else if (action != null && action.startsWith('quick_add_todo') && mounted) {
        final parts = action.split(':');
        final targetNoteId = parts.length > 1 ? parts[1] : 'ALL_NOTES';
        unawaited(QuickAddTodoSheet.show(context, targetNoteId));
      }
    } catch (e) {
      debugPrint('Error getting pending widget action: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
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
        content: Text(ids.length == 1
            ? 'Note moved to Trash'
            : '${ids.length} notes moved to Trash'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            for (final id in ids) {
              await NoteRepository.instance.restoreNote(id);
            }
            await refreshNotes();
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

  Future<void> refreshNotes() async {
    if (!mounted) return;
    await context.read<NoteProvider>().refreshNotes();
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

  Future<void> bulkMoveToFolder() async {
    final noteProvider = context.read<NoteProvider>();
    if (noteProvider.selectedNoteIds.isEmpty) return;

    final allFolders = await NoteRepository.instance.getAllFolders();
    if (!mounted) return;

    final controller = TextEditingController();
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppLayout.radiusXXL),
        ),
        title: const Text('Move to folder'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: ListTile(
                        leading: const Icon(Icons.notes_outlined),
                        title: const Text('All Notes'),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppLayout.radiusM),
                        ),
                        onTap: () {
                          Navigator.pop(ctx, 'All Notes');
                        },
                      ),
                    ),
                    ...allFolders.map((f) => Material(
                          color: Colors.transparent,
                          child: ListTile(
                            leading: const Icon(Icons.folder_outlined),
                            title: Text(f),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppLayout.radiusM),
                            ),
                            onTap: () {
                              Navigator.pop(ctx, f);
                            },
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: AppLayout.spaceS),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'New folder name',
                  prefixIcon: const Icon(Icons.create_new_folder_outlined),
                  filled: false,
                  fillColor: Colors.transparent,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppLayout.radiusM),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppLayout.radiusM),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppLayout.radiusM),
                    borderSide: BorderSide(
                      color: Theme.of(ctx).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                ),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) Navigator.pop(ctx, v.trim());
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = controller.text.trim();
              if (v.isNotEmpty) Navigator.pop(ctx, v);
            },
            child: const Text('Create & Move'),
          ),
        ],
      ),
    );

    if (chosen == null || !mounted) return;
    final ids = noteProvider.selectedNoteIds.toList();
    final now = DateTime.now();
    for (final id in ids) {
      final note = await NoteRepository.instance.readNote(id);
      if (note != null) {
        await NoteRepository.instance.updateNote(
          note.copyWith(
            category: chosen == 'All Notes' ? '' : chosen,
            dateModified: now,
          ),
        );
      }
    }
    noteProvider.clearSelection();
    await refreshNotes();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(chosen == 'All Notes'
            ? '${ids.length} note${ids.length == 1 ? '' : 's'} removed from folder'
            : '${ids.length} note${ids.length == 1 ? '' : 's'} moved to "$chosen"'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> bulkTag() async {
    final noteProvider = context.read<NoteProvider>();
    final availableTags = noteProvider.allTags.where((t) => t != 'All' && t != 'Archived' && t != 'Trash').toList();
    if (availableTags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No tags available. Create a tag first.')));
      return;
    }

    final selectedNewTag = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Tag to Selected'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableTags.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(availableTags[index]),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
              ),
              onTap: () => Navigator.pop(context, availableTags[index]),
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
      ),
    );

    if (selectedNewTag != null) await noteProvider.bulkTag([selectedNewTag]);
  }

  Future<void> _editTag(String tag) async {
    final controller = TextEditingController(text: tag);
    int selectedColor = context.read<NoteProvider>().tagColors[tag] ?? 0;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text('Edit Tag'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: controller, decoration: const InputDecoration(labelText: 'Tag Name'), autofocus: true),
              const SizedBox(height: 16),
              const Text('Tag Color'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12, runSpacing: 12, alignment: WrapAlignment.center,
                children: AppTheme.noteColors.map((c) {
                  final bool isSystem = c.toARGB32() == 0;
                  final bool isSelected = !isSystem && selectedColor == c.toARGB32();
                  return Semantics(
                    button: true,
                    label: isSystem ? 'Random color' : 'Color swatch',
                    selected: isSelected,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                      onTap: () {
                        if (isSystem) {
                          final nonZeroColors = AppTheme.noteColors.where((color) => color.toARGB32() != 0).toList();
                          final randomColor = (nonZeroColors..shuffle()).first;
                          setDialogState(() => selectedColor = randomColor.toARGB32());
                        } else {
                          setDialogState(() => selectedColor = c.toARGB32());
                        }
                      },
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                        child: Center(
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isSystem ? Theme.of(context).colorScheme.surface : c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outlineVariant,
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                            child: isSystem
                                ? const Icon(Icons.shuffle, size: 16)
                                : (isSelected
                                    ? Icon(Icons.check,
                                        size: 16,
                                        color: c.computeLuminance() > 0.5 ? Colors.black : Colors.white)
                                    : null),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final newName = controller.text.trim();
                final noteProvider = context.read<NoteProvider>();
                if (newName.isNotEmpty) {
                  if (newName != tag) await NoteRepository.instance.renameTag(tag, newName);
                  if (selectedColor != (noteProvider.tagColors[tag] ?? 0)) await NoteRepository.instance.setTagColor(newName, selectedColor);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  await noteProvider.refreshNotes();
                  if (noteProvider.selectedTag == tag) noteProvider.setTag(newName);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _deleteTag(String tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tag?'),
        content: Text('Are you sure you want to delete "$tag"? This will remove the tag from all notes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error, foregroundColor: Theme.of(context).colorScheme.onError), onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed == true) {
      await NoteRepository.instance.deleteTag(tag);
      if (!mounted) return;
      final noteProvider = context.read<NoteProvider>();
      if (noteProvider.selectedTag == tag) noteProvider.setTag('All');
      await noteProvider.refreshNotes();
    }
  }

  void _showTagOptions(String tag) {
    if (tag == 'All' || tag == 'Archived' || tag == 'Trash') return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Edit Tag'), onTap: () { Navigator.pop(context); _editTag(tag); }),
            ListTile(leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error), title: Text('Delete Tag', style: TextStyle(color: Theme.of(context).colorScheme.error)), onTap: () { Navigator.pop(context); _deleteTag(tag); }),
          ],
        ),
      ),
    );
  }

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

      final noteProvider = context.watch<NoteProvider>();
      final finProvider = context.watch<FinancialManagerProvider>();

      final isNotesSelection = _currentIndex == 0 && noteProvider.isSelectionMode;
      final isFinancesSelection = settings.showFinancialManager && _currentIndex == 1 && finProvider.isSelectionMode;
      final isSelectionMode = isNotesSelection || isFinancesSelection;

      Widget? activeToolbar;
      if (isNotesSelection) {
        activeToolbar = _buildSelectionToolbar(context, noteProvider);
      } else if (isFinancesSelection) {
        activeToolbar = LedgerFloatingToolbar(
          onActionCompleted: () => FinancialManagerScreen.refreshNotifier.value++,
        );
      }

      final bool hasExtraFeatures = settings.showFinancialManager || settings.isPeriodTrackerEnabled;
      
      if (!hasExtraFeatures) {
        return Scaffold(
          extendBody: true,
          body: _buildNotesScaffold(context, settings),
          floatingActionButton: isSelectionMode ? null : _buildFAB(context),
          bottomNavigationBar: isSelectionMode
              ? activeToolbar
              : null,
        );
      }

      final List<Widget> destinations = _buildDestinations(settings);
      _currentIndex = _currentIndex.clamp(0, destinations.length - 1);

      final bool isTablet = MediaQuery.sizeOf(context).width >= 600;

      if (isTablet) {
        return Scaffold(
          extendBody: true,
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  if (noteProvider.isSelectionMode) noteProvider.clearSelection();
                  if (finProvider.isSelectionMode) finProvider.clearSelection();
                  setState(() => _currentIndex = index);
                },
                labelType: NavigationRailLabelType.all,
                destinations: _buildNavRailDestinations(settings),
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
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
        );
      }

      return Scaffold(
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
          switchInCurve: AppLayout.curveEmphasizedDecelerate,
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
                      if (noteProvider.isSelectionMode) noteProvider.clearSelection();
                      if (finProvider.isSelectionMode) finProvider.clearSelection();
                      setState(() => _currentIndex = index);
                    },
                    destinations: _buildNavDestinations(settings),
                  ),
                ),
        ),
      );
    });
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
            if (settings.showClarityMosaic &&
                noteProvider.searchQuery.isEmpty &&
                !noteProvider.isSelectionMode)
              const SliverToBoxAdapter(child: ClarityMosaicStrip()),
            if (settings.showTagFilterBar)
              SliverToBoxAdapter(child: TagFilterBar(onTagLongPress: _showTagOptions)),
            if (settings.showProTips &&
                settings.isTipDue &&
                noteProvider.searchQuery.isEmpty &&
                !noteProvider.isSelectionMode)
              SliverToBoxAdapter(
                child: HomeTipCard(
                  tip: HomeTipCard.getCatalog(context)[settings.currentTipIndex %
                      HomeTipCard.getCatalog(context).length],
                  onDismiss: () => settings.dismissCurrentTip(),
                  onDisable: () => settings.setShowProTips(false),
                ),
              ),
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
        if (returned == true) await refreshNotes();
      },
      secondaryAction: IconButton(
        tooltip: 'Templates',
        icon: Icon(Icons.style_outlined, color: colorScheme.onPrimaryContainer, size: 20),
        onPressed: () {
          _showTemplateSheet();
        },
      ),
    );
  }

  void _showTemplateSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Start from a template',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            ...NoteTemplate.all().map(
              (t) => ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(sheetContext).colorScheme.primaryContainer,
                  child: Icon(t.icon,
                      color: Theme.of(sheetContext)
                          .colorScheme
                          .onPrimaryContainer),
                ),
                title: Text(t.name),
                subtitle: Text(t.description),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final noteProvider = Provider.of<NoteProvider>(context, listen: false);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NoteEditorScreen(
                        templateTitle: t.title,
                        templateContent: t.contentDeltaJson,
                        initialFolder: noteProvider.selectedFolder,
                      ),
                    ),
                  );
                  await refreshNotes();
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// Keep NoteCard and NoteViewMode for now as they are used in many places.
class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Map<String, int>? tagColors;
  final bool isSelected;

  const NoteCard({super.key, required this.note, required this.onTap, this.onLongPress, this.tagColors, this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    final isSystemDefault = note.color == 0;
    final theme = Theme.of(context);
    Color backgroundColor;
    Color borderColor;

    if (isSystemDefault) {
      backgroundColor = theme.colorScheme.surface;
      borderColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.3);
    } else {
      final scheme = ColorScheme.fromSeed(seedColor: Color(note.color), brightness: theme.brightness);
      backgroundColor = scheme.surfaceContainerLow;
      borderColor = scheme.outline.withValues(alpha: 0.2);
    }

    final searchQuery = context.watch<NoteProvider>().searchQuery;

    final checkedCount = RegExp(r'"list"\s*:\s*"checked"').allMatches(note.content).length;
    final uncheckedCount = RegExp(r'"list"\s*:\s*"unchecked"').allMatches(note.content).length;
    final totalChecklistItems = checkedCount + uncheckedCount;

    return BouncingWidget(
      onTap: onTap,
      onLongPress: onLongPress != null
          ? () {
              AppHaptics.mediumImpact();
              onLongPress!();
            }
          : null,
      child: Container(
        padding: AppLayout.paddingAllL,
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primaryContainer : backgroundColor,
          borderRadius: BorderRadius.circular(AppLayout.radiusL),
          border: Border.all(color: isSelected ? theme.colorScheme.primary : borderColor, width: isSelected ? 2 : 1),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (note.title.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: HighlightedText(
                          text: note.title,
                          query: searchQuery,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold) ?? const TextStyle(),
                          highlightStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary) ?? const TextStyle(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (note.isPinned)
                        Padding(
                          padding: EdgeInsets.only(
                            left: AppLayout.spaceS,
                            right: isSelected ? 22.0 : 0.0,
                          ),
                          child: Icon(
                            Icons.push_pin,
                            size: AppLayout.iconS,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      else if (isSelected)
                        const SizedBox(width: 22.0),
                    ],
                  ),
                if (note.isLocked) ...[
                  const SizedBox(height: AppLayout.spaceS),
                  AppChip(
                    label: 'Locked Note',
                    icon: Icons.lock_outline,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    textColor: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
                if (!note.isLocked && note.imagePath != null) ...[
                  const SizedBox(height: AppLayout.spaceM),
                  ClipRRect(borderRadius: BorderRadius.circular(AppLayout.radiusL), child: Image.file(File(note.imagePath!), cacheWidth: 400, height: 120, width: double.infinity, fit: BoxFit.cover, alignment: Alignment.topCenter, errorBuilder: (c, e, s) => const SizedBox.shrink())),
                ],
                if (!note.isLocked && totalChecklistItems > 0) ...[
                  const SizedBox(height: AppLayout.spaceS),
                  AppChip(
                    label: '$checkedCount/$totalChecklistItems Done',
                    icon: checkedCount == totalChecklistItems
                        ? Icons.check_circle_outline_rounded
                        : Icons.checklist_rounded,
                    backgroundColor: checkedCount == totalChecklistItems
                        ? Colors.green.withValues(alpha: 0.15)
                        : theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
                    textColor: checkedCount == totalChecklistItems
                        ? Colors.green
                        : theme.colorScheme.onSecondaryContainer,
                  ),
                ],
                const SizedBox(height: AppLayout.spaceS),
                if (!note.isLocked && ((note.previewText?.isNotEmpty ?? false) || note.content.isNotEmpty))
                  Flexible(
                    child: HighlightedText(
                      text: note.previewText ?? '...',
                      query: searchQuery,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant) ?? const TextStyle(),
                      highlightStyle: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary) ?? const TextStyle(),
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (note.tags.isNotEmpty) ...[
                  const SizedBox(height: AppLayout.spaceM),
                  Wrap(
                    spacing: AppLayout.spaceXS, runSpacing: AppLayout.spaceXS,
                    children: [
                      ...note.tags.take(3).map((tag) {
                        final colorVal = tagColors?[tag];
                        Color bg = theme.colorScheme.secondaryContainer.withValues(alpha: 0.5);
                        Color fg = theme.colorScheme.onSecondaryContainer;
                        if (colorVal != null && colorVal != 0) {
                          final scheme = ColorScheme.fromSeed(seedColor: Color(colorVal), brightness: theme.brightness);
                          bg = scheme.primaryContainer;
                          fg = scheme.onPrimaryContainer;
                        }
                        return Container(padding: const EdgeInsets.symmetric(horizontal: AppLayout.spaceS, vertical: AppLayout.spaceXS), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppLayout.radiusStadium)), child: Text(tag, style: TextStyle(fontSize: 11.5, color: fg, fontWeight: FontWeight.w600)));
                      }),
                      if (note.tags.length > 3)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppLayout.spaceS, vertical: AppLayout.spaceXS),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                          ),
                          child: Text(
                            '+${note.tags.length - 3}',
                            style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
            if (isSelected)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    shape: BoxShape.circle,
                    boxShadow: AppLayout.softShadow(context),
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

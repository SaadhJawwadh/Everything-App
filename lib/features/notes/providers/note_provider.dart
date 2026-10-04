import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/note_repository.dart';
import '../../../data/note_model.dart';
import '../../../services/p2p_sync_service.dart';
import '../../../services/notification_service.dart';

class NoteProvider extends ChangeNotifier {
  final NoteRepository _noteRepository = NoteRepository();
  StreamSubscription? _syncEventsSubscription;
  List<Note> _notes = [];
  List<Note> _filteredNotes = [];
  bool _isLoading = true;
  String _selectedTag = 'All';
  List<String> _allTags = ['All'];
  final Set<String> _selectedNoteIds = {};
  bool _isSelectionMode = false;
  Map<String, int> _tagColors = {};

  final int _pageSize = 20;
  int _currentPage = 0;
  bool _isLoadingMore = false;
  bool _hasMoreNotes = true;
  String _sortMode = 'modified'; // modified | created | title | color
  Map<String, int> _tagCounts = {};
  String? _selectedFolder = 'Notes'; // default view = Notes folder
  List<String> _folders = [];
  final List<String> _emptyFolders = [];

  Map<String, int> _folderCounts = {};
  int _archivedCount = 0;
  int _trashCount = 0;

  // Getters
  List<Note> get notes => _notes;
  List<Note> get filteredNotes => _filteredNotes;
  bool get isLoading => _isLoading;
  String get selectedTag => _selectedTag;
  List<String> get allTags => _allTags;
  Set<String> get selectedNoteIds => _selectedNoteIds;
  bool get isSelectionMode => _isSelectionMode;
  Map<String, int> get tagColors => _tagColors;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreNotes => _hasMoreNotes;
  String get sortMode => _sortMode;
  Map<String, int> get tagCounts => _tagCounts;
  String? get selectedFolder => _selectedFolder;
  List<String> get folders => [..._folders, ..._emptyFolders]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  Map<String, int> get folderCounts => _folderCounts;
  int get archivedCount => _archivedCount;
  int get trashCount => _trashCount;
  bool _filterChecklistsOnly = false;
  bool get filterChecklistsOnly => _filterChecklistsOnly;
  int _checklistNotesCount = 0;
  int get checklistNotesCount {
    if (_checklistNotesCount > 0) return _checklistNotesCount;
    return _notes.where((n) =>
        n.content.contains('"list":"checked"') ||
        n.content.contains('"list":"unchecked"') ||
        n.content.contains('- [ ]') ||
        n.content.contains('- [x]')).length;
  }

  void setFilterChecklistsOnly(bool value) {
    if (_filterChecklistsOnly == value) return;
    _filterChecklistsOnly = value;
    _applySearchFilter();
    notifyListeners();
  }

  void setFolder(String? folder) {
    _filterChecklistsOnly = false;
    _selectedFolder = folder;
    SharedPreferences.getInstance().then((prefs) {
      if (folder == null) {
        prefs.remove('lastActiveFolder');
      } else {
        prefs.setString('lastActiveFolder', folder);
      }
    });
    refreshNotes();
  }

  void createFolder(String name) {
    final cleaned = name.trim();
    if (cleaned.isEmpty || cleaned == 'All Notes' || cleaned == 'Notes' || cleaned == 'All folders') return;
    if (!_folders.contains(cleaned) && !_emptyFolders.contains(cleaned)) {
      _emptyFolders.add(cleaned);
    }
    setFolder(cleaned);
  }

  NoteProvider() {
    _init();
    _syncEventsSubscription = P2pSyncService.instance.syncEvents.listen((result) {
      if (result.success && (result.syncedCount > 0 || result.receivedCount > 0)) {
        refreshNotes();
      }
    });
  }

  @override
  void dispose() {
    _syncEventsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadSortMode();
    await refreshNotes();
  }

  Future<void> _loadSortMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _sortMode = prefs.getString('noteSortMode') ?? 'modified';
      if (prefs.containsKey('lastActiveFolder')) {
        final savedFolder = prefs.getString('lastActiveFolder');
        _selectedFolder = (savedFolder == null || savedFolder.isEmpty) ? null : savedFolder;
      }
      if (prefs.containsKey('lastActiveTag')) {
        _selectedTag = prefs.getString('lastActiveTag') ?? 'All';
      }
    } catch (_) {}
  }

  Future<void> setSortMode(String mode) async {
    if (mode == _sortMode) return;
    _sortMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('noteSortMode', mode);
    await refreshNotes();
  }

  Future<void> refreshNotes({bool showLoading = false}) async {
    if (showLoading || _notes.isEmpty) {
      _isLoading = true;
      notifyListeners();
    }
    _currentPage = 0;
    _hasMoreNotes = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final purgeDays = prefs.getInt('trashAutoPurgeDays') ?? 30;
      final purgedCount = await _noteRepository.clearOldTrash(purgeDays);
      if (purgedCount > 0) {
        await NotificationService.showAutoPurgeNotification(purgedCount, purgeDays);
      }
      final tags = await _noteRepository.getAllTags();
      final colors = await _noteRepository.getAllTagColors();

      final fetchedNotes = await _noteRepository.readAllNotes(
        limit: _pageSize,
        offset: 0,
        tag: _selectedTag == 'All' || _selectedTag == 'Archived' || _selectedTag == 'Trash' ? null : _selectedTag,
        isArchived: _selectedTag == 'Archived',
        isTrashed: _selectedTag == 'Trash',
        sortMode: _sortMode,
        folder: _selectedFolder,
      );
      _tagCounts = await _noteRepository.getTagCounts();
      _folderCounts = await _noteRepository.getFolderCounts();
      _archivedCount = await _noteRepository.getArchivedCount();
      _trashCount = await _noteRepository.getTrashCount();
      _checklistNotesCount = await _noteRepository.getChecklistNotesCount(folder: _selectedFolder);
      _folders = await _noteRepository.getAllFolders();
      _emptyFolders.removeWhere((f) => _folders.contains(f));
      if (_selectedFolder != null &&
          _selectedFolder != 'Notes' &&
          _selectedFolder != 'All Notes' &&
          !_folders.contains(_selectedFolder) &&
          !_emptyFolders.contains(_selectedFolder)) {
        _emptyFolders.add(_selectedFolder!);
      }

      _allTags = ['All', ...tags];
      if (!_allTags.contains(_selectedTag)) {
        _selectedTag = 'All';
      }

      _tagColors = colors;
      _notes = fetchedNotes;
      _applySearchFilter();
      
      _isLoading = false;
      if (fetchedNotes.length < _pageSize) {
        _hasMoreNotes = false;
      }
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error refreshing notes: $e');
    }
  }

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    _searchQuery = query.trim().toLowerCase();
    _applySearchFilter();
    notifyListeners();
  }

  void _applySearchFilter() {
    Iterable<Note> result = _notes;

    if (_filterChecklistsOnly) {
      result = result.where((note) {
        return note.content.contains('"list":"checked"') ||
               note.content.contains('"list":"unchecked"') ||
               note.content.contains('- [ ]') ||
               note.content.contains('- [x]');
      });
    }

    if (_searchQuery.isNotEmpty) {
      result = result.where((note) {
        final titleMatch = note.title.toLowerCase().contains(_searchQuery);
        final contentMatch = note.content.toLowerCase().contains(_searchQuery);
        final tagMatch = note.tags.any((t) => t.toLowerCase().contains(_searchQuery));
        return titleMatch || contentMatch || tagMatch;
      });
    }

    _filteredNotes = result.toList();
  }

  void setTag(String tag) {
    _selectedTag = tag;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('lastActiveTag', tag);
    });
    refreshNotes();
  }

  Future<void> loadMoreNotes() async {
    if (_isLoadingMore || !_hasMoreNotes) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      _currentPage++;
      final moreNotes = await _noteRepository.readAllNotes(
        limit: _pageSize,
        offset: _currentPage * _pageSize,
        tag: _selectedTag == 'All' || _selectedTag == 'Archived' || _selectedTag == 'Trash' ? null : _selectedTag,
        isArchived: _selectedTag == 'Archived',
        isTrashed: _selectedTag == 'Trash',
        sortMode: _sortMode,
        folder: _selectedFolder,
      );

      if (moreNotes.length < _pageSize) {
        _hasMoreNotes = false;
      }

      // Avoid duplicates
      final existingIds = _notes.map((n) => n.id).toSet();
      final newNotes = moreNotes.where((n) => !existingIds.contains(n.id)).toList();
      
      _notes.addAll(newNotes);
      _filteredNotes = List.from(_notes);
    } catch (e) {
      debugPrint('Error loading more notes: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // Selection Logic
  void toggleSelection(String id) {
    if (_selectedNoteIds.contains(id)) {
      _selectedNoteIds.remove(id);
    } else {
      _selectedNoteIds.add(id);
    }
    _isSelectionMode = _selectedNoteIds.isNotEmpty;
    notifyListeners();
  }

  void clearSelection() {
    _selectedNoteIds.clear();
    _isSelectionMode = false;
    notifyListeners();
  }

  void selectAll() {
    _selectedNoteIds.addAll(_notes.map((n) => n.id));
    _isSelectionMode = _selectedNoteIds.isNotEmpty;
    notifyListeners();
  }

  // Bulk Actions
  /// Pins the selection; if every selected note is already pinned, unpins.
  Future<void> bulkTogglePin() async {
    final ids = _selectedNoteIds.toList();
    if (ids.isEmpty) return;
    final selected = _notes.where((n) => ids.contains(n.id));
    final allPinned =
        selected.isNotEmpty && selected.every((n) => n.isPinned);
    await _noteRepository.bulkSetPinned(ids, !allPinned);
    clearSelection();
    await refreshNotes();
  }

  Future<void> bulkArchive() async {
    await _noteRepository.bulkArchive(_selectedNoteIds.toList(), true);
    clearSelection();
    await refreshNotes();
  }

  /// Moves the selection to trash and returns the affected ids so callers
  /// can offer an undo.
  Future<List<String>> bulkDelete() async {
    final ids = _selectedNoteIds.toList();
    await _noteRepository.bulkDelete(ids);
    clearSelection();
    await refreshNotes();
    return ids;
  }

  Future<void> bulkTag(List<String> selectedTags) async {
    await _noteRepository.bulkTag(_selectedNoteIds.toList(), selectedTags);
    clearSelection();
    await refreshNotes();
  }

  // Tag Management
  Future<void> editTag(String oldTag, String newTag) async {
    if (newTag.isEmpty || newTag == oldTag || newTag.toLowerCase() == 'all') return;

    try {
      await _noteRepository.renameTag(oldTag, newTag);
      if (_selectedTag == oldTag) {
        _selectedTag = newTag;
      }
      await refreshNotes();
    } catch (e) {
      debugPrint('Error renaming tag: $e');
    }
  }

  Future<void> deleteTag(String tag) async {
    try {
      await _noteRepository.deleteTag(tag);
      if (_selectedTag == tag) {
        _selectedTag = 'All';
      }
      await refreshNotes();
    } catch (e) {
      debugPrint('Error deleting tag: $e');
    }
  }
}

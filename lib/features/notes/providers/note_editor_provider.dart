import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../data/note_model.dart';
import '../data/note_repository.dart';
import '../../sync/providers/p2p_sync_provider.dart';

/// ChangeNotifier managing state, auto-saving, and business logic for the Note Editor.
class NoteEditorProvider extends ChangeNotifier {
  final NoteRepository _repository = NoteRepository.instance;

  Note? _note;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isDirty = false;

  String _title = '';
  String _content = '';
  String _category = 'Notes';
  int _color = 0;
  bool _isPinned = false;
  List<String> _tags = [];
  DateTime? _reminderAt;

  Timer? _autoSaveTimer;

  Note? get note => _note;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isDirty => _isDirty;

  String get title => _title;
  String get content => _content;
  String get category => _category;
  int get color => _color;
  bool get isPinned => _isPinned;
  List<String> get tags => List.unmodifiable(_tags);
  DateTime? get reminderAt => _reminderAt;

  /// Initializes the provider with an existing note or a new draft note.
  Future<void> init(Note? initialNote, {String? defaultCategory}) async {
    _isLoading = true;
    notifyListeners();

    if (initialNote != null) {
      _note = initialNote;
      _title = initialNote.title;
      _content = initialNote.content;
      _category = initialNote.category;
      _color = initialNote.color;
      _isPinned = initialNote.isPinned;
      _tags = List.from(initialNote.tags);
      _reminderAt = initialNote.reminderAt;
    } else {
      final now = DateTime.now();
      _category = defaultCategory ?? 'Notes';
      _note = Note(
        id: const Uuid().v4(),
        title: '',
        content: '',
        dateCreated: now,
        dateModified: now,
        category: _category,
        color: 0,
        tags: [],
      );
    }

    _isDirty = false;
    _isLoading = false;
    notifyListeners();
  }

  void updateTitle(String newTitle) {
    if (_title != newTitle) {
      _title = newTitle;
      _markDirty();
    }
  }

  void updateContent(String newContent) {
    if (_content != newContent) {
      _content = newContent;
      _markDirty();
    }
  }

  void updateCategory(String newCategory) {
    if (_category != newCategory) {
      _category = newCategory;
      _markDirty();
    }
  }

  void updateColor(int newColor) {
    if (_color != newColor) {
      _color = newColor;
      _markDirty();
    }
  }

  void togglePinned() {
    _isPinned = !_isPinned;
    _markDirty();
  }

  void addTag(String tag) {
    if (!_tags.contains(tag)) {
      _tags.add(tag);
      _markDirty();
    }
  }

  void removeTag(String tag) {
    if (_tags.remove(tag)) {
      _markDirty();
    }
  }

  void setReminder(DateTime? dateTime) {
    _reminderAt = dateTime;
    _markDirty();
  }

  void _markDirty() {
    _isDirty = true;
    notifyListeners();
    _scheduleAutoSave();
  }

  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), () {
      saveNote();
    });
  }

  /// Persists current note state to database single-source-of-truth.
  Future<void> saveNote() async {
    if (_note == null || !_isDirty) return;
    if (_title.trim().isEmpty && _content.trim().isEmpty) return;

    _isSaving = true;
    notifyListeners();

    final now = DateTime.now();
    final updatedNote = _note!.copyWith(
      title: _title.trim(),
      content: _content,
      category: _category,
      color: _color,
      isPinned: _isPinned,
      tags: _tags,
      reminderAt: _reminderAt,
      clearReminderAt: _reminderAt == null,
      dateModified: now,
    );

    final existing = await _repository.readNote(updatedNote.id);
    if (existing != null) {
      await _repository.updateNote(updatedNote);
    } else {
      await _repository.createNote(updatedNote);
    }

    _note = updatedNote;
    _isDirty = false;
    _isSaving = false;
    notifyListeners();

    // Background auto-sync uses the provider's persisted peers and their
    // individual secrets/endpoints instead of an empty synthetic pairing.
    P2pSyncProvider.activeInstance?.triggerEventSync();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    super.dispose();
  }
}

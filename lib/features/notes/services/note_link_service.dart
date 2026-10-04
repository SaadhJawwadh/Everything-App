import 'package:flutter/material.dart';
import '../../../../data/note_model.dart';
import '../data/note_repository.dart';
import '../presentation/screens/note_editor_screen.dart';

/// Represents a parsed bi-directional note link (e.g. `[[Target Note Title]]`).
class NoteLink {
  final String targetTitle;
  final String rawMatch;
  final int startIndex;
  final int endIndex;

  const NoteLink({
    required this.targetTitle,
    required this.rawMatch,
    required this.startIndex,
    required this.endIndex,
  });
}

/// Service responsible for scanning, parsing, and resolving `[[Note Title]]` wiki-links.
class NoteLinkService {
  NoteLinkService._();

  static final RegExp noteLinkRegex = RegExp(r'\[\[([^\]\r\n]+)\]\]');

  /// Scans [text] and returns all embedded `[[Note Title]]` links.
  static List<NoteLink> scanLinks(String text) {
    if (text.isEmpty) return const [];
    final matches = noteLinkRegex.allMatches(text);
    final results = <NoteLink>[];

    for (final match in matches) {
      final target = match.group(1)?.trim() ?? '';
      if (target.isNotEmpty) {
        results.add(NoteLink(
          targetTitle: target,
          rawMatch: match.group(0) ?? '',
          startIndex: match.start,
          endIndex: match.end,
        ));
      }
    }
    return results;
  }

  /// Finds a note matching [targetTitle] (case-insensitive), or returns null.
  static Future<Note?> findMatchingNote(String targetTitle) async {
    final cleanTarget = targetTitle.trim().toLowerCase();
    if (cleanTarget.isEmpty) return null;

    final allNotes = await NoteRepository.instance.readAllNotes();
    for (final note in allNotes) {
      if (note.title.trim().toLowerCase() == cleanTarget) {
        return note;
      }
    }
    return null;
  }

  /// Navigates to the note matching [targetTitle].
  /// If the note does not exist yet, creates a new note with [targetTitle] and opens the editor.
  static Future<void> navigateToLinkedNote(BuildContext context, String targetTitle) async {
    final existing = await findMatchingNote(targetTitle);
    if (!context.mounted) return;

    if (existing != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NoteEditorScreen(note: existing),
        ),
      );
    } else {
      // Create new note with this target title
      final newNote = Note(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: targetTitle,
        content: '',
        dateCreated: DateTime.now(),
        dateModified: DateTime.now(),
      );
      await NoteRepository.instance.createNote(newNote);
      if (!context.mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NoteEditorScreen(note: newNote),
        ),
      );
    }
  }
}

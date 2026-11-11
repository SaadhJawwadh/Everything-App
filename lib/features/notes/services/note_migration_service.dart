import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:uuid/uuid.dart';
import '../../../data/database_helper.dart';
import '../../../data/database_constants.dart';
import '../../../data/note_model.dart';
import '../../../utils/rich_text_utils.dart';
import '../../../screens/app_lock_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../data/note_repository.dart';

class NoteMigrationResult {
  final int totalImported;
  final int skippedCount;
  final List<String> importedTitles;
  final Set<String> importedTags;
  final List<String> importedNoteIds;

  const NoteMigrationResult({
    required this.totalImported,
    required this.skippedCount,
    required this.importedTitles,
    required this.importedTags,
    this.importedNoteIds = const [],
  });
}

class NoteMigrationService {
  static const Map<String, int> _keepColorMap = {
    'DEFAULT': 0xFF252529,
    'RED': 0xFF5C2B29,
    'ORANGE': 0xFF614A19,
    'YELLOW': 0xFF635D19,
    'GREEN': 0xFF345920,
    'TEAL': 0xFF16504B,
    'BLUE': 0xFF2D555E,
    'DARK_BLUE': 0xFF1E3A5F,
    'PURPLE': 0xFF42275E,
    'PINK': 0xFF5B2245,
    'BROWN': 0xFF442F19,
    'GRAY': 0xFF3C3F41,
  };

  /// Pick one or more files (ZIP archive from Google Takeout, JSON, Markdown, or TXT)
  /// and parse them into Note models.
  static Future<List<Note>> pickAndParseNotes() async {
    final result = await AppLockScreen.withLockIgnored(() => FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['json', 'zip', 'md', 'txt'],
    ));

    if (result == null || result.files.isEmpty) return [];

    final parsedNotes = <Note>[];

    for (final file in result.files) {
      if (file.path == null) continue;
      final localFile = File(file.path!);
      if (!await localFile.exists()) continue;

      final ext = file.extension?.toLowerCase() ?? '';

      if (ext == 'zip') {
        final zipNotes = await _parseZipFile(localFile);
        parsedNotes.addAll(zipNotes);
      } else if (ext == 'json') {
        final note = await _parseJsonFile(localFile);
        if (note != null) parsedNotes.add(note);
      } else if (ext == 'md' || ext == 'txt') {
        final note = await _parseMarkdownFile(localFile);
        if (note != null) parsedNotes.add(note);
      }
    }

    return parsedNotes;
  }

  @visibleForTesting
  static Future<Note?> parseKeepJsonForTesting(String jsonStr, String fallbackFileName) =>
      _parseKeepJsonString(jsonStr, fallbackFileName);

  @visibleForTesting
  static Future<List<Note>> parseZipForTesting(File file) => _parseZipFile(file);

  /// Extracts and parses notes from a Google Takeout or backup ZIP file,
  /// including any attached photos or images. Offloads heavy decompression and
  /// JSON/Markdown parsing to a background isolate.
  static Future<List<Note>> _parseZipFile(File file) async {
    Directory? targetDir;
    try {
      targetDir = await getApplicationDocumentsDirectory();
    } catch (_) {
      targetDir = Directory.systemTemp;
    }
    final targetDirPath = targetDir.path;
    final filePath = file.path;

    return await Isolate.run<List<Note>>(() async {
      return _parseZipFileInternal(filePath, targetDirPath);
    });
  }

  static Future<List<Note>> _parseZipFileInternal(String filePath, String targetDirPath) async {
    final notes = <Note>[];
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final targetDir = Directory(targetDirPath);

      // Index all image files in the ZIP archive
      final imageFiles = <String, ArchiveFile>{};
      for (final archiveFile in archive) {
        if (!archiveFile.isFile) continue;
        final name = archiveFile.name.toLowerCase();
        if (name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png') || name.endsWith('.webp')) {
          final cleanBaseName = archiveFile.name.split('/').last.split('\\').last.toLowerCase();
          imageFiles[cleanBaseName] = archiveFile;
        }
      }

      for (final archiveFile in archive) {
        if (!archiveFile.isFile) continue;
        final rawName = archiveFile.name;
        final baseName = rawName.split('/').last.split('\\').last.toLowerCase();

        if (baseName.endsWith('.json') && !baseName.contains('manifest') && baseName != 'takeout.json') {
          try {
            final content = utf8.decode(archiveFile.content as List<int>);
            final note = await _parseKeepJsonString(
              content,
              archiveFile.name,
              imageFiles: imageFiles,
              targetDir: targetDir,
            );
            if (note != null) notes.add(note);
          } catch (_) {}
        } else if (baseName.endsWith('.md') || baseName.endsWith('.txt')) {
          try {
            final content = utf8.decode(archiveFile.content as List<int>);
            final note = _parseMarkdownString(content, archiveFile.name);
            if (note != null) notes.add(note);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[NoteMigrationService] Error reading ZIP: $e');
    }
    return notes;
  }

  static Future<Note?> _parseJsonFile(File file) async {
    try {
      Directory? targetDir;
      try {
        targetDir = await getApplicationDocumentsDirectory();
      } catch (_) {
        targetDir = Directory.systemTemp;
      }
      final targetDirPath = targetDir.path;
      final filePath = file.path;
      final parentDirPath = file.parent.path;
      final fileName = file.uri.pathSegments.last;

      return await Isolate.run(() async {
        final localFile = File(filePath);
        final content = await localFile.readAsString();
        return await _parseKeepJsonString(
          content,
          fileName,
          sourceDir: Directory(parentDirPath),
          targetDir: Directory(targetDirPath),
        );
      });
    } catch (e) {
      debugPrint('[NoteMigrationService] Error parsing JSON file: $e');
      return null;
    }
  }

  static Future<Note?> _parseMarkdownFile(File file) async {
    try {
      final content = await file.readAsString();
      final fileName = file.uri.pathSegments.last;
      final fileStat = await file.stat();
      return _parseMarkdownString(
        content,
        fileName,
        dateCreated: fileStat.changed,
        dateModified: fileStat.modified,
      );
    } catch (e) {
      debugPrint('[NoteMigrationService] Error parsing Markdown file: $e');
      return null;
    }
  }

  /// Parses a Google Keep JSON payload.
  static Future<Note?> _parseKeepJsonString(
    String jsonStr,
    String fallbackFileName, {
    Map<String, ArchiveFile>? imageFiles,
    Directory? sourceDir,
    Directory? targetDir,
  }) async {
    try {
      final data = jsonDecode(jsonStr);
      if (data is! Map<String, dynamic>) return null;

      // Ensure this looks like a Keep note
      final hasText = data.containsKey('textContent');
      final hasList = data.containsKey('listContent');
      final hasTitle = data.containsKey('title');
      final hasAnnotations = data.containsKey('annotations');
      if (!hasText && !hasList && !hasTitle && !hasAnnotations) return null;

      String title = (data['title'] as String?)?.trim() ?? '';

      // Clean fallback filename (strip folders like 'Takeout/Keep/', extensions, and replace underscores)
      final cleanBaseName = fallbackFileName
          .split('/')
          .last
          .split('\\')
          .last
          .replaceAll(RegExp(r'\.(json|html|md|txt)$', caseSensitive: false), '')
          .replaceAll('_', ' ')
          .trim();

      // Check if filename is an ISO timestamp (e.g. "2025-09-21T22 54 57.487+05 30")
      final isTimestampFilename = RegExp(r'^\d{4}[-_]\d{2}[-_]\d{2}T', caseSensitive: false).hasMatch(cleanBaseName) ||
          RegExp(r'^\d{4}[-_]\d{2}[-_]\d{2}').hasMatch(cleanBaseName);

      if (title.isEmpty) {
        // 1. Check annotations for web bookmark title
        if (data['annotations'] is List && (data['annotations'] as List).isNotEmpty) {
          for (final ann in (data['annotations'] as List)) {
            if (ann is Map && ann['title'] != null) {
              final annTitle = ann['title'].toString().trim();
              if (annTitle.isNotEmpty) {
                title = annTitle;
                break;
              }
            }
          }
        }

        // 2. Smart First-Line promotion: check if textContent starts with a short heading line
        String rawText = (data['textContent'] as String?)?.trim() ?? '';
        if (title.isEmpty && rawText.isNotEmpty) {
          final lines = rawText.split('\n');
          final firstLine = lines.first.trim();
          if (firstLine.isNotEmpty &&
              firstLine.length <= 45 &&
              lines.length > 1 &&
              !firstLine.endsWith(',') &&
              !firstLine.endsWith(';') &&
              !firstLine.endsWith('...')) {
            title = firstLine;
            // Remove the promoted first line from textContent to avoid duplicate text
            data['textContent'] = lines.sublist(1).join('\n').trim();
          }
        }

        // 3. Fallback to clean filename ONLY if it was human-named (not an ISO machine timestamp)
        if (title.isEmpty && !isTimestampFilename && cleanBaseName.isNotEmpty) {
          title = cleanBaseName;
        }

        // 4. If still empty, title remains "" (clean titleless note without awkward cutoffs)
      }

      final tags = <String>[];
      if (data['labels'] is List) {
        for (final label in data['labels']) {
          if (label is Map && label['name'] != null) {
            final tagName = label['name'].toString().trim();
            if (tagName.isNotEmpty && !tags.contains(tagName)) {
              tags.add(tagName);
            }
          }
        }
      }

      // Timestamps (Google Keep uses microseconds since epoch)
      DateTime dateCreated = DateTime.now();
      DateTime dateModified = DateTime.now();
      if (data['createdTimestampUsec'] != null) {
        final usec = int.tryParse(data['createdTimestampUsec'].toString()) ?? 0;
        if (usec > 0) dateCreated = DateTime.fromMicrosecondsSinceEpoch(usec);
      }
      if (data['userEditedTimestampUsec'] != null) {
        final usec = int.tryParse(data['userEditedTimestampUsec'].toString()) ?? 0;
        if (usec > 0) dateModified = DateTime.fromMicrosecondsSinceEpoch(usec);
      }

      final isPinned = data['isPinned'] == true;
      final isArchived = data['isArchived'] == true;

      // Color mapping
      int noteColor = 0xFF252529;
      if (data['color'] != null) {
        final colorKey = data['color'].toString().toUpperCase();
        noteColor = _keepColorMap[colorKey] ?? 0xFF252529;
      }

      // Extract image attachment if present in ZIP archive or local extracted folder
      String? savedImagePath;
      if (data['attachments'] is List && targetDir != null) {
        for (final att in (data['attachments'] as List)) {
          if (att is Map && att['filePath'] != null) {
            final rawPath = att['filePath'].toString();
            final attName = rawPath.split('/').last.split('\\').last;
            final ext = attName.contains('.') ? '.${attName.split('.').last}' : '.jpg';

            // 1. Check ZIP archive entries first
            if (imageFiles != null) {
              final matchedFile = imageFiles[attName.toLowerCase()];
              if (matchedFile != null) {
                final outPath = '${targetDir.path}/keep_att_${const Uuid().v4()}$ext';
                final outFile = File(outPath);
                await outFile.writeAsBytes(matchedFile.content as List<int>);
                savedImagePath = outPath;
                break;
              }
            }

            // 2. Check local source directory from extracted Takeout folder
            if (sourceDir != null) {
              final localFile = File('${sourceDir.path}/$attName');
              if (await localFile.exists()) {
                final outPath = '${targetDir.path}/keep_att_${const Uuid().v4()}$ext';
                await localFile.copy(outPath);
                savedImagePath = outPath;
                break;
              }
            }
          }
        }
      }

      // Content & Checklist Delta creation
      Delta delta = Delta();

      if (data['listContent'] is List && (data['listContent'] as List).isNotEmpty) {
        // If there's leading text content, insert it first
        final textContent = (data['textContent'] as String?)?.trim() ?? '';
        if (textContent.isNotEmpty) {
          delta.insert('$textContent\n');
        }

        final listItems = data['listContent'] as List;
        for (final item in listItems) {
          if (item is Map) {
            final itemText = (item['text'] as String?)?.trim() ?? '';
            final isChecked = item['isChecked'] == true;
            if (itemText.isNotEmpty) {
              if (isChecked) {
                delta.insert(itemText, {'strike': true});
              } else {
                delta.insert(itemText);
              }
              delta.insert('\n', {'list': isChecked ? 'checked' : 'unchecked'});
            }
          }
        }

        // Also append annotations (web links) if present on checklist note
        if (data['annotations'] is List && (data['annotations'] as List).isNotEmpty) {
          for (final ann in (data['annotations'] as List)) {
            if (ann is Map) {
              final url = (ann['url'] as String?)?.trim() ?? '';
              final annTitle = (ann['title'] as String?)?.trim() ?? '';
              if (url.isNotEmpty) {
                final label = annTitle.isNotEmpty ? annTitle : url;
                delta.insert('\n$label: $url\n');
              }
            }
          }
        }
      } else {
        // Plain text note / Web Bookmark
        String textContent = (data['textContent'] as String?) ?? '';

        // Extract web links / bookmarks from Keep annotations if present
        if (data['annotations'] is List && (data['annotations'] as List).isNotEmpty) {
          final buffer = StringBuffer();
          for (final ann in (data['annotations'] as List)) {
            if (ann is Map) {
              final url = (ann['url'] as String?)?.trim() ?? '';
              final annTitle = (ann['title'] as String?)?.trim() ?? '';
              final description = (ann['description'] as String?)?.trim() ?? '';
              if (url.isNotEmpty) {
                if (buffer.isNotEmpty) buffer.writeln();
                final displayTitle = annTitle.isNotEmpty ? annTitle : url;
                buffer.writeln('[$displayTitle]($url)');
                if (description.isNotEmpty && description != annTitle) {
                  buffer.writeln(description);
                }
              }
            }
          }
          if (buffer.isNotEmpty) {
            if (textContent.trim().isNotEmpty) {
              textContent = '$textContent\n\n$buffer';
            } else {
              textContent = buffer.toString();
            }
          }
        }

        if (textContent.isNotEmpty) {
          delta = RichTextUtils.markdownToDelta(textContent);
        } else {
          delta.insert('\n');
        }
      }

      final contentJson = RichTextUtils.deltaToJson(delta);

      return Note(
        id: const Uuid().v4(),
        title: title,
        content: contentJson,
        dateCreated: dateCreated,
        dateModified: dateModified,
        color: noteColor,
        isPinned: isPinned,
        isArchived: isArchived,
        tags: tags,
        imagePath: savedImagePath,
      );
    } catch (e) {
      debugPrint('[NoteMigrationService] Keep parse error: $e');
      return null;
    }
  }

  /// Parses Markdown / Plain text note content.
  static Note? _parseMarkdownString(
    String markdownStr,
    String fallbackFileName, {
    DateTime? dateCreated,
    DateTime? dateModified,
  }) {
    if (markdownStr.trim().isEmpty) return null;

    final lines = markdownStr.split('\n');
    String title = '';
    int bodyStartIndex = 0;

    // Check if line 0 is a markdown title '# ...'
    if (lines.isNotEmpty && lines.first.trim().startsWith('# ')) {
      title = lines.first.trim().substring(2).trim();
      bodyStartIndex = 1;
    } else {
      title = fallbackFileName
          .split('/')
          .last
          .split('\\')
          .last
          .replaceAll(RegExp(r'\.(md|txt)$', caseSensitive: false), '')
          .replaceAll('_', ' ')
          .trim();
    }

    final body = lines.skip(bodyStartIndex).join('\n').trim();
    final delta = RichTextUtils.markdownToDelta(body.isNotEmpty ? body : title);
    final contentJson = RichTextUtils.deltaToJson(delta);

    final tags = <String>[];
    // Extract hashtag labels e.g. #personal, #work
    final tagRegex = RegExp(r'(?:^|\s)#([a-zA-Z0-9_\-]+)');
    for (final match in tagRegex.allMatches(body)) {
      final tag = match.group(1)?.trim();
      if (tag != null && tag.isNotEmpty && !tags.contains(tag)) {
        tags.add(tag);
      }
    }

    return Note(
      id: const Uuid().v4(),
      title: title,
      content: contentJson,
      dateCreated: dateCreated ?? DateTime.now(),
      dateModified: dateModified ?? DateTime.now(),
      color: 0xFF252529,
      tags: tags,
    );
  }

  /// Batch inserts parsed notes and their tags non-destructively into SQLite with deduplication.
  static Future<NoteMigrationResult> batchInsertNotes(List<Note> notes) async {
    if (notes.isEmpty) {
      return const NoteMigrationResult(
        totalImported: 0,
        skippedCount: 0,
        importedTitles: [],
        importedTags: {},
        importedNoteIds: [],
      );
    }

    final db = await DatabaseHelper.instance.database;
    final importedTitles = <String>[];
    final importedTags = <String>{};
    final importedNoteIds = <String>[];
    int importedCount = 0;
    int skippedCount = 0;

    await db.transaction((txn) async {
      for (final note in notes) {
        // Fast deduplication check: skip if identical non-deleted note already exists
        final existing = await txn.query(
          TableNames.notes,
          columns: ['id'],
          where: 'dateCreated = ? AND title = ? AND content = ? AND deletedAt IS NULL',
          whereArgs: [note.dateCreated.toIso8601String(), note.title, note.content],
          limit: 1,
        );

        if (existing.isNotEmpty) {
          skippedCount++;
          continue;
        }

        final enriched = NoteRepository.instance.enrichNoteWithPreview(note);

        await txn.insert(
          TableNames.notes,
          enriched.toMap(),
        );

        for (final tag in enriched.tags) {
          if (tag.trim().isEmpty) continue;
          importedTags.add(tag.trim());
          await txn.insert(
            'tags',
            {'name': tag.trim(), 'color': 0xFF6366F1},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          await txn.insert(
            'note_tags',
            {'note_id': enriched.id, 'tag_name': tag.trim()},
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }

        importedTitles.add(note.title.isNotEmpty ? note.title : 'Untitled');
        importedNoteIds.add(enriched.id);
        importedCount++;
      }
    });

    return NoteMigrationResult(
      totalImported: importedCount,
      skippedCount: skippedCount,
      importedTitles: importedTitles,
      importedTags: importedTags,
      importedNoteIds: importedNoteIds,
    );
  }

  /// Rolls back a recent import batch by soft-deleting the specified note IDs into the Trash.
  static Future<int> undoImport(List<String> noteIds) async {
    if (noteIds.isEmpty) return 0;
    final db = await DatabaseHelper.instance.database;
    final placeholders = List.filled(noteIds.length, '?').join(',');
    final nowIso = DateTime.now().toIso8601String();

    final count = await db.rawUpdate(
      'UPDATE ${TableNames.notes} SET deletedAt = ? WHERE id IN ($placeholders) AND deletedAt IS NULL',
      [nowIso, ...noteIds],
    );
    return count;
  }
}

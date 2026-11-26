import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../screens/app_lock_screen.dart';

/// Platform and media operations for Story Cards:
/// - Native MediaStore gallery saving (Pictures/EverythingApp)
/// - Native clipboard image copying (content URI)
/// - System share sheet integration
class StoryCardMediaService {
  static const MethodChannel _mediaChannel =
      MethodChannel('com.saadhjawwadh.notebook/story_media');

  const StoryCardMediaService();

  /// Saves the rendered story card image to the device gallery or public Pictures folder.
  ///
  /// On Android, this writes to `MediaStore.Images.Media` (`Pictures/EverythingApp`)
  /// so that the image is instantly accessible in Google Photos / Gallery.
  Future<String?> saveImageToGallery(Uint8List bytes, {String? filename}) async {
    final name = filename ?? 'story_${DateTime.now().millisecondsSinceEpoch}.png';

    if (Platform.isAndroid) {
      try {
        final result = await _mediaChannel.invokeMapMethod<String, dynamic>(
          'saveImageToGallery',
          {
            'bytes': bytes,
            'filename': name,
          },
        );
        if (result != null && result['success'] == true) {
          return result['path'] as String? ?? 'Pictures/EverythingApp/$name';
        }
      } catch (e) {
        debugPrint('StoryCardMediaService: native MediaStore save failed: $e, falling back...');
      }
    }

    // Fallback: save to application documents directory
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${appDocDir.path}/story_cards');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }
      final file = File('${exportDir.path}/$name');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      debugPrint('StoryCardMediaService: fallback save failed: $e');
      return null;
    }
  }

  /// Copies the rendered story card image directly to the system clipboard.
  ///
  /// On Android, puts an image content URI on the [ClipboardManager], allowing direct
  /// 1-tap pasting into WhatsApp, Instagram Stories, Telegram, X, and messages.
  Future<bool> copyImageToClipboard(
    Uint8List bytes, {
    String? filename,
    String? fallbackText,
  }) async {
    final name = filename ?? 'story_clip_${DateTime.now().millisecondsSinceEpoch}.png';
    bool imageCopied = false;

    if (Platform.isAndroid) {
      try {
        final res = await _mediaChannel.invokeMethod<bool>(
          'copyImageToClipboard',
          {
            'bytes': bytes,
            'filename': name,
          },
        );
        imageCopied = res ?? false;
      } catch (e) {
        debugPrint('StoryCardMediaService: native copyImageToClipboard failed: $e');
      }
    }

    // Always copy fallback text if provided so clipboard isn't empty on non-supported platforms
    if (fallbackText != null && fallbackText.isNotEmpty && !imageCopied) {
      await Clipboard.setData(ClipboardData(text: fallbackText));
    }

    return imageCopied;
  }

  /// Shares the story card via native OS share sheet.
  Future<bool> shareImage(
    Uint8List bytes, {
    required String title,
    String? filename,
  }) async {
    final name = filename ?? 'story_share_${DateTime.now().millisecondsSinceEpoch}.png';
    try {
      final tempDir = await getTemporaryDirectory();
      final cutoff = DateTime.now().subtract(const Duration(hours: 1));
      await for (final entity in tempDir.list()) {
        if (entity is File) {
          final baseName = entity.uri.pathSegments.last;
          if (baseName.startsWith('story_share_') && baseName.endsWith('.png')) {
            try {
              final stat = await entity.stat();
              if (stat.modified.isBefore(cutoff)) {
                await entity.delete();
              }
            } catch (_) {}
          }
        }
      }

      final file = File('${tempDir.path}/$name');
      await file.writeAsBytes(bytes);

      final result = await AppLockScreen.withLockIgnored(
        () => Share.shareXFiles(
          [XFile(file.path)],
          text: title.isNotEmpty ? title : 'Story Note',
        ),
      );
      return result.status == ShareResultStatus.success;
    } catch (e) {
      debugPrint('StoryCardMediaService: shareImage failed: $e');
      return false;
    }
  }

  /// Shares multiple pre-rendered story slide PNG files in one OS share sheet.
  Future<bool> shareMultipleImageFiles(
    List<File> files, {
    required String title,
  }) async {
    if (files.isEmpty) return false;
    try {
      return await AppLockScreen.withLockIgnored(() async {
        final result = await Share.shareXFiles(
          files.map((f) => XFile(f.path)).toList(),
          text: title.isNotEmpty ? title : 'Story Note',
        );
        return result.status == ShareResultStatus.success;
      });
    } catch (e) {
      debugPrint('StoryCardMediaService: shareMultipleImageFiles failed: $e');
      return false;
    }
  }

  /// Saves multiple pre-rendered story slide PNG files sequentially to gallery.
  Future<int> saveMultipleImageFilesToGallery(List<File> files) async {
    int savedCount = 0;
    for (int i = 0; i < files.length; i++) {
      try {
        final bytes = await files[i].readAsBytes();
        final path = await saveImageToGallery(
          bytes,
          filename: 'story_${DateTime.now().millisecondsSinceEpoch}_slide${i + 1}.png',
        );
        if (path != null) savedCount++;
      } catch (_) {}
    }
    return savedCount;
  }
}

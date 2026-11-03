import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_bottom_sheet.dart';
import '../../../../screens/app_lock_screen.dart';

/// Coordinates media insertion (Camera, Gallery) and persistent image storage for notes.
class NoteMediaCoordinator {
  static void showImageOptions({
    required BuildContext context,
    required Future<void> Function(ImageSource source) onPickImage,
  }) {
    AppBottomSheet.show(
      context: context,
      title: 'Insert Image',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Gallery'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppLayout.radiusM),
            ),
            onTap: () => onPickImage(ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Camera'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppLayout.radiusM),
            ),
            onTap: () => onPickImage(ImageSource.camera),
          ),
        ],
      ),
    );
  }

  static Future<String?> pickAndSaveImage(ImageSource source) async {
    final picker = ImagePicker();
    try {
      AppLockScreen.ignoreNextResumeLock();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final imagesDir = Directory(p.join(appDir.path, 'note_images'));
        if (!await imagesDir.exists()) {
          await imagesDir.create(recursive: true);
        }
        final ext = p.extension(pickedFile.path);
        final uniqueName = '${const Uuid().v4()}$ext';
        final savedFile = await File(pickedFile.path).copy(p.join(imagesDir.path, uniqueName));
        return savedFile.path;
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
    return null;
  }
}

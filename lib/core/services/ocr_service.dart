import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../screens/app_lock_screen.dart';

/// Shared offline OCR service powered by Google ML Kit Text Recognition.
class OcrService {
  const OcrService._();

  /// Extracts plain text from an image file on disk using on-device ML Kit.
  /// Always closes the native recognizer in `finally`.
  static Future<String?> extractTextFromImage(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) return null;

    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognized = await textRecognizer.processImage(inputImage);
      final trimmed = recognized.text.trim();
      return trimmed.isEmpty ? null : trimmed;
    } catch (e) {
      debugPrint('[OcrService] Error extracting text: $e');
      return null;
    } finally {
      await textRecognizer.close();
    }
  }

  /// Launches the camera or gallery while suppressing App Lock resume checks,
  /// extracts text on-device, and cleans up the temporary picked file.
  static Future<String?> pickAndExtractText(ImageSource source) async {
    final picker = ImagePicker();
    return AppLockScreen.withLockIgnored(() async {
      final picked = await picker.pickImage(source: source);
      if (picked == null) return null;
      try {
        return await extractTextFromImage(picked.path);
      } finally {
        try {
          final tmp = File(picked.path);
          if (await tmp.exists()) {
            await tmp.delete();
          }
        } catch (_) {}
      }
    });
  }
}

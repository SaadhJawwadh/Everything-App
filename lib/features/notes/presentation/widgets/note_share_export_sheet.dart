import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_bottom_sheet.dart';
import '../../../../core/ui/app_snack_bar.dart';
import '../../../../screens/app_lock_screen.dart';
import '../../../../utils/rich_text_utils.dart';

/// Modal bottom sheet presenting options to share notes as plain text, markdown, text file, or Story Card.
class NoteShareExportSheet {
  static void show({
    required BuildContext context,
    required String title,
    required Delta delta,
    required String plainText,
    required VoidCallback onOpenStoryCard,
  }) {
    final markdown = RichTextUtils.deltaToMarkdown(delta);
    final shareContent = title.isEmpty ? plainText : '$title\n\n$plainText';
    final colorScheme = Theme.of(context).colorScheme;

    AppBottomSheet.show(
      context: context,
      title: 'Share & Export Note',
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera_back_rounded, color: colorScheme.primary),
              title: const Text('Create Story Card'),
              subtitle: const Text('Export quote as a stylish image for social stories'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
              ),
              onTap: () {
                Navigator.pop(context);
                onOpenStoryCard();
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet_outlined),
              title: const Text('Share as Plain Text'),
              subtitle: const Text('Send text to other apps or messaging'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
              ),
              onTap: () {
                Navigator.pop(context);
                if (shareContent.isNotEmpty) {
                  AppLockScreen.ignoreNextResumeLock();
                  Share.share(shareContent, subject: title.isEmpty ? 'Note' : title);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.code_outlined),
              title: const Text('Share as Markdown'),
              subtitle: const Text('Preserve bold, lists, and headers formatting'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
              ),
              onTap: () {
                Navigator.pop(context);
                final mdContent = title.isEmpty ? markdown : '# $title\n\n$markdown';
                if (mdContent.isNotEmpty) {
                  AppLockScreen.ignoreNextResumeLock();
                  Share.share(mdContent, subject: title.isEmpty ? 'Note' : title);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Export as Text File'),
              subtitle: const Text('Save note as a .txt document'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
              ),
              onTap: () async {
                Navigator.pop(context);
                final tempDir = await getTemporaryDirectory();
                final safeTitle = (title.isEmpty ? 'Note' : title).replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
                final file = File('${tempDir.path}/$safeTitle.txt');
                await file.writeAsString(shareContent);
                AppLockScreen.ignoreNextResumeLock();
                await Share.shareXFiles([XFile(file.path)], text: title.isEmpty ? 'Note Export' : title);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copy to Clipboard'),
              subtitle: const Text('Copy note content to clipboard'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
              ),
              onTap: () async {
                Navigator.pop(context);
                if (shareContent.isNotEmpty) {
                  await Clipboard.setData(ClipboardData(text: shareContent));
                  if (context.mounted) {
                    AppSnackBar.show(context, message: 'Note copied to clipboard');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

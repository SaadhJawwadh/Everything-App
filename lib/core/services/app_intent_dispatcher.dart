import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../data/transaction_model.dart';
import '../../data/category_constants.dart';
import '../../features/finances/presentation/screens/financial_manager_screen.dart';
import '../../features/finances/presentation/screens/transaction_editor_screen.dart';
import '../../features/finances/presentation/widgets/receipt_scanner_sheet.dart';
import '../../features/notes/data/note_repository.dart';
import '../../features/notes/presentation/screens/note_editor_screen.dart';
import '../../features/notes/providers/note_provider.dart';
import '../../screens/app_lock_screen.dart';
import '../../features/settings/providers/settings_provider.dart';
import '../../features/sync/presentation/screens/p2p_sync_screen.dart';
import '../../widgets/home/home_app_bar.dart';
import '../../widgets/home/quick_add_todo_sheet.dart';

class AppIntentDispatcher {
  AppIntentDispatcher._();

  static const MethodChannel _widgetChannel =
      MethodChannel('com.saadhjawwadh.notebook/widget');

  /// Handles incoming shared media (text, links, images) by prefilling a new note editor.
  static Future<void> handleSharedMedia(
    BuildContext context,
    List<SharedMediaFile> files,
  ) async {
    final textParts = <String>[];
    final imagePaths = <String>[];

    for (final file in files) {
      switch (file.type) {
        case SharedMediaType.text:
        case SharedMediaType.url:
          if (file.path.trim().isNotEmpty) textParts.add(file.path.trim());
          break;
        case SharedMediaType.image:
          final copied = await copySharedImage(file.path);
          if (copied != null) imagePaths.add(copied);
          break;
        default:
          break;
      }
    }

    if (textParts.isEmpty && imagePaths.isEmpty) return;
    if (!context.mounted) return;

    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditorScreen(
          initialSharedText: textParts.isEmpty ? null : textParts.join('\n'),
          initialSharedImagePaths: imagePaths.isEmpty ? null : imagePaths,
          initialFolder: noteProvider.selectedFolder,
        ),
      ),
    );
  }

  /// Copies a shared image out of the transient share cache into app documents.
  static Future<String?> copySharedImage(String sourcePath) async {
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
      return sourcePath;
    }
  }

  /// Checks and processes pending intents from AppLockScreen or Native Widgets.
  static Future<void> processPendingIntents({
    required BuildContext context,
    required void Function(int tabIndex)? onSwitchTab,
    required List<Widget> destinations,
  }) async {
    final pendingShared = AppLockScreen.pendingSharedMedia;
    if (pendingShared != null && pendingShared.isNotEmpty) {
      AppLockScreen.pendingSharedMedia = null;
      await handleSharedMedia(context, pendingShared);
      return;
    }

    try {
      final String? action =
          await _widgetChannel.invokeMethod<String>('getPendingAction');
      if (action == null || !context.mounted) return;

      void switchToFinancesIfAvailable() {
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        if (settings.showFinancialManager && onSwitchTab != null) {
          int financesIndex = -1;
          for (int i = 0; i < destinations.length; i++) {
            if (destinations[i] is FinancialManagerScreen) {
              financesIndex = i;
              break;
            }
          }
          if (financesIndex != -1) {
            onSwitchTab(financesIndex);
          }
        }
      }

      if (action == 'add_transaction') {
        switchToFinancesIfAvailable();
        if (context.mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const TransactionEditorScreen()),
          );
        }
      } else if (action == 'view_trends' ||
          action == 'view_budgets' ||
          action == 'view_ledger') {
        switchToFinancesIfAvailable();
        FinancialManagerScreen.tabRedirectNotifier.value =
            action == 'view_budgets' ? 'Budgets' : 'Ledger';
      } else if (action == 'new_note') {
        final noteProvider = Provider.of<NoteProvider>(context, listen: false);
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                NoteEditorScreen(initialFolder: noteProvider.selectedFolder),
          ),
        );
      } else if (action == 'search') {
        HomeAppBar.searchRequestedNotifier.value = true;
      } else if (action == 'scan_receipt') {
        switchToFinancesIfAvailable();
        final res = await ReceiptScannerSheet.show(context);
        if (res != null && context.mounted) {
          final double? total = res['total'] as double?;
          final String? merchant = res['merchant'] as String?;
          await Navigator.push(
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
      } else if (action == 'sync_devices') {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const P2pSyncScreen()),
        );
      } else if (action == 'process_text') {
        final String? sharedText =
            await _widgetChannel.invokeMethod<String>('getPendingSharedText');
        if (sharedText != null && sharedText.trim().isNotEmpty && context.mounted) {
          final noteProvider = Provider.of<NoteProvider>(context, listen: false);
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NoteEditorScreen(
                initialSharedText: sharedText,
                initialFolder: noteProvider.selectedFolder,
              ),
            ),
          );
        }
      } else if (action.startsWith('quick_add_todo')) {
        final parts = action.split(':');
        final targetNoteId = parts.length > 1 ? parts[1] : 'ALL_NOTES';
        await QuickAddTodoSheet.show(context, targetNoteId);
      } else if (action.startsWith('open_note:')) {
        final parts = action.split(':');
        final noteId = parts.length > 1 ? parts[1] : '';
        final lineIndex = parts.length > 2 ? int.tryParse(parts[2]) : null;
        if (noteId.isNotEmpty) {
          final note = await NoteRepository.instance.readNote(noteId);
          if (note != null && context.mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NoteEditorScreen(
                  note: note,
                  targetLineIndex: lineIndex,
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting pending widget action: $e');
    }
  }
}

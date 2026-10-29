import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../../data/note_model.dart';
import '../../data/transaction_category.dart';
import '../../data/transaction_model.dart';
import '../../data/category_constants.dart';
import '../../features/finances/data/transaction_repository.dart';
import '../../features/finances/presentation/screens/financial_manager_screen.dart';
import '../../features/finances/presentation/screens/transaction_editor_screen.dart';
import '../../features/finances/presentation/widgets/receipt_scanner_sheet.dart';
import '../../features/finances/providers/financial_manager_provider.dart';
import '../../features/notes/data/note_repository.dart';
import '../../features/notes/presentation/screens/note_editor_screen.dart';
import '../../features/notes/providers/note_provider.dart';
import '../../screens/app_lock_screen.dart';
import '../../features/settings/providers/settings_provider.dart';
import '../../features/sync/presentation/screens/p2p_sync_screen.dart';
import '../../utils/rich_text_utils.dart';
import '../../utils/widget_helper.dart';
import '../../widgets/home/home_app_bar.dart';
import '../../widgets/home/quick_add_todo_sheet.dart';
import 'package:uuid/uuid.dart';

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

  /// Executes parameterized Android MCP / Assistant quick-capture intents in the background
  /// even when [AppLockScreen] is locked, so users can log expenses, todos, or notes hands-free
  /// without exposing existing private records on screen.
  /// Returns `true` if a background quick-capture intent was consumed and saved.
  static Future<bool> processBackgroundQuickCaptureIfAny(
    BuildContext context,
  ) async {
    if (!context.mounted) return false;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final finProvider =
        Provider.of<FinancialManagerProvider>(context, listen: false);
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.maybeOf(context);

    try {
      final String? action =
          await _widgetChannel.invokeMethod<String>('peekPendingAction');
      if (action == null) return false;

      final Map<Object?, Object?>? rawExtras = await _widgetChannel
          .invokeMethod<Map<Object?, Object?>>('getPendingIntentExtras');
      final extras = <String, String>{};
      rawExtras?.forEach((k, v) {
        if (k != null && v != null) {
          extras[k.toString()] = v.toString();
        }
      });

      if (extras.isEmpty) return false;

      if (action == 'add_transaction' && settings.showFinancialManager) {
        final amount = double.tryParse(extras['amount'] ?? '');
        if (amount != null && amount > 0) {
          // Consume the pending action
          await _widgetChannel.invokeMethod<String>('getPendingAction');
          final desc = (extras['description'] ?? '').trim().isNotEmpty
              ? extras['description']!.trim()
              : 'Quick Expense';
          final cat = (extras['category'] ?? '').trim().isNotEmpty
              ? extras['category']!.trim()
              : TransactionCategory.fromDescriptionCached(desc);
          final isExpense =
              (extras['is_expense'] ?? 'true').toLowerCase() != 'false';
          final account =
              (extras['account_type'] ?? '').toLowerCase() == 'savings'
                  ? AccountType.savings
                  : AccountType.daily;

          await TransactionRepository.instance.createTransaction(
            TransactionModel(
              amount: amount,
              description: desc,
              date: DateTime.now(),
              isExpense: isExpense,
              category: cat,
              account: account,
            ),
          );
          unawaited(finProvider.loadTransactions());
          FinancialManagerScreen.refreshNotifier.value++;
          messenger?.showSnackBar(
            SnackBar(content: Text('Quick-logged: $desc')),
          );
          return true;
        }
      } else if (action.startsWith('quick_add_todo')) {
        final todoText = (extras['todo_text'] ?? '').trim();
        if (todoText.isNotEmpty) {
          await _widgetChannel.invokeMethod<String>('getPendingAction');
          final parts = action.split(':');
          final targetNoteId = parts.length > 1 ? parts[1] : null;
          await WidgetHelper.quickAddTask(
            noteId: targetNoteId,
            taskText: todoText,
          );
          unawaited(noteProvider.refreshNotes());
          messenger?.showSnackBar(
            SnackBar(content: Text('Task added: $todoText')),
          );
          return true;
        }
      } else if (action == 'new_note') {
        final content = (extras['content'] ?? '').trim();
        if (content.isNotEmpty) {
          await _widgetChannel.invokeMethod<String>('getPendingAction');
          final title = (extras['title'] ?? '').trim().isNotEmpty
              ? extras['title']!.trim()
              : content.split(RegExp(r'\s+')).take(6).join(' ');
          final now = DateTime.now();
          final note = Note(
            id: const Uuid().v4(),
            title: title,
            content: RichTextUtils.deltaToJson(
              RichTextUtils.markdownToDelta(content),
            ),
            dateCreated: now,
            dateModified: now,
            category: (extras['folder'] ?? '').trim().isNotEmpty
                ? extras['folder']!.trim()
                : 'Notes',
          );
          await NoteRepository.instance.createNote(note);
          unawaited(noteProvider.refreshNotes());
          messenger?.showSnackBar(
            SnackBar(content: Text('Saved note: $title')),
          );
          return true;
        }
      }
    } catch (e) {
      debugPrint('Background quick-capture intent check failed: $e');
    }
    return false;
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

    // First check if a parameterized background quick-capture intent can be fulfilled directly
    if (await processBackgroundQuickCaptureIfAny(context)) {
      return;
    }

    try {
      final String? action =
          await _widgetChannel.invokeMethod<String>('getPendingAction');
      if (action == null || !context.mounted) return;

      final Map<Object?, Object?>? rawExtras = await _widgetChannel
          .invokeMethod<Map<Object?, Object?>>('getPendingIntentExtras');
      if (!context.mounted) return;
      final extras = <String, String>{};
      rawExtras?.forEach((k, v) {
        if (k != null && v != null) {
          extras[k.toString()] = v.toString();
        }
      });

      final settings = Provider.of<SettingsProvider>(context, listen: false);
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);

      void switchToFinancesIfAvailable() {
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
        if (!settings.showFinancialManager) return;
        switchToFinancesIfAvailable();
        if (context.mounted) {
          final prefillDesc = extras['description'];
          final prefillCategory = extras['category'];
          final initialTx = (prefillDesc != null && prefillDesc.isNotEmpty)
              ? TransactionModel(
                  amount: double.tryParse(extras['amount'] ?? '') ?? 0.0,
                  description: prefillDesc,
                  date: DateTime.now(),
                  isExpense:
                      (extras['is_expense'] ?? 'true').toLowerCase() != 'false',
                  category: prefillCategory ??
                      TransactionCategory.fromDescriptionCached(prefillDesc),
                )
              : null;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  TransactionEditorScreen(transaction: initialTx),
            ),
          );
        }
      } else if (action == 'view_trends' ||
          action == 'view_budgets' ||
          action == 'view_ledger') {
        if (!settings.showFinancialManager) return;
        switchToFinancesIfAvailable();
        FinancialManagerScreen.tabRedirectNotifier.value =
            action == 'view_budgets' ? 'Budgets' : 'Ledger';
      } else if (action == 'new_note') {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NoteEditorScreen(
              initialSharedText: extras['content'] ?? extras['title'],
              initialFolder: extras['folder'] ?? noteProvider.selectedFolder,
            ),
          ),
        );
      } else if (action == 'search') {
        HomeAppBar.searchRequestedNotifier.value = true;
        final searchQuery = extras['query'];
        if (searchQuery != null && searchQuery.isNotEmpty) {
          noteProvider.setSearchQuery(searchQuery);
        }
      } else if (action == 'scan_receipt') {
        if (!settings.showFinancialManager) return;
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
        final targetText = parts.length > 3 ? parts.sublist(3).join(':') : null;
        if (noteId.isNotEmpty) {
          final note = await NoteRepository.instance.readNote(noteId);
          if (note != null && context.mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NoteEditorScreen(
                  note: note,
                  targetLineIndex: lineIndex,
                  targetChecklistText: targetText,
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

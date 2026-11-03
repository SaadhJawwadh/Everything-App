import 'package:flutter/material.dart';
import '../../../../core/ui/app_dialog.dart';

/// Modal dialog allowing the user to select an existing note folder or create a new one.
class NoteFolderDialog {
  static Future<String?> show({
    required BuildContext context,
    required String currentFolder,
    required List<String> folders,
  }) async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Move to folder',
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    ListTile(
                      leading: const Icon(Icons.notes_outlined),
                      title: const Text('All Notes'),
                      selected: currentFolder == 'All Notes',
                      onTap: () => Navigator.pop(ctx, 'All Notes'),
                    ),
                    ...folders.map(
                      (f) => ListTile(
                        leading: const Icon(Icons.folder_outlined),
                        title: Text(f),
                        selected: currentFolder == f,
                        onTap: () => Navigator.pop(ctx, f),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'New folder name',
                  prefixIcon: Icon(Icons.create_new_folder_outlined),
                ),
                onSubmitted: (v) {
                  if (v.trim().isNotEmpty) Navigator.pop(ctx, v.trim());
                },
              ),
            ],
          ),
        ),
        cancelLabel: 'Cancel',
        confirmLabel: 'Create & Move',
        onCancel: () => Navigator.pop(ctx),
        onConfirm: () {
          final v = controller.text.trim();
          if (v.isNotEmpty) Navigator.pop(ctx, v);
        },
      ),
    );
  }
}

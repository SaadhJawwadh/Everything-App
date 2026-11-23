import 'package:flutter/material.dart';
import 'package:note_taking_app/core/theme/app_layout.dart';
import '../../core/ui/app_dialog.dart';

/// A Material 3 dialog for choosing dimensions (rows/columns) when inserting a table.
class EditorTableDialog extends StatefulWidget {
  final int initialRows;
  final int initialCols;

  const EditorTableDialog({
    super.key,
    this.initialRows = 3,
    this.initialCols = 3,
  });

  /// Static helper to display the dialog and return `({int rows, int cols})?`.
  static Future<({int rows, int cols})?> show(
    BuildContext context, {
    int initialRows = 3,
    int initialCols = 3,
  }) async {
    return AppDialog.show<({int rows, int cols})>(
      context: context,
      builder: (ctx) => EditorTableDialog(
        initialRows: initialRows,
        initialCols: initialCols,
      ),
    );
  }

  @override
  State<EditorTableDialog> createState() => _EditorTableDialogState();
}

class _EditorTableDialogState extends State<EditorTableDialog> {
  late int _rows;
  late int _cols;

  @override
  void initState() {
    super.initState();
    _rows = widget.initialRows;
    _cols = widget.initialCols;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.radiusXXL),
      ),
      title: Row(
        children: [
          Icon(Icons.table_chart_outlined, color: colorScheme.primary),
          const SizedBox(width: 12),
          Text('Insert Table', style: theme.textTheme.titleLarge),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose dimensions for your table:',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _DimensionCounter(
                label: 'Columns',
                value: _cols,
                onDecrement: _cols > 1 ? () => setState(() => _cols--) : null,
                onIncrement: _cols < 10 ? () => setState(() => _cols++) : null,
              ),
              const SizedBox(width: AppLayout.spaceM),
              _DimensionCounter(
                label: 'Rows',
                value: _rows,
                onDecrement: _rows > 1 ? () => setState(() => _rows--) : null,
                onIncrement: _rows < 20 ? () => setState(() => _rows++) : null,
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (rows: _rows, cols: _cols)),
          child: const Text('Insert'),
        ),
      ],
    );
  }
}

class _DimensionCounter extends StatelessWidget {
  final String label;
  final int value;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  const _DimensionCounter({
    required this.label,
    required this.value,
    this.onDecrement,
    this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              color: colorScheme.primary,
              onPressed: onDecrement,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$value',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              color: colorScheme.primary,
              onPressed: onIncrement,
            ),
          ],
        ),
      ],
    );
  }
}

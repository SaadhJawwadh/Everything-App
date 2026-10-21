import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../../../../core/theme/app_layout.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../utils/rich_text_utils.dart';

/// Custom embed builder rendering rounded, full-width responsive images
/// with full-screen zoom and long-press contextual actions.
class RoundedImageEmbedBuilder extends EmbedBuilder {
  const RoundedImageEmbedBuilder();

  @override
  String get key => BlockEmbed.imageType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final node = embedContext.node;
    final controller = embedContext.controller;

    final imageUrl = node.value.data;
    final isUrl = imageUrl.startsWith('http');
    final file = isUrl ? null : File(imageUrl);

    Widget imageWidget = isUrl
        ? Image.network(
            imageUrl,
            cacheWidth: 1080,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(
                child: Icon(Icons.broken_image_outlined, size: 36),
              ),
            ),
          )
        : Image.file(
            file!,
            cacheWidth: 1080,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(
                child: Icon(Icons.broken_image_outlined, size: 36),
              ),
            ),
          );

    return GestureDetector(
      onTap: () {
        // View Full Image
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _FullScreenImageViewer(
              imageProvider: isUrl
                  ? NetworkImage(imageUrl)
                  : FileImage(file!) as ImageProvider,
            ),
          ),
        );
      },
      onLongPress: () {
        if (!embedContext.readOnly) {
          AppHaptics.mediumImpact();
          if (context.mounted) {
            _showImageActions(context, controller, node, imageUrl, isUrl, file);
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        width: double.infinity, // Mobile friendly: use full width
        height: 200,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppLayout.radiusL),
          child: imageWidget,
        ),
      ),
    );
  }

  void _showImageActions(
      BuildContext context,
      QuillController controller,
      Embed node,
      String imageUrl,
      bool isUrl,
      File? file) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.fullscreen),
                title: const Text('View Full Image'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _FullScreenImageViewer(
                        imageProvider: isUrl
                            ? NetworkImage(imageUrl)
                            : FileImage(file!) as ImageProvider,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error),
                title: Text('Remove Image',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () {
                  final offset = node.documentOffset;
                  controller.replaceText(offset, 1, '', null);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  final ImageProvider imageProvider;
  const _FullScreenImageViewer({required this.imageProvider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: InteractiveViewer(
        child: Center(
          child: Image(image: imageProvider),
        ),
      ),
    );
  }
}

/// Notification dispatched when an embedded table cell gains or loses focus.
class TableCellFocusNotification extends Notification {
  final bool isFocused;
  const TableCellFocusNotification(this.isFocused);
}

/// Custom embed builder rendering an interactive, editable table in Quill.
class TableEmbedBuilder extends EmbedBuilder {
  const TableEmbedBuilder();

  @override
  String get key => TableBlockEmbed.tableType;

  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final node = embedContext.node;
    final controller = embedContext.controller;
    final readOnly = embedContext.readOnly;

    return TableWidget(
      node: node,
      rawData: node.value.data,
      controller: controller,
      readOnly: readOnly,
    );
  }
}

/// Interactive table widget inside the Quill editor allowing dynamic
/// cell editing, row/column addition, and debounced delta updates.
class TableWidget extends StatefulWidget {
  final Embed node;
  final String rawData;
  final QuillController controller;
  final bool readOnly;

  const TableWidget({
    super.key,
    required this.node,
    required this.rawData,
    required this.controller,
    required this.readOnly,
  });

  @override
  State<TableWidget> createState() => _TableWidgetState();
}

class _TableWidgetState extends State<TableWidget> {
  List<List<String>> _cells = [];
  List<List<TextEditingController>> _controllers = [];
  List<List<FocusNode>> _focusNodes = [];
  Timer? _debounce;

  static String _cleanText(String text) {
    return text
        .replaceAll('\uFFFC', '')
        .replaceAll('\uFFFD', '')
        .replaceAll('\uFEFF', '');
  }

  @override
  void initState() {
    super.initState();
    _parseData();
  }

  void _parseData() {
    try {
      final List<dynamic> outer = jsonDecode(widget.rawData);
      _cells = outer
          .map((r) => (r as List).map((c) => _cleanText(c.toString())).toList())
          .toList();
    } catch (e) {
      _cells = [
        ['Header 1', 'Header 2'],
        ['Cell 1', 'Cell 2']
      ];
    }
    _initControllers();
  }

  void _initControllers() {
    for (final row in _controllers) {
      for (final controller in row) {
        controller.dispose();
      }
    }
    for (final row in _focusNodes) {
      for (final node in row) {
        node.dispose();
      }
    }
    _controllers = _cells
        .map((row) => row
            .map((cellText) => TextEditingController(text: _cleanText(cellText)))
            .toList())
        .toList();
    _focusNodes = _cells
        .map((row) => row.map((_) {
              final node = FocusNode();
              node.addListener(() {
                if (!mounted) return;
                debugPrint("TABLE_CELL: node.hasFocus = ${node.hasFocus}");
                if (node.hasFocus) {
                  const TableCellFocusNotification(true).dispatch(context);
                } else {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    final anyFocused =
                        _focusNodes.any((r) => r.any((n) => n.hasFocus));
                    debugPrint("TABLE_CELL: anyFocused = $anyFocused");
                    if (!anyFocused) {
                      const TableCellFocusNotification(false)
                          .dispatch(context);
                    }
                  });
                }
              });
              return node;
            }).toList())
        .toList();
  }

  @override
  void didUpdateWidget(covariant TableWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawData != widget.rawData) {
      try {
        final List<dynamic> outer = jsonDecode(widget.rawData);
        final newCells = outer
            .map((r) => (r as List).map((c) => _cleanText(c.toString())).toList())
            .toList();
        if (!_areCellsEqual(_cells, newCells)) {
          _cells = newCells;
          _initControllers();
        }
      } catch (_) {}
    }
  }

  bool _areCellsEqual(List<List<String>> a, List<List<String>> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].length != b[i].length) return false;
      for (int j = 0; j < a[i].length; j++) {
        if (a[i][j] != b[i][j]) return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final row in _controllers) {
      for (final controller in row) {
        controller.dispose();
      }
    }
    for (final row in _focusNodes) {
      for (final node in row) {
        node.dispose();
      }
    }
    super.dispose();
  }

  void _onCellChanged(int rowIndex, int colIndex, String text) {
    final cleaned = _cleanText(text);
    if (cleaned != text) {
      final controller = _controllers[rowIndex][colIndex];
      final currentSelection = controller.selection;
      final newOffset =
          currentSelection.baseOffset.clamp(0, cleaned.length);
      controller.value = TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: newOffset),
      );
    }
    _cells[rowIndex][colIndex] = cleaned;
    _triggerSave();
  }

  void _triggerSave() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      final cleanCells = _cells
          .map((r) => r.map((c) => _cleanText(c)).toList())
          .toList();
      final jsonStr = jsonEncode(cleanCells);
      final offset = widget.node.offset;
      widget.controller.replaceText(
        offset,
        1,
        TableBlockEmbed(jsonStr),
        null,
      );
    });
  }

  void _addRow() {
    setState(() {
      final colCount = _cells[0].length;
      _cells.add(List.generate(colCount, (_) => 'Cell'));
      _initControllers();
    });
    _triggerSave();
  }

  void _removeRow() {
    if (_cells.length <= 1) return;
    setState(() {
      _cells.removeLast();
      _initControllers();
    });
    _triggerSave();
  }

  void _addColumn() {
    setState(() {
      for (int i = 0; i < _cells.length; i++) {
        _cells[i].add(i == 0 ? 'Header ${_cells[i].length + 1}' : 'Cell');
      }
      _initControllers();
    });
    _triggerSave();
  }

  void _removeColumn() {
    if (_cells[0].length <= 1) return;
    setState(() {
      for (int i = 0; i < _cells.length; i++) {
        _cells[i].removeLast();
      }
      _initControllers();
    });
    _triggerSave();
  }

  Widget _buildTableStructureActionIcon({
    required IconData structureIcon,
    required IconData actionIcon,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(structureIcon, size: 20),
        Positioned(
          right: -5,
          bottom: -5,
          child: Icon(actionIcon, size: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.5);

    return TapRegion(
      onTapOutside: (event) {
        debugPrint("TABLE_CELL: onTapOutside triggered");
        for (final row in _focusNodes) {
          for (final node in row) {
            if (node.hasFocus) {
              debugPrint("TABLE_CELL: unfocusing node");
              node.unfocus();
            }
          }
        }
      },
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppLayout.radiusM),
                border: Border.all(color: borderColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: Table(
                border: TableBorder.symmetric(
                  inside: BorderSide(color: borderColor),
                ),
                children: List.generate(_cells.length, (rIndex) {
                  final isHeader = rIndex == 0;
                  return TableRow(
                    decoration: BoxDecoration(
                      color: isHeader
                          ? theme.colorScheme.surfaceContainerHigh
                          : (rIndex % 2 == 1
                              ? theme.colorScheme.surface
                              : theme.colorScheme.surfaceContainerLowest),
                    ),
                    children: List.generate(_cells[rIndex].length, (cIndex) {
                      return TableCell(
                        verticalAlignment: TableCellVerticalAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          child: TextField(
                            controller: _controllers[rIndex][cIndex],
                            focusNode: _focusNodes[rIndex][cIndex],
                            readOnly: widget.readOnly,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 13,
                              fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              fillColor: Colors.transparent,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            ),
                            onChanged: (text) => _onCellChanged(rIndex, cIndex, text),
                          ),
                        ),
                      );
                    }),
                  );
                }),
              ),
            ),
            if (!widget.readOnly)
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppLayout.radiusL),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: _buildTableStructureActionIcon(
                              structureIcon: Icons.table_rows_outlined,
                              actionIcon: Icons.add_rounded,
                            ),
                            tooltip: 'Add Row',
                            onPressed: _cells.length < 20 ? _addRow : null,
                          ),
                          IconButton(
                            icon: _buildTableStructureActionIcon(
                              structureIcon: Icons.table_rows_outlined,
                              actionIcon: Icons.remove_rounded,
                            ),
                            tooltip: 'Remove Row',
                            onPressed: _cells.length > 1 ? _removeRow : null,
                          ),
                          const SizedBox(width: AppLayout.spaceS),
                          IconButton(
                            icon: _buildTableStructureActionIcon(
                              structureIcon: Icons.view_column_outlined,
                              actionIcon: Icons.add_rounded,
                            ),
                            tooltip: 'Add Column',
                            onPressed: _cells[0].length < 10 ? _addColumn : null,
                          ),
                          IconButton(
                            icon: _buildTableStructureActionIcon(
                              structureIcon: Icons.view_column_outlined,
                              actionIcon: Icons.remove_rounded,
                            ),
                            tooltip: 'Remove Column',
                            onPressed: _cells[0].length > 1 ? _removeColumn : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/theme/app_layout.dart';

typedef SlashCommandItem = ({String label, String command, IconData icon, String description});

/// Floating contextual slash command menu overlay for the rich-text note editor.
class NoteSlashCommandOverlay extends StatelessWidget {
  final String query;
  final bool isAiActive;
  final void Function(String command) onCommandSelected;
  final List<SlashCommandItem> commands;

  static const List<SlashCommandItem> defaultCommands = [
    (label: 'AI Assist', command: 'ai', icon: Icons.auto_awesome, description: 'Launch Gemini AI tools'),
    (label: 'Checklist', command: 'todo', icon: Icons.check_box_outlined, description: 'Interactive to-do checkbox'),
    (label: 'Table', command: 'table', icon: Icons.table_chart_outlined, description: 'Insert 3x3 data grid'),
    (label: 'Code Block', command: 'code', icon: Icons.code, description: 'Monospace code container'),
    (label: 'Heading 1', command: 'h1', icon: Icons.title, description: 'Large main heading'),
    (label: 'Heading 2', command: 'h2', icon: Icons.text_fields, description: 'Medium section heading'),
    (label: 'Quote', command: 'quote', icon: Icons.format_quote, description: 'Callout blockquote'),
    (label: 'Bullet List', command: 'bullet', icon: Icons.format_list_bulleted, description: 'Unordered bullet points'),
    (label: 'Numbered List', command: 'number', icon: Icons.format_list_numbered, description: 'Sequential numbered list'),
  ];

  const NoteSlashCommandOverlay({
    super.key,
    required this.query,
    required this.isAiActive,
    required this.onCommandSelected,
    this.commands = defaultCommands,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final filteredCommands = commands
        .where((cmd) => cmd.command != 'ai' || isAiActive)
        .where((cmd) =>
            cmd.command.startsWith(query) ||
            cmd.label.toLowerCase().contains(query))
        .toList();

    if (filteredCommands.isEmpty) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: AppLayout.animShort,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppLayout.radiusXL),
        boxShadow: AppLayout.softShadow(context),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                Icon(Icons.bolt, size: 16, color: colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Slash Commands',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  'Type to filter',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6.0),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: filteredCommands.length,
              itemBuilder: (context, index) {
                final cmd = filteredCommands[index];
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  leading: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(AppLayout.radiusS),
                    ),
                    child: Icon(cmd.icon, size: 18, color: colorScheme.primary),
                  ),
                  title: Row(
                    children: [
                      Text(
                        cmd.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(AppLayout.radiusS),
                        ),
                        child: Text(
                          '/${cmd.command}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontFamily: 'monospace',
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    cmd.description,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () => onCommandSelected(cmd.command),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/services/app_haptics.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/app_bottom_sheet.dart';
import '../../../../core/ui/app_card.dart';
import '../../../../core/ui/app_chip.dart';
import '../../../../core/ui/expressive_split_button.dart';
import '../../../../data/note_model.dart';
import 'package:note_taking_app/features/notes/providers/note_provider.dart';
import '../../../../screens/app_lock_screen.dart';
import '../../services/note_migration_service.dart';

class NoteMigrationSheet extends StatefulWidget {
  const NoteMigrationSheet({super.key});

  static Future<void> show(BuildContext context) async {
    await AppBottomSheet.show<void>(
      context: context,
      title: 'Import & Migrate Notes',
      child: const NoteMigrationSheet(),
    );
  }

  @override
  State<NoteMigrationSheet> createState() => _NoteMigrationSheetState();
}

class _NoteMigrationSheetState extends State<NoteMigrationSheet> {
  bool _isLoading = false;
  List<Note>? _parsedNotes;
  Set<String> _detectedTags = {};

  Future<void> _pickFiles() async {
    setState(() => _isLoading = true);
    try {
      final notes = await NoteMigrationService.pickAndParseNotes();
      if (!mounted) return;

      final tags = <String>{};
      for (final n in notes) {
        tags.addAll(n.tags);
      }

      setState(() {
        _parsedNotes = notes;
        _detectedTags = tags;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error parsing notes: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _launchGoogleTakeout() async {
    AppLockScreen.ignoreNextResumeLock();
    final uri = Uri.parse('https://takeout.google.com/settings/takeout/custom/keep');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open browser. Please visit takeout.google.com manually.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open browser. Please visit takeout.google.com manually.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _performImport() async {
    if (_parsedNotes == null || _parsedNotes!.isEmpty) return;
    setState(() => _isLoading = true);
    AppHaptics.mediumImpact();

    try {
      final result = await NoteMigrationService.batchInsertNotes(_parsedNotes!);
      if (!mounted) return;

      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      await noteProvider.refreshNotes();

      if (mounted) {
        Navigator.of(context).pop();
        final messenger = ScaffoldMessenger.of(context);
        final theme = Theme.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              result.skippedCount > 0
                  ? 'Imported ${result.totalImported} notes (${result.skippedCount} duplicates skipped).'
                  : 'Successfully imported ${result.totalImported} notes${result.importedTags.isNotEmpty ? ' with ${result.importedTags.length} tags' : ''}.',
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
            action: result.importedNoteIds.isNotEmpty
                ? SnackBarAction(
                    label: 'Undo',
                    textColor: theme.colorScheme.inversePrimary,
                    onPressed: () async {
                      AppHaptics.mediumImpact();
                      final count = await NoteMigrationService.undoImport(result.importedNoteIds);
                      await noteProvider.refreshNotes();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Reverted import ($count notes moved to trash).'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  )
                : null,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to import notes: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_parsedNotes == null) ...[
            AppCard(
              padding: const EdgeInsets.all(AppLayout.spaceL),
              backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.25),
              border: BorderSide(color: colorScheme.primary.withValues(alpha: 0.3)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.import_contacts_rounded, color: colorScheme.primary, size: 24),
                      const SizedBox(width: AppLayout.spaceS),
                      Text(
                        'Google Keep & Markdown',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontFamily: AppTheme.fontGoogleSansFlex,
                          fontFamilyFallback: AppTheme.fontFallbacks,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppLayout.spaceS),
                  Text(
                    'Import notes directly from Google Takeout (ZIP or JSON files) or generic Markdown/Text files (.md, .txt). Your titles, checklists, tags, and timestamps will be preserved.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const Divider(height: AppLayout.spaceXL),
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, size: 20, color: colorScheme.primary),
                      const SizedBox(width: AppLayout.spaceS),
                      Text(
                        'How to export from Google Keep',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontFamily: AppTheme.fontGoogleSansFlex,
                          fontFamilyFallback: AppTheme.fontFallbacks,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppLayout.spaceS),
                  Text(
                    '1. Use the menu below to open Google Takeout with Keep pre-selected.\n'
                    '2. Scroll down and tap "Next step" → "Create export".\n'
                    '3. Once downloaded, return here and select the ZIP file.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13.0,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppLayout.spaceL),
            ExpressiveSplitButton<String>(
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.folder_open_rounded),
              label: _isLoading ? 'Scanning Files...' : 'Select Takeout ZIP or Notes',
              onPrimaryPressed: _isLoading ? () {} : _pickFiles,
              menuItems: const [
                PopupMenuItem(
                  value: 'takeout',
                  child: Row(
                    children: [
                      Icon(Icons.open_in_browser_rounded, size: 20),
                      SizedBox(width: 10),
                      Text('Open Google Takeout'),
                    ],
                  ),
                ),
              ],
              onSelected: (val) {
                if (val == 'takeout') {
                  _launchGoogleTakeout();
                }
              },
            ),
          ] else ...[
            // Preview parsed notes
            AppCard(
              padding: const EdgeInsets.all(AppLayout.spaceM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ready to Import',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontFamily: AppTheme.fontGoogleSansFlex,
                          fontFamilyFallback: AppTheme.fontFallbacks,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_parsedNotes!.length} Notes Found',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontFamily: AppTheme.fontGoogleSansFlex,
                          fontFamilyFallback: AppTheme.fontFallbacks,
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  if (_detectedTags.isNotEmpty) ...[
                    const SizedBox(height: AppLayout.spaceS),
                    Text(
                      'Detected Tags (${_detectedTags.length}):',
                      style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppLayout.spaceXS),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 110),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: AppLayout.spaceXS,
                          runSpacing: AppLayout.spaceXS,
                          children: _detectedTags.map((tag) {
                            return AppChip(label: '#$tag');
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppLayout.spaceM),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _parsedNotes!.length.clamp(0, 5),
                      itemBuilder: (context, index) {
                        final note = _parsedNotes![index];
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.description_outlined, size: 20),
                          title: Text(
                            note.title.isNotEmpty ? note.title : 'Untitled',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            note.tags.isNotEmpty ? note.tags.join(', ') : 'No tags',
                            style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_parsedNotes!.length > 5) ...[
                    Text(
                      'And ${_parsedNotes!.length - 5} more notes...',
                      style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppLayout.spaceL),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : () => setState(() => _parsedNotes = null),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Change Files'),
                  ),
                ),
                const SizedBox(width: AppLayout.spaceM),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isLoading || _parsedNotes!.isEmpty ? null : _performImport,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.download_done_rounded),
                    label: Text(_isLoading ? 'Importing...' : 'Import Notes'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppLayout.spaceS),
        ],
      ),
    );
  }
}

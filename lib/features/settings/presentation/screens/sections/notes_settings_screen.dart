import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/theme/app_layout.dart';
import '../../../../../core/ui/expressive_sliver_app_bar.dart';
import '../../../../../utils/app_route.dart';
import '../../../../../widgets/settings_widgets.dart';
import '../../../../notes/presentation/screens/manage_tags_screen.dart';
import '../../../../notes/presentation/widgets/note_migration_sheet.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../providers/settings_provider.dart';
import '../settings_dialogs.dart';

class NotesSettingsScreen extends StatelessWidget {
  const NotesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              ExpressiveSliverAppBar(
                titleText: l10n?.notesAndEditorWorkspace ?? 'Notes & Editor',
                showBackButton: true,
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppLayout.spaceXL,
                  vertical: AppLayout.spaceL,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    SettingsSection(
                      title: 'Organization & Tags',
                      icon: Icons.label_outline,
                      accentColor: const Color(0xFFF59E0B),
                      children: [
                        SettingsTile(
                          icon: Icons.label_outline,
                          iconColor: const Color(0xFFF59E0B),
                          title: l10n?.manageTags ?? 'Manage Tags',
                          subtitle: 'Rename or delete note tags',
                          showArrow: true,
                          onTap: () => AppRoute.push(context, const ManageTagsScreen()),
                        ),
                        SettingsSwitchTile(
                          icon: Icons.tag_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          title: 'Tag Filter Bar',
                          subtitle: 'Show quick tag filter pills at the top of the notes list',
                          value: settings.showTagFilterBar,
                          onChanged: settings.setShowTagFilterBar,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppLayout.spaceL),
                    SettingsSection(
                      title: 'Writing & Editor Tools',
                      icon: Icons.edit_note_rounded,
                      accentColor: colorScheme.secondary,
                      children: [
                        SettingsSwitchTile(
                          icon: Icons.border_color_outlined,
                          iconColor: colorScheme.secondary,
                          title: 'Minimal Editor Mode',
                          subtitle: 'Streamlined writing toolbar; secondary tools moved to menu',
                          value: settings.minimalEditorMode,
                          onChanged: settings.setMinimalEditorMode,
                        ),
                        SettingsSwitchTile(
                          icon: Icons.checklist_rtl_rounded,
                          iconColor: colorScheme.secondary,
                          title: 'Collapse Completed Checklists',
                          subtitle: 'Move finished to-do items to a bottom section',
                          value: settings.moveCompletedChecklistsToBottom,
                          onChanged: settings.setMoveCompletedChecklistsToBottom,
                        ),
                        SettingsSwitchTile(
                          icon: Icons.celebration_outlined,
                          iconColor: const Color(0xFFF59E0B),
                          title: 'Milestone Celebrations',
                          subtitle: 'Calm celebrations when reaching savings goals and settling debts',
                          value: settings.showMilestoneDelight,
                          onChanged: settings.setShowMilestoneDelight,
                        ),
                        SettingsSwitchTile(
                          icon: Icons.calendar_view_week_rounded,
                          iconColor: colorScheme.primary,
                          title: 'Days of Clarity Strip',
                          subtitle: 'Visualize 14-day mindfulness activity without stressful streak countdowns',
                          value: settings.showClarityMosaic,
                          onChanged: settings.setShowClarityMosaic,
                        ),
                        if (settings.isDeviceAiSupported)
                          SettingsSwitchTile(
                            icon: Icons.auto_awesome_outlined,
                            iconColor: colorScheme.primary,
                            title: 'Gemini Nano AI',
                            subtitle: 'Enable offline summaries, tag suggestions & smart SMS parsing',
                            value: settings.useOnDeviceAi,
                            onChanged: settings.setUseOnDeviceAi,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppLayout.spaceL),
                    SettingsSection(
                      title: 'Maintenance & Import',
                      icon: Icons.auto_delete_outlined,
                      accentColor: colorScheme.tertiary,
                      children: [
                        SettingsTile(
                          icon: Icons.auto_delete_outlined,
                          iconColor: colorScheme.tertiary,
                          title: 'Trash Auto-Purge',
                          subtitle: 'Automatic deletion schedule for trash',
                          valueBadge: settings.trashAutoPurgeDays <= 0
                              ? 'Disabled'
                              : '${settings.trashAutoPurgeDays} Days',
                          showArrow: true,
                          onTap: () => SettingsDialogs.showTrashPurgeDialog(context, settings),
                        ),
                        SettingsTile(
                          icon: Icons.import_contacts_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          title: 'Import & Migrate Notes',
                          subtitle: 'Import from Google Keep Takeout, Markdown, or text files',
                          showArrow: true,
                          onTap: () => NoteMigrationSheet.show(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppLayout.fabBottomPadding),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

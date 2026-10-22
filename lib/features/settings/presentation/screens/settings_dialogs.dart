import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_bottom_sheet.dart';
import '../../../../core/ui/app_card.dart';
import '../../../../core/ui/app_dialog.dart';
import '../../../../data/database_helper.dart';
import '../../../../data/transaction_category.dart';
import 'package:note_taking_app/features/notes/providers/note_provider.dart';
import '../../../../screens/app_lock_screen.dart';
import '../../../../services/backup_service.dart';
import '../../../finances/providers/financial_manager_provider.dart';
import '../../../finances/providers/savings_goal_provider.dart';
import '../../../../utils/widget_helper.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/settings_provider.dart';

/// Centralized modal sheets and picker dialogs for Settings.
class SettingsDialogs {
  SettingsDialogs._();

  static void showTrashPurgeDialog(BuildContext context, SettingsProvider settings) {
    final options = [
      (label: '7 Days', days: 7, desc: 'Auto-delete items 7 days old'),
      (label: '14 Days', days: 14, desc: 'Auto-delete items 14 days old'),
      (label: '30 Days (Default)', days: 30, desc: 'Auto-delete items 30 days old'),
      (label: 'Disabled', days: 0, desc: 'Never auto-delete deleted notes'),
    ];

    AppBottomSheet.show(
      context: context,
      title: 'Trash Auto-Purge Duration',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final isSelected = settings.trashAutoPurgeDays == opt.days;
          final colorScheme = Theme.of(context).colorScheme;

          return Material(
            color: Colors.transparent,
            child: ListTile(
              leading: Icon(
                Icons.auto_delete_outlined,
                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
              title: Text(
                opt.label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                ),
              ),
              subtitle: Text(
                opt.desc,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: isSelected
                  ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
                  : null,
              onTap: () {
                AppHaptics.selectionClick();
                settings.setTrashAutoPurgeDays(opt.days);
                Navigator.pop(context);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  static void showThemePicker(BuildContext context, SettingsProvider settings) {
    final options = [
      (label: 'System Default', mode: ThemeMode.system, icon: Icons.brightness_auto_rounded, desc: 'Follow device dark mode settings'),
      (label: 'Light Theme', mode: ThemeMode.light, icon: Icons.light_mode_rounded, desc: 'Clean high-contrast light mode'),
      (label: 'Dark Theme', mode: ThemeMode.dark, icon: Icons.dark_mode_rounded, desc: 'Sleek dark mode surface theme'),
    ];

    AppBottomSheet.show(
      context: context,
      title: 'Choose Theme',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final isSelected = settings.themeMode == opt.mode;
          final colorScheme = Theme.of(context).colorScheme;

          return ListTile(
            leading: Icon(
              opt.icon,
              color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            title: Text(
              opt.label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              opt.desc,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: isSelected
                ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
                : null,
            onTap: () {
              AppHaptics.selectionClick();
              settings.setThemeMode(opt.mode);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  static void showLanguagePicker(BuildContext context, SettingsProvider settings) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final languages = [
      {
        'code': 'system',
        'name': l10n?.languageSystem ?? 'System Default',
        'native': 'Follow Device Language',
        'icon': Icons.brightness_auto_rounded,
      },
      {
        'code': 'en',
        'name': 'English',
        'native': 'English (United States)',
        'icon': Icons.language_rounded,
      },
      {
        'code': 'zh',
        'name': '中文',
        'native': 'Chinese (Simplified)',
        'icon': Icons.translate_rounded,
      },
      {
        'code': 'pt',
        'name': 'Português',
        'native': 'Portuguese (Portugal / Brazil)',
        'icon': Icons.public_rounded,
      },
      {
        'code': 'es',
        'name': 'Español',
        'native': 'Spanish (Latin America / Spain)',
        'icon': Icons.travel_explore_rounded,
      },
      {
        'code': 'fr',
        'name': 'Français',
        'native': 'French (France / Canada)',
        'icon': Icons.language_rounded,
      },
      {
        'code': 'de',
        'name': 'Deutsch',
        'native': 'German (Germany / Austria)',
        'icon': Icons.translate_rounded,
      },
      {
        'code': 'ta',
        'name': 'தமிழ்',
        'native': 'Tamil (Sri Lanka / India)',
        'icon': Icons.translate_rounded,
      },
      {
        'code': 'ru',
        'name': 'Русский',
        'native': 'Russian (Россия / СНГ)',
        'icon': Icons.language_rounded,
      },
    ];

    AppBottomSheet.show(
      context: context,
      title: l10n?.appLanguage ?? 'App Language',
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.65,
        ),
        child: ListView(
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.zero,
          children: languages.map((lang) {
            final isSelected = settings.selectedLanguageCode == lang['code'];

            return Material(
              color: Colors.transparent,
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary.withValues(alpha: 0.15)
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppLayout.radiusM),
                  ),
                  child: Icon(
                    lang['icon'] as IconData,
                    size: 20,
                    color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                  ),
                ),
                title: Text(
                  lang['name'] as String,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  lang['native'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
                    : null,
                onTap: () {
                  AppHaptics.selectionClick();
                  settings.setSelectedLanguage(lang['code'] as String);
                  Navigator.pop(context);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  static void showCurrencyPicker(BuildContext context, SettingsProvider settings) {
    final l10n = AppLocalizations.of(context);
    final currencies = [
      {'code': 'LKR', 'symbol': 'Rs.', 'name': 'Sri Lankan Rupee'},
      {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee'},
      {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
      {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
      {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
      {'code': 'AED', 'symbol': 'د.إ', 'name': 'UAE Dirham'},
      {'code': 'SAR', 'symbol': '﷼', 'name': 'Saudi Riyal'},
      {'code': 'CAD', 'symbol': 'C\$', 'name': 'Canadian Dollar'},
      {'code': 'AUD', 'symbol': 'A\$', 'name': 'Australian Dollar'},
      {'code': 'SGD', 'symbol': 'S\$', 'name': 'Singapore Dollar'},
      {'code': 'MYR', 'symbol': 'RM', 'name': 'Malaysian Ringgit'},
      {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen'},
      {'code': 'NZD', 'symbol': 'NZ\$', 'name': 'New Zealand Dollar'},
      {'code': 'CHF', 'symbol': 'CHF', 'name': 'Swiss Franc'},
      {'code': 'RUB', 'symbol': '₽', 'name': 'Russian Ruble'},
    ];

    AppBottomSheet.show(
      context: context,
      title: l10n?.selectCurrency ?? 'Select Currency',
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.65,
        ),
        child: ListView(
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.zero,
          children: currencies.map((c) {
            final isSelected = settings.currency == c['symbol'];
            final colorScheme = Theme.of(context).colorScheme;

            return Material(
              color: Colors.transparent,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isSelected
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  child: Text(
                    c['symbol']!,
                    style: TextStyle(
                      color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text('${c['code']} - ${c['name']}'),
                trailing: isSelected
                    ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
                    : null,
                onTap: () {
                  AppHaptics.selectionClick();
                  settings.setCurrency(c['symbol']!);
                  Navigator.pop(context);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  static void showDefaultPaymentInfoDialog(BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController(text: settings.defaultPaymentInfo);

    showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Default Payment Details',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your bank account number, UPI ID, or mobile pay info. This will be automatically included in WhatsApp reminders to friends.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. Bank: Commercial Bank\nAcc: 1234567890\nName: John Doe',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        confirmLabel: 'Save',
        onConfirm: () {
          settings.setDefaultPaymentInfo(controller.text.trim());
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  static void showNotificationTextDialog(BuildContext context, SettingsProvider settings) {
    final controller = TextEditingController(text: settings.discreetNotificationText);

    showDialog(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Discreet Notification Text',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Custom text shown on your lock screen when period alerts arrive. Keep it subtle for maximum privacy.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'e.g. Personal Reminder, Self-care note',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        confirmLabel: 'Save',
        onConfirm: () {
          final val = controller.text.trim();
          if (val.isNotEmpty) {
            settings.setDiscreetNotificationText(val);
          }
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  static void showTimeoutPicker(BuildContext context, SettingsProvider settings) {
    final timeouts = [
      (label: 'Immediately', seconds: 0),
      (label: '30 Seconds', seconds: 30),
      (label: '1 Minute', seconds: 60),
      (label: '5 Minutes', seconds: 300),
      (label: '15 Minutes', seconds: 900),
    ];

    AppBottomSheet.show(
      context: context,
      title: 'Auto-Lock Timeout',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: timeouts.map((t) {
          final isSelected = settings.appLockTimeout == t.seconds;
          final colorScheme = Theme.of(context).colorScheme;

          return ListTile(
            title: Text(t.label),
            trailing: isSelected
                ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
                : null,
            onTap: () {
              AppHaptics.selectionClick();
              settings.setAppLockTimeout(t.seconds);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  static void showFrequencyPicker(BuildContext context, SettingsProvider settings) {
    final frequencies = [
      (label: 'Daily', value: 'daily'),
      (label: 'Weekly', value: 'weekly'),
    ];

    AppBottomSheet.show(
      context: context,
      title: 'Backup Frequency',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: frequencies.map((f) {
          final isSelected = settings.autoBackupFrequency == f.value;
          final colorScheme = Theme.of(context).colorScheme;

          return ListTile(
            title: Text(f.label),
            trailing: isSelected
                ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
                : null,
            onTap: () {
              AppHaptics.selectionClick();
              settings.setAutoBackupFrequency(f.value);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  static Future<void> showBackupLocationPicker(BuildContext context, SettingsProvider settings) async {
    try {
      AppLockScreen.ignoreNextResumeLock();
      final selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null && selectedDirectory.isNotEmpty) {
        final targetDir = Directory(selectedDirectory);
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }

        // Issue #5: Initialize a clean backup immediately into the target directory.
        // This guarantees write permissions and ensures an empty directory immediately contains
        // a valid backup file.
        final jsonContent = await generateBackupJson(
          settingsOverride: settings.toBackupMap(),
        );
        final dateStr = DateTime.now().toString().replaceAll(RegExp(r'[: ]'), '_').split('.')[0];
        final fileName = 'notebook_auto_backup_$dateStr.json';
        final initialFile = File('${targetDir.path}/$fileName');
        await initialFile.writeAsString(jsonContent);

        AppHaptics.mediumImpact();
        await settings.setAutoBackupPath(selectedDirectory);
        settings.updateLastAutoBackupTime(DateTime.now());

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Backup folder set & initialized: $selectedDirectory'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Custom backup directory setup failed ($e), falling back to app storage');
      await settings.setAutoBackupPath(null); // Resilient fallback to protected app storage
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not write to folder ($e). Using secure app storage.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  static void showDatabaseSnapshotsSheet(BuildContext context) {
    AppBottomSheet.show(
      context: context,
      title: 'Database Snapshots & Local Recovery',
      child: StatefulBuilder(
        builder: (ctx, setSheetState) {
          final theme = Theme.of(ctx);
          final colorScheme = theme.colorScheme;

          return FutureBuilder<List<DatabaseSnapshotInfo>>(
            future: DatabaseHelper.instance.getAvailableSnapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppLayout.spaceXL),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final snapshots = snapshot.data ?? [];

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Rolling Snapshots (${snapshots.length})',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                        label: const Text('Snapshot Now'),
                        onPressed: () async {
                          AppHaptics.selectionClick();
                          final created = await DatabaseHelper.instance.createManualSnapshot();
                          if (created != null && ctx.mounted) {
                            setSheetState(() {});
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Manual database snapshot created'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppLayout.spaceM),
                  if (snapshots.isEmpty)
                    AppCard(
                      child: Padding(
                        padding: const EdgeInsets.all(AppLayout.spaceL),
                        child: Column(
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 40,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(height: AppLayout.spaceM),
                            Text(
                              'No Snapshots Found',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppLayout.spaceS),
                            Text(
                              'Snapshots are created automatically before database schema updates and P2P sync merges. You can also create manual snapshots above.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...snapshots.map((snap) {
                      IconData snapIcon;
                      Color snapColor;
                      String typeTitle;

                      switch (snap.type) {
                        case 'pre-migration':
                          snapIcon = Icons.published_with_changes_rounded;
                          snapColor = colorScheme.primary;
                          typeTitle = 'Pre-Migration Snapshot';
                          break;
                        case 'pre-sync':
                          snapIcon = Icons.sync_rounded;
                          snapColor = colorScheme.secondary;
                          typeTitle = 'Pre-Sync Snapshot';
                          break;
                        default:
                          snapIcon = Icons.bookmark_added_rounded;
                          snapColor = colorScheme.tertiary;
                          typeTitle = 'Manual Snapshot';
                          break;
                      }

                      final formattedTime = DateFormat('MMM d, y • h:mm a').format(snap.timestamp);
                      final sizeKb = (snap.sizeBytes / 1024).toStringAsFixed(1);

                      return AppCard(
                        margin: const EdgeInsets.only(bottom: AppLayout.spaceS),
                        child: Padding(
                          padding: const EdgeInsets.all(AppLayout.spaceM),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: snapColor.withValues(alpha: 0.15),
                                foregroundColor: snapColor,
                                child: Icon(snapIcon, size: 20),
                              ),
                              const SizedBox(width: AppLayout.spaceM),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      typeTitle,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$formattedTime • $sizeKb KB',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              OutlinedButton(
                                onPressed: () async {
                                  AppHaptics.selectionClick();
                                  final confirmed = await showDialog<bool>(
                                    context: ctx,
                                    builder: (dialogCtx) => AppDialog(
                                      title: 'Restore Snapshot?',
                                      content: Text(
                                        'Restore data from $formattedTime? A safety backup of your active database will be saved first.',
                                      ),
                                      confirmLabel: 'Restore',
                                      onConfirm: () => Navigator.of(dialogCtx).pop(true),
                                    ),
                                  );

                                  if (confirmed == true && ctx.mounted) {
                                    final noteProv = Provider.of<NoteProvider>(ctx, listen: false);
                                    final finProv = Provider.of<FinancialManagerProvider>(ctx, listen: false);
                                    final goalsProv = Provider.of<SavingsGoalProvider>(ctx, listen: false);
                                    final navigator = Navigator.of(ctx);
                                    final messenger = ScaffoldMessenger.of(ctx);

                                    final restored = await DatabaseHelper.instance.restoreSnapshot(snap.path);
                                    if (restored) {
                                      try {
                                        await noteProv.refreshNotes();
                                        await finProv.refresh();
                                        await goalsProv.loadGoals();
                                      } catch (_) {}
                                      navigator.pop();
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Database successfully restored from snapshot'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    } else {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: const Text('Failed to restore snapshot. Current database preserved.'),
                                          backgroundColor: colorScheme.error,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                child: const Text('Restore'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: AppLayout.spaceM),
                ],
              );
            },
          );
        },
      ),
    );
  }

  static void showAccountNamingAndRoutingSheet(BuildContext context, SettingsProvider settings) {
    final acc1Controller = TextEditingController(text: settings.account1Name);
    final acc2Controller = TextEditingController(text: settings.account2Name);
    final routingMap = Map<String, String>.from(settings.categoryAccountRouting);

    void saveAndClose(BuildContext ctx) async {
      AppHaptics.mediumImpact();
      await settings.setAccount1Name(acc1Controller.text.trim());
      await settings.setAccount2Name(acc2Controller.text.trim());
      for (final cat in TransactionCategory.allNames) {
        await settings.setCategoryAccountRouting(cat, routingMap[cat]);
      }
      if (context.mounted) {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account settings and category routing saved.')),
        );
      }
    }

    AppBottomSheet.show(
      context: context,
      title: 'Account Names & Routing',
      actions: [
        FilledButton.tonal(
          onPressed: () => saveAndClose(context),
          child: const Text('Save'),
        ),
      ],
      child: StatefulBuilder(
        builder: (ctx, setModalState) {
          final cs = Theme.of(ctx).colorScheme;
          final tt = Theme.of(ctx).textTheme;

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Customize presentation names for your dual accounts and assign default target accounts for categories.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppLayout.spaceL),

                // Account 1 Name
                Text('Account 1 (Daily Operating)', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: acc1Controller,
                  onChanged: (_) => setModalState(() {}),
                  decoration: InputDecoration(
                    hintText: 'e.g. Daily, Commercial Bank, Cash Wallet',
                    prefixIcon: const Icon(Icons.credit_card_outlined),
                    filled: true,
                    fillColor: cs.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppLayout.radiusM),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppLayout.spaceM),

                // Account 2 Name
                Text('Account 2 (Savings Vault)', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: acc2Controller,
                  onChanged: (_) => setModalState(() {}),
                  decoration: InputDecoration(
                    hintText: 'e.g. Savings, HNB Vault, Emergency Fund',
                    prefixIcon: const Icon(Icons.account_balance_outlined),
                    filled: true,
                    fillColor: cs.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppLayout.radiusM),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppLayout.spaceL),

                // Category Default Routing
                Text('Category Default Routing', style: tt.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Transactions with these categories will default to the selected account.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppLayout.spaceS),
                ...TransactionCategory.allNames.map((cat) {
                  final currentAccount = routingMap[cat];
                  final catIcon = TransactionCategory.iconFor(cat);
                  final catColor = TransactionCategory.colorFor(cat);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(catIcon, size: 18, color: catColor),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(cat, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                        ),
                        SegmentedButton<String?>(
                          showSelectedIcon: false,
                          style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          segments: [
                            const ButtonSegment<String?>(
                              value: null,
                              label: Text('Auto'),
                            ),
                            ButtonSegment<String?>(
                              value: 'daily',
                              label: Text(acc1Controller.text.trim().isNotEmpty ? acc1Controller.text.trim() : 'Daily'),
                            ),
                            ButtonSegment<String?>(
                              value: 'savings',
                              label: Text(acc2Controller.text.trim().isNotEmpty ? acc2Controller.text.trim() : 'Savings'),
                            ),
                          ],
                          selected: {currentAccount},
                          onSelectionChanged: (selected) {
                            AppHaptics.selectionClick();
                            setModalState(() {
                              final sel = selected.first;
                              if (sel == null) {
                                routingMap.remove(cat);
                              } else {
                                routingMap[cat] = sel;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: AppLayout.spaceXL),

                FilledButton(
                  onPressed: () => saveAndClose(ctx),
                  child: const Text('Save Settings'),
                ),
                const SizedBox(height: AppLayout.spaceM),
              ],
            ),
          );
        },
      ),
    );
  }

  static String getThemeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System Default';
    }
  }

  static String getLanguageDisplayName(String code) {
    switch (code) {
      case 'ru':
        return 'Русский (Russian)';
      case 'ta':
        return 'தமிழ் (Tamil)';
      case 'zh':
        return '中文 (Chinese)';
      case 'pt':
        return 'Português (Portuguese)';
      case 'es':
        return 'Español (Spanish)';
      case 'fr':
        return 'Français (French)';
      case 'de':
        return 'Deutsch (German)';
      case 'en':
        return 'English';
      case 'system':
      default:
        return 'System Default';
    }
  }

  static String getLanguageBadge(String code) {
    switch (code) {
      case 'ru':
        return 'RU';
      case 'ta':
        return 'தமிழ்';
      case 'zh':
        return '中文';
      case 'pt':
        return 'PT';
      case 'es':
        return 'ES';
      case 'fr':
        return 'FR';
      case 'de':
        return 'DE';
      case 'en':
        return 'EN';
      case 'system':
      default:
        return 'Auto';
    }
  }

  static String getTimeoutLabel(int seconds) {
    if (seconds == 0) return 'Immediately';
    if (seconds < 60) return '$seconds Seconds';
    return '${seconds ~/ 60} Minute${seconds >= 120 ? 's' : ''}';
  }

  static String getFrequencyLabel(String freq) {
    return freq == 'weekly' ? 'Weekly' : 'Daily';
  }

  static String formatLastBackupTime(dynamic time) {
    final dt = time is DateTime ? time : (time is String ? DateTime.tryParse(time) : null);
    if (dt == null) return time?.toString() ?? '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  static Future<void> launchExternalUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static void showPinWidgetSheet(BuildContext context, [String? initialWidgetType]) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final widgets = [
      (
        type: 'todo',
        name: 'Action Items & Checklist',
        desc: 'Interactive checklist with 1-tap toggling, list selector, and quick task capture.',
        icon: Icons.checklist_rtl_rounded,
        color: colorScheme.primary,
        gridSize: '2x2 • 4x2 • 4x4',
      ),
      (
        type: 'finance',
        name: 'Financial Manager',
        desc: 'Real-time daily/monthly cash flow, budget pacing indicator, and mini sparkline plot.',
        icon: Icons.account_balance_wallet_outlined,
        color: colorScheme.secondary,
        gridSize: '2x2 • 4x2',
      ),
      (
        type: 'unified',
        name: 'Unified Dual-Domain Capsule',
        desc: 'Dual-domain balance metrics paired with pending note checklist items.',
        icon: Icons.dashboard_customize_outlined,
        color: colorScheme.tertiary,
        gridSize: '4x2 • 4x4',
      ),
    ];

    AppBottomSheet.show(
      context: context,
      title: 'Pin to Home Screen',
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add tactile Material You widgets directly to your device home screen with 1-tap launcher pinning.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppLayout.spaceM),
            ...widgets.map((w) {
              final isHighlight = initialWidgetType == w.type;
              return AppCard(
                margin: const EdgeInsets.only(bottom: AppLayout.spaceS),
                backgroundColor: isHighlight ? w.color.withValues(alpha: 0.08) : null,
                child: Padding(
                  padding: const EdgeInsets.all(AppLayout.spaceM),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: w.color.withValues(alpha: 0.15),
                        foregroundColor: w.color,
                        child: Icon(w.icon, size: 22),
                      ),
                      const SizedBox(width: AppLayout.spaceM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    w.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(AppLayout.radiusS),
                                  ),
                                  child: Text(
                                    w.gridSize,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              w.desc,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppLayout.spaceS),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        onPressed: () async {
                          AppHaptics.mediumImpact();
                          final pinned = await WidgetHelper.requestPinWidget(w.type);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  pinned
                                      ? 'Pin request sent to your launcher'
                                      : 'Launcher pinning not supported. Add from your home screen widget menu.',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: const Text('Pin'),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: AppLayout.spaceM),
          ],
        ),
      ),
    );
  }
}

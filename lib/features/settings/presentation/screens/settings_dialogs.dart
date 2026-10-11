import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/app_haptics.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/ui/app_bottom_sheet.dart';
import '../../../../core/ui/app_dialog.dart';
import '../../../../data/transaction_category.dart';
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
    final languages = [
      {
        'code': 'system',
        'name': 'System Default',
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
    ];

    AppBottomSheet.show(
      context: context,
      title: 'App Language',
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
    );
  }

  static void showCurrencyPicker(BuildContext context, SettingsProvider settings) {
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
    ];

    AppBottomSheet.show(
      context: context,
      title: 'Select Currency',
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
      final selectedDirectory = await FilePicker.platform.getDirectoryPath();
      if (selectedDirectory != null) {
        AppHaptics.mediumImpact();
        await settings.setAutoBackupPath(selectedDirectory);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Backup location updated to: $selectedDirectory'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select directory: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
}

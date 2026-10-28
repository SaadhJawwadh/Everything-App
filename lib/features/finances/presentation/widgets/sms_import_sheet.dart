import 'package:flutter/material.dart';
import 'package:note_taking_app/services/sms_service.dart';
import 'package:note_taking_app/screens/app_lock_screen.dart';
import 'package:note_taking_app/core/theme/app_layout.dart';
import 'package:note_taking_app/core/ui/app_bottom_sheet.dart';
import 'package:note_taking_app/core/ui/app_dialog.dart';

class SmsImportSheet extends StatefulWidget {
  const SmsImportSheet({super.key});

  static Future<void> show(BuildContext context) {
    return AppBottomSheet.show(
      context: context,
      title: 'Advanced SMS Import Options',
      child: const SmsImportSheet(),
    );
  }

  @override
  State<SmsImportSheet> createState() => _SmsImportSheetState();
}

class _SmsImportSheetState extends State<SmsImportSheet> {
  static const _periods = [
    ('Last 24 hours (Default)', 1),
    ('Last 7 days', 7),
    ('Last 30 days', 30),
    ('Last 90 days', 90),
    ('All time', null),
  ];

  int _selectedIndex = 0;
  bool _bypassTombstones = false;

  Future<void> _runImport() async {
    final granted = await SmsService.hasPermission();
    if (!mounted) return;

    if (!granted) {
      final proceed = await AppDialog.showConfirm(
        context: context,
        title: 'SMS Access',
        message:
            'This app needs permission to read your SMS messages so it can detect and import bank transactions.\n\nOnly messages from recognised bank senders are processed. No messages are sent off-device or shared.',
        cancelLabel: 'Not now',
        confirmLabel: 'Allow',
      );
      if (proceed != true) return;

      AppLockScreen.ignoreNextResumeLock();
      final ok = await SmsService.requestPermissions();
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS permission is required to import transactions.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    final offsetDays = _periods[_selectedIndex].$2;
    final from = offsetDays != null
        ? DateTime.now().subtract(Duration(days: offsetDays))
        : DateTime(2000);

    // Non-blocking dispatch: dismiss modal sheet immediately so user can continue using the app
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Started SMS import in background...'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );

    await SmsService.performSmsSync(
      trigger: SmsSyncTrigger.historicalSheet,
      fromTime: from,
      bypassTombstones: _bypassTombstones,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + AppLayout.spaceS,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick sync automatically scans messages from the last 24 hours. Select a custom date range below to scan older history or re-import past transactions.',
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          ...List.generate(_periods.length, (i) {
            final (label, _) = _periods[i];
            return Material(
              color: Colors.transparent,
              child: RadioListTile<int>(
                title: Text(label),
                value: i,
                // ignore: deprecated_member_use
                groupValue: _selectedIndex,
                // ignore: deprecated_member_use
                onChanged: (v) => setState(() => _selectedIndex = v!),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            );
          }),
          const SizedBox(height: AppLayout.spaceM),
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
              title: const Text('Force Re-Scan Previously Deleted SMS'),
              subtitle: Text(
                'Bypasses tombstone filters to re-import transactions you previously purged.',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              value: _bypassTombstones,
              onChanged: (v) => setState(() => _bypassTombstones = v ?? false),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _runImport,
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Start Import'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

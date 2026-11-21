import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// Canonical dataset of Everything App releases and changelogs.
class ChangelogCategory {
  final String title;
  final List<String> items;

  ChangelogCategory({
    required this.title,
    required this.items,
  });

  factory ChangelogCategory.fromJson(Map<String, dynamic> json) {
    return ChangelogCategory(
      title: json['title'] as String? ?? '',
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class ChangelogRelease {
  final String version;
  final String date;
  final bool isLatest;
  final List<ChangelogCategory> categories;

  ChangelogRelease({
    required this.version,
    required this.date,
    this.isLatest = false,
    required this.categories,
  });

  factory ChangelogRelease.fromJson(Map<String, dynamic> json) {
    return ChangelogRelease(
      version: json['version'] as String? ?? '',
      date: json['date'] as String? ?? '',
      isLatest: json['isLatest'] as bool? ?? false,
      categories: (json['categories'] as List<dynamic>? ?? const [])
          .map((cat) => ChangelogCategory.fromJson(cat as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Latest release kept in Dart for synchronous rendering.
final ChangelogRelease kLatestChangelog = ChangelogRelease(
  version: 'v3.7.0',
  date: 'November 21, 2026',
  isLatest: true,
  categories: [
    ChangelogCategory(
      title: "What's New",
      items: [
        'Scan Text to Note (Offline OCR): Extract editable text directly from camera photos or embedded note images using /scan or the image menu.',
        'Proactive Budget Alerts, Bill Reminders & Weekly Digest: Get notified at 80% and 100% of monthly category budgets, 48 hours before recurring bills, and with an optional Sunday digest.',
        'Group Simplify Debts & Batch Story Slides: Calculate minimal transfers for grouped split bills and export all Story Card slides in one tap.',
        'Encrypted Auto-Backups, Per-Module Locks & Screenshot Shield: Automated backups are now encrypted with a recovery key, Finances and Health tabs lock individually, and Android screenshot protection is configurable in Security.',
      ],
    ),
    ChangelogCategory(
      title: 'Improvements',
      items: [
        'Full-Body Note Search & Period Notes: Search unlocked notes across their full body, add optional notes to period logs, and jump straight to Health from period notifications.',
        'Cleaner Finance Analytics & Broader Compatibility: Excluded account transfers from spending breakdowns, scoped budgets to the current month, and marked Wi-Fi hardware optional for more devices.',
      ],
    ),
    ChangelogCategory(
      title: 'Fixes',
      items: [
        'Biometrics & P2P Authentication: Wired the Use Biometrics toggle with PIN fallback, added integrity checks to P2P sync, and gated Story Card AI Highlights on supported devices.',
      ],
    ),
  ],
);

/// Synchronous latest-only list; call [loadFullChangelogHistory] for older releases.
final List<ChangelogRelease> kChangelogHistory = [kLatestChangelog];

List<ChangelogRelease>? _cachedFullHistory;

/// Lazily loads historical releases from [assets/changelog_history.json] and
/// prepends [kLatestChangelog], caching the result for subsequent opens.
Future<List<ChangelogRelease>> loadFullChangelogHistory({
  AssetBundle? bundle,
}) async {
  if (bundle == null && _cachedFullHistory != null) {
    return _cachedFullHistory!;
  }
  final targetBundle = bundle ?? rootBundle;
  final rawJson = await targetBundle.loadString('assets/changelog_history.json');
  final decoded = jsonDecode(rawJson) as List<dynamic>;
  final historical = decoded
      .map((entry) => ChangelogRelease.fromJson(entry as Map<String, dynamic>))
      .toList();
  final combined = <ChangelogRelease>[kLatestChangelog, ...historical];
  if (bundle == null) {
    _cachedFullHistory = combined;
  }
  return combined;
}

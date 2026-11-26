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
  version: 'v3.8.0',
  date: 'November 26, 2026',
  isLatest: true,
  categories: [
    ChangelogCategory(
      title: "What's New",
      items: [
        'Redesigned Material You Home Widgets: Streamlined to two adaptive widgets (Tasks & Notes, and Finances) that scale from compact 4x1 strips to spacious tablet and foldable layouts.',
        'Widget Privacy Lock: Automatically mask balances and checklist items on your home screen when App Lock or Finance Lock is active, with a toggle in Security Settings.',
        'Poster Story Cards & Local Wi-Fi Browser Companion: Bold chromatic Story Card themes with poster typography, plus a PIN-protected local Wi-Fi browser companion on port 8765.',
        'Dynamic App Shortcuts: Long-press shortcuts now adapt to your enabled modules, with quick access to New Note, Sync, Search, New Transaction, and Scan Receipt.',
      ],
    ),
    ChangelogCategory(
      title: 'Improvements',
      items: [
        'Faster Ledger & Tabular Numerals: Live transactions appear immediately above the fold, tabular figures keep every amount aligned, and nested card clutter is removed across Finances, Health, and Settings.',
        'Snappier Checklist Switching & Previews: Added distinct widget names and realistic previews in the Android picker, smoother list switching, and an option to start a new checklist directly.',
        'Smaller App Size & Full Translation: Trimmed ~5 MB of duplicate font assets and translated all widget labels and states across all 8 supported languages.',
      ],
    ),
    ChangelogCategory(
      title: 'Fixes',
      items: [
        'Always-Fresh Widget Updates: Fixed background sync and currency/language changes not refreshing widgets, and fixed Android 14+ task-row tap reliability.',
        'Accurate Dual-Account & Task Counts: Fixed midnight boundary totals, pending checklist filtering, and dark-mode checkbox contrast.',
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

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
  version: 'v3.8.2',
  date: 'November 26, 2026',
  isLatest: true,
  categories: [
    ChangelogCategory(
      title: "What's New",
      items: [
        'Redesigned Material You Home Widgets: Streamlined to two adaptive widgets (Tasks & Notes, and Finances) with rounded tonal task cards and edge-to-edge checklist switching.',
        'Always-Visible Home Widgets: Home widgets stay live even when App Lock or Finance Lock is active, with clear Security Settings disclosures.',
        'Poster Story Cards & Local Wi-Fi Browser Companion: Bold chromatic Story Card themes with poster typography, plus a PIN-protected local Wi-Fi browser companion on port 8765.',
      ],
    ),
    ChangelogCategory(
      title: 'Improvements',
      items: [
        'Cleaner Tasks & Notes Widget Header: Removed harsh header dividers and balanced pill proportions while keeping full 48dp touch targets.',
        'Faster Ledger & 8-Language Support: Live transactions appear immediately above the fold, tabular numerals keep figures aligned, and widget labels are translated across 8 languages.',
      ],
    ),
    ChangelogCategory(
      title: 'Fixes',
      items: [
        'Bulletproof Transaction & Note Saves: Manual transaction edits are no longer reverted by background AI, split-bill and savings goal links stay intact, and image-only notes save safely on app background.',
        'Finance Widget & App Lock Stability: Fixed random "Finances disabled" flashes on cold start, PIN-fallback re-lock loops, screen-off latch races, and module-lock resume prompts.',
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

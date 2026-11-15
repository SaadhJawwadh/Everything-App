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
  version: 'v3.5.2',
  date: 'November 15, 2026',
  isLatest: true,
  categories: [
    ChangelogCategory(
      title: 'Improvements',
      items: [
        'Android 15/16 16 KB Page Size Support: Upgraded on-device AI native libraries for full 16 KB memory page compatibility and optimized Play Store delivery.',
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

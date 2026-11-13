import 'package:flutter/material.dart';
import '../core/theme/app_layout.dart';
import '../core/ui/expressive_sliver_app_bar.dart';
import '../core/ui/app_card.dart';
import '../data/changelog_data.dart';

class ChangelogScreen extends StatefulWidget {
  const ChangelogScreen({super.key});

  @override
  State<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends State<ChangelogScreen> {
  List<ChangelogRelease> _releases = kChangelogHistory;
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final fullHistory = await loadFullChangelogHistory();
      if (!mounted) return;
      setState(() {
        _releases = fullHistory;
        _isLoadingHistory = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingHistory = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const ExpressiveSliverAppBar(
            titleText: 'Changelog',
            showBackButton: true,
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppLayout.spaceXL,
              vertical: AppLayout.spaceL,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final release = _releases[index];
                  return _buildVersionSection(
                    context,
                    release: release,
                  );
                },
                childCount: _releases.length,
              ),
            ),
          ),
          if (_isLoadingHistory)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: AppLayout.spaceXL),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVersionSection(
    BuildContext context, {
    required ChangelogRelease release,
  }) {
    final theme = Theme.of(context);
    final isLatest = release.isLatest;
    final changes = release.categories;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppLayout.spaceXL),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: isLatest ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 3,
                  ),
                  boxShadow: isLatest
                      ? [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.4),
                            blurRadius: 6,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
              ),
              Container(
                width: 2,
                height: changes.fold<double>(0.0, (acc, item) => acc + (item.items.length * 28.0) + 70.0),
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
          const SizedBox(width: AppLayout.spaceM),
          Expanded(
            child: AppCard(
              backgroundColor: isLatest
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
                  : theme.colorScheme.surfaceContainerLow,
              padding: const EdgeInsets.all(AppLayout.spaceL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            release.version,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isLatest ? theme.colorScheme.primary : null,
                            ),
                          ),
                          if (isLatest) ...[
                            const SizedBox(width: AppLayout.spaceS),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                              ),
                              child: Text(
                                'LATEST',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        release.date,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppLayout.spaceM),
                  ...changes.map((group) {
                    final cleanTitle = group.title.replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]', unicode: true), '').trim();
                    IconData groupIcon = Icons.article_outlined;
                    Color iconColor = theme.colorScheme.primary;
                    final lowerTitle = cleanTitle.toLowerCase();
                    if (lowerTitle.contains("what's new") || lowerTitle.contains("feature")) {
                      groupIcon = Icons.auto_awesome_rounded;
                      iconColor = theme.colorScheme.primary;
                    } else if (lowerTitle.contains("improvement")) {
                      groupIcon = Icons.trending_up_rounded;
                      iconColor = theme.colorScheme.tertiary;
                    } else if (lowerTitle.contains("fix")) {
                      groupIcon = Icons.build_circle_outlined;
                      iconColor = theme.colorScheme.secondary;
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(groupIcon, size: 18, color: iconColor),
                            const SizedBox(width: AppLayout.spaceXS),
                            Text(
                              cleanTitle,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppLayout.spaceS),
                        ...group.items.map((item) => Padding(
                              padding: const EdgeInsets.only(
                                left: AppLayout.spaceS,
                                bottom: AppLayout.spaceS,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '• ',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      item,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                        const SizedBox(height: AppLayout.spaceM),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

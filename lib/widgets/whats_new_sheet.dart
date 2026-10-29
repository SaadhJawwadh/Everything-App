import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:provider/provider.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import 'package:note_taking_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:note_taking_app/features/settings/presentation/screens/sections/finances_settings_screen.dart';
import 'package:note_taking_app/widgets/home/keyboard_shortcuts_dialog.dart';
import '../core/services/app_haptics.dart';
import '../core/theme/app_layout.dart';
import '../core/ui/app_card.dart';
import '../widgets/bouncing_widget.dart';

class WhatsNewSheet extends StatelessWidget {
  final String currentVersion;

  const WhatsNewSheet({
    super.key,
    required this.currentVersion,
  });

  void _finishWhatsNew(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    AppHaptics.mediumImpact();
    await settings.setLastSeenVersion(currentVersion);
    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final categories = [
      _WhatsNewCategory(
        categoryTitle: "New Features",
        categoryIcon: Icons.auto_awesome_rounded,
        categoryColor: theme.colorScheme.primary,
        bgColor: theme.colorScheme.primaryContainer.withValues(alpha: isDark ? 0.3 : 0.4),
        items: [
          _WhatsNewItem(
            icon: Icons.bolt_rounded,
            title: "Smart Action Search Cards",
            desc: "Type natural phrases like 'spent 1200 on coffee', 'todo buy milk', or 'split 3000 dinner' in Search to log in one tap.",
          ),
          _WhatsNewItem(
            icon: Icons.mic_external_on_rounded,
            title: "Hands-Free Quick Capture",
            desc: "Log expenses, tasks, or notes instantly from Android Assistant and system shortcuts with 1-tap Undo safety.",
          ),
          _WhatsNewItem(
            icon: Icons.keyboard_command_key_rounded,
            title: "Hardware Keyboard Shortcuts",
            desc: "Full keyboard navigation for tablets, foldables, and laptops (Ctrl+K Search, Ctrl+N Note, Ctrl+E Expense, Ctrl+/).",
            actionLabel: "View Shortcuts ➔",
            onAction: () {
              Navigator.pop(context);
              KeyboardShortcutsDialog.show(context);
            },
          ),
          _WhatsNewItem(
            icon: Icons.checklist_rtl_rounded,
            title: "Checklists & Tasks View",
            desc: "View and manage all active checklists across every folder from one unified view in the Folder Picker.",
          ),
        ],
      ),
      _WhatsNewCategory(
        categoryTitle: "Improvements",
        categoryIcon: Icons.trending_up_rounded,
        categoryColor: theme.colorScheme.tertiary,
        bgColor: theme.colorScheme.tertiaryContainer.withValues(alpha: isDark ? 0.3 : 0.4),
        items: [
          _WhatsNewItem(
            icon: Icons.dashboard_customize_rounded,
            title: "Interactive Settings Hub",
            desc: "Jump directly to Finances, Health Tracker, Gemini AI, Security, or Sync from the top status pills.",
            actionLabel: "Open Settings Hub ➔",
            onAction: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          _WhatsNewItem(
            icon: Icons.widgets_rounded,
            title: "Live Widget Previews",
            desc: "Rich, themed previews of your Todo, Finance, and Unified widgets in the Android 15+ home screen widget picker.",
          ),
          _WhatsNewItem(
            icon: Icons.currency_exchange_rounded,
            title: "Unified Currency Symbols",
            desc: "Authentic currency symbols (Rs., ₹, \$, €, £, ₽) displayed consistently across balance cards, ledgers, split bills, and search.",
            actionLabel: "Customize Currency ➔",
            onAction: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FinancesSettingsScreen()),
              );
            },
          ),
          _WhatsNewItem(
            icon: Icons.wifi_tethering_rounded,
            title: "Future-Proof P2P Wi-Fi Sync",
            desc: "Enhanced local network discovery for Android 16/17 alongside multi-window desktop resizing support.",
          ),
        ],
      ),
      _WhatsNewCategory(
        categoryTitle: "Fixes",
        categoryIcon: Icons.build_circle_outlined,
        categoryColor: theme.colorScheme.secondary,
        bgColor: theme.colorScheme.secondaryContainer.withValues(alpha: isDark ? 0.3 : 0.4),
        items: [
          _WhatsNewItem(
            icon: Icons.fact_check_rounded,
            title: "Pinned Checklist Routing",
            desc: "Quick-added tasks now automatically append to your active pinned widget checklist before creating a fallback list.",
          ),
          _WhatsNewItem(
            icon: Icons.undo_rounded,
            title: "Instant Action Undo Rollback",
            desc: "Undoing a quick-saved transaction or task cleanly restores your ledger balance or removes the newly added checklist item.",
          ),
          _WhatsNewItem(
            icon: Icons.savings_rounded,
            title: "Neutral Savings Transfers",
            desc: "Savings goal deposits from your Daily account use neutral transfers so monthly income totals stay accurate.",
          ),
          _WhatsNewItem(
            icon: Icons.keyboard_hide_rounded,
            title: "Keyboard-Safe Modal Sheets",
            desc: "Eliminated layout overflows across all bottom sheets and pickers when the on-screen keyboard is open.",
          ),
        ],
      ),
    ];

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppLayout.radiusXXL)),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.35),
          width: 1.0,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppLayout.spaceXL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                  const SizedBox(height: AppLayout.spaceM),
                  // Top Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppLayout.spaceXL),

                  // Header Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppLayout.spaceM),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.stars_rounded,
                          color: theme.colorScheme.onPrimaryContainer,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: AppLayout.spaceM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "What's New",
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(AppLayout.radiusS),
                              ),
                              child: Text(
                                "Version $currentVersion",
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppLayout.spaceXL),

                  // Categorized Updates List
                  Expanded(
                    child: AnimationLimiter(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: categories.length,
                        itemBuilder: (context, catIndex) {
                          final category = categories[catIndex];
                          return AnimationConfiguration.staggeredList(
                            position: catIndex,
                            duration: const Duration(milliseconds: 280),
                            child: SlideAnimation(
                              verticalOffset: 24.0,
                              child: FadeInAnimation(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: AppLayout.spaceL),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Category Pill Tag
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppLayout.spaceM,
                                          vertical: AppLayout.spaceXS,
                                        ),
                                        decoration: BoxDecoration(
                                          color: category.bgColor,
                                          borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              category.categoryIcon,
                                              size: 14,
                                              color: category.categoryColor,
                                            ),
                                            const SizedBox(width: AppLayout.spaceXS),
                                            Text(
                                              category.categoryTitle,
                                              style: theme.textTheme.titleSmall?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: category.categoryColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: AppLayout.spaceM),

                                      // Items inside AppCard containers
                                      ...category.items.map((item) {
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: AppLayout.spaceS),
                                          child: AppCard(
                                            padding: const EdgeInsets.all(AppLayout.spaceM),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(AppLayout.spaceS),
                                                  decoration: BoxDecoration(
                                                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(AppLayout.radiusM),
                                                  ),
                                                  child: Icon(
                                                    item.icon,
                                                    color: theme.colorScheme.primary,
                                                    size: 22,
                                                  ),
                                                ),
                                                const SizedBox(width: AppLayout.spaceM),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        item.title,
                                                        style: theme.textTheme.titleMedium?.copyWith(
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        item.desc,
                                                        style: theme.textTheme.bodyMedium?.copyWith(
                                                          color: theme.colorScheme.onSurfaceVariant,
                                                          height: 1.35,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                      if (item.actionLabel != null && item.onAction != null) ...[
                                                        const SizedBox(height: AppLayout.spaceS),
                                                        TextButton(
                                                          onPressed: () {
                                                            AppHaptics.selectionClick();
                                                            item.onAction!();
                                                          },
                                                          style: TextButton.styleFrom(
                                                            padding: const EdgeInsets.symmetric(
                                                              horizontal: 14,
                                                              vertical: 8,
                                                            ),
                                                            minimumSize: const Size(0, 36),
                                                            backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                                                            foregroundColor: theme.colorScheme.primary,
                                                            shape: const StadiumBorder(),
                                                          ),
                                                          child: Text(
                                                            item.actionLabel!,
                                                            style: const TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Got It Button
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppLayout.spaceL),
                    child: BouncingWidget(
                      onTap: () => _finishWhatsNew(context),
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(vertical: AppLayout.spaceM),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(AppLayout.radiusStadium),
                        ),
                        child: Center(
                          child: Text(
                            "Awesome, Got It!",
                            style: TextStyle(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
  }
}

class _WhatsNewCategory {
  final String categoryTitle;
  final IconData categoryIcon;
  final Color categoryColor;
  final Color bgColor;
  final List<_WhatsNewItem> items;

  _WhatsNewCategory({
    required this.categoryTitle,
    required this.categoryIcon,
    required this.categoryColor,
    required this.bgColor,
    required this.items,
  });
}

class _WhatsNewItem {
  final IconData icon;
  final String title;
  final String desc;
  final String? actionLabel;
  final VoidCallback? onAction;

  _WhatsNewItem({
    required this.icon,
    required this.title,
    required this.desc,
    this.actionLabel,
    this.onAction,
  });
}

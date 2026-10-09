import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../features/finances/data/transaction_repository.dart';
import '../../features/health/data/period_repository.dart';
import '../../data/transaction_model.dart';
import '../../data/period_log_model.dart';
import '../../data/transaction_category.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import '../../providers/note_provider.dart';
import '../../features/finances/presentation/screens/category_management_screen.dart';
import '../../features/finances/presentation/screens/sms_contacts_screen.dart';
import '../../features/finances/presentation/screens/sms_rules_screen.dart';
import '../../features/finances/presentation/screens/transaction_editor_screen.dart';
import '../../features/health/presentation/screens/period_tracker_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/notes/presentation/screens/manage_tags_screen.dart';
import '../../features/notes/presentation/screens/filtered_notes_screen.dart';
import '../../features/notes/presentation/screens/note_editor_screen.dart';
import '../../data/note_model.dart';
import '../../features/sync/presentation/screens/p2p_sync_screen.dart';
import '../../features/finances/presentation/widgets/recurring_rules_sheet.dart';
import '../../services/backup_service.dart';
import '../../services/sms_service.dart';
import '../../utils/app_route.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_theme.dart';

class SettingsSearchResult {
  final String title;
  final String subtitle;
  final String section;
  final IconData icon;
  final List<String> keywords;
  final VoidCallback onTap;
  final Widget? trailingWidget;

  const SettingsSearchResult({
    required this.title,
    required this.subtitle,
    this.section = 'Settings',
    required this.icon,
    required this.keywords,
    required this.onTap,
    this.trailingWidget,
  });
}

class HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final TextStyle highlightStyle;
  final int? maxLines;
  final TextOverflow? overflow;

  const HighlightedText({
    super.key,
    required this.text,
    required this.query,
    required this.style,
    required this.highlightStyle,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    if (query.trim().isEmpty) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final q = query.trim().toLowerCase();
    final tLower = text.toLowerCase();
    final index = tLower.indexOf(q);

    if (index == -1) {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
        overflow: overflow,
      );
    }

    final before = text.substring(0, index);
    final match = text.substring(index, index + q.length);
    final after = text.substring(index + q.length);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: before, style: style),
          TextSpan(text: match, style: highlightStyle),
          TextSpan(text: after, style: style),
        ],
      ),
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

class UniversalSearchOverlay extends StatefulWidget {
  final String query;

  const UniversalSearchOverlay({super.key, required this.query});

  @override
  State<UniversalSearchOverlay> createState() => _UniversalSearchOverlayState();
}

class _UniversalSearchOverlayState extends State<UniversalSearchOverlay> {
  Future<List<dynamic>>? _searchFuture;
  String _selectedScope =
      'All'; // 'All' | 'Settings' | 'Notes' | 'Finances' | 'Health'
  bool _isTestingSync = false;

  @override
  void initState() {
    super.initState();
    _updateSearchFuture();
  }

  @override
  void didUpdateWidget(covariant UniversalSearchOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _updateSearchFuture();
    }
  }

  void _updateSearchFuture() {
    final q = widget.query.trim();
    if (q.length < 2) {
      _searchFuture = null;
    } else {
      _searchFuture = Future.wait([
        TransactionRepository.instance.searchTransactions(q),
        PeriodRepository.instance.searchPeriodLogs(q),
      ]);
    }
  }

  bool _fuzzyMatch(String text, String search) {
    if (search.isEmpty) return false;
    final t = text.toLowerCase();
    final q = search.toLowerCase();

    // Fast path 1: Instant substring check
    if (t.contains(q)) return true;

    // Fast path 2: Fuzzy match only for queries >= 4 chars to prevent CPU matrix churn
    if (q.length < 4) return false;

    final words = t.split(RegExp(r'\s+'));
    for (final word in words) {
      if ((word.length - q.length).abs() > 2) continue;
      if (_fastLevenshtein(word, q) <= 1) return true;
    }
    return false;
  }

  int _fastLevenshtein(String a, String b) {
    if (a == b) return 0;
    final lenA = a.length;
    final lenB = b.length;

    List<int> v0 = List<int>.generate(lenB + 1, (i) => i);
    List<int> v1 = List<int>.filled(lenB + 1, 0);

    for (int i = 0; i < lenA; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < lenB; j++) {
        final cost = (a.codeUnitAt(i) == b.codeUnitAt(j)) ? 0 : 1;
        final del = v0[j + 1] + 1;
        final ins = v1[j] + 1;
        final sub = v0[j] + cost;
        int min = del < ins ? del : ins;
        v1[j + 1] = min < sub ? min : sub;
      }
      for (int k = 0; k <= lenB; k++) {
        v0[k] = v1[k];
      }
    }
    return v1[lenB];
  }

  List<SettingsSearchResult> _searchSettings(BuildContext context, String q) {
    final search = q.trim().toLowerCase();
    if (search.isEmpty) return [];

    final settings = Provider.of<SettingsProvider>(context, listen: false);

    final allItems = <SettingsSearchResult>[
      // Security
      SettingsSearchResult(
        title: 'App Lock & Security',
        subtitle: 'Configure PIN & biometric protection',
        section: 'Security',
        icon: Icons.lock_outlined,
        keywords: [
          'app lock',
          'security',
          'pin',
          'biometrics',
          'password',
          'timeout',
          'lock',
          'fingerprint',
          'face unlock',
        ],
        onTap: () => AppRoute.push(context, const SettingsScreen(initialQuery: 'App Lock')),
        trailingWidget: Switch.adaptive(
          value: settings.appLockEnabled,
          onChanged: (val) async {
            await settings.setAppLockEnabled(val);
            if (mounted) setState(() {});
          },
        ),
      ),

      // Finances
      SettingsSearchResult(
        title: 'SMS Auto-Sync',
        subtitle: 'Daily background SMS transaction import',
        section: 'Finances',
        icon: Icons.sync_outlined,
        keywords: [
          'auto sync',
          'sms sync',
          'daily sync',
          'background sync',
          'test sync',
          'telephony',
          'bank parser',
        ],
        onTap: () => AppRoute.push(context, const SettingsScreen(initialQuery: 'SMS')),
        trailingWidget: _isTestingSync
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : OutlinedButton(
                style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10)),
                onPressed: () async {
                  setState(() => _isTestingSync = true);
                  final messenger = ScaffoldMessenger.of(context);
                  await SmsService.performDailyTransactionSync();
                  if (mounted) {
                    setState(() => _isTestingSync = false);
                    messenger.showSnackBar(
                      const SnackBar(
                          content: Text('SMS Auto-Sync check complete'),
                          behavior: SnackBarBehavior.floating),
                    );
                  }
                },
                child: const Text('Test', style: TextStyle(fontSize: 12)),
              ),
      ),
      SettingsSearchResult(
        title: 'Currency',
        subtitle: 'Select currency symbol (${settings.currencySymbol} - LKR, USD, EUR, INR...)',
        section: 'Finances',
        icon: Icons.monetization_on_outlined,
        keywords: ['currency', 'symbol', 'usd', 'lkr', 'eur', 'gbp', 'inr', 'rupee', 'dollar', 'money'],
        onTap: () => AppRoute.push(context, const SettingsScreen(initialQuery: 'Currency')),
      ),
      SettingsSearchResult(
        title: 'Manage Categories',
        subtitle: 'Customise transaction categories & keywords',
        section: 'Finances',
        icon: Icons.category_outlined,
        keywords: [
          'category',
          'categories',
          'manage categories',
          'icons',
          'keywords',
          'ledger'
        ],
        onTap: () => AppRoute.push(context, const CategoryManagementScreen()),
      ),
      SettingsSearchResult(
        title: 'Savings Goals & Vault',
        subtitle: 'Goal pockets, milestone targets & vault reserve transfers',
        section: 'Finances',
        icon: Icons.savings_outlined,
        keywords: ['savings', 'savings goals', 'vault', 'pocket', 'piggy bank', 'deposit', 'emergency fund'],
        onTap: () => AppRoute.push(context, const SettingsScreen(initialQuery: 'Savings')),
      ),
      SettingsSearchResult(
        title: 'Split Bills & Shared Debts',
        subtitle: 'Split receipts with friends and record settlement repayments',
        section: 'Finances',
        icon: Icons.call_split_rounded,
        keywords: ['split bills', 'split', 'iou', 'shared debt', 'group expense', 'friends', 'settle up', 'whatsapp'],
        onTap: () => AppRoute.push(context, const SettingsScreen(initialQuery: 'Split Bills')),
      ),
      SettingsSearchResult(
        title: 'SMS Contacts',
        subtitle: 'Manage recognized bank senders for auto-import',
        section: 'Finances',
        icon: Icons.contacts_outlined,
        keywords: ['sms contacts', 'contacts', 'senders', 'bank', 'phone', 'whitelist', 'blacklist'],
        onTap: () => AppRoute.push(context, const SmsContactsScreen()),
      ),
      SettingsSearchResult(
        title: 'SMS Import Rules',
        subtitle: 'Auto-categorization & transaction type rules',
        section: 'Finances',
        icon: Icons.rule_folder_outlined,
        keywords: [
          'sms rules',
          'auto categorize',
          'income rules',
          'expense rules',
          'train parser',
        ],
        onTap: () => AppRoute.push(context, const SmsRulesScreen()),
      ),
      SettingsSearchResult(
        title: 'Recurring Transactions',
        subtitle: 'Manage automatically repeating ledger entries',
        section: 'Finances',
        icon: Icons.event_repeat_outlined,
        keywords: [
          'recurring',
          'rules',
          'repeating',
          'subscription',
          'auto transaction',
          'salary',
        ],
        onTap: () {
          final currency = context.read<SettingsProvider>().currency;
          RecurringRulesSheet.show(
            context: context,
            currency: currency,
            onRulesUpdated: () {},
          );
        },
      ),

      // Data & Backups
      SettingsSearchResult(
        title: 'Export & Import Backup',
        subtitle: 'Save or restore all notes and settings to encrypted JSON file',
        section: 'Data',
        icon: Icons.backup_outlined,
        keywords: [
          'backup',
          'export backup',
          'import backup',
          'restore',
          'json',
          'encrypted',
          'saf',
          'storage',
        ],
        onTap: () => AppRoute.push(context, const SettingsScreen(initialQuery: 'Backup')),
      ),
      SettingsSearchResult(
        title: 'Import Transactions (CSV)',
        subtitle: 'Import transaction records from CSV file',
        section: 'Data',
        icon: Icons.file_upload_outlined,
        keywords: [
          'import csv',
          'csv',
          'import transactions',
          'excel',
          'ledger csv',
        ],
        onTap: () => BackupService.importTransactionsFromCsv(context),
      ),
      SettingsSearchResult(
        title: 'P2P Device Sync',
        subtitle: 'Sync notes & finances with paired devices over Wi-Fi',
        section: 'Data',
        icon: Icons.sync_rounded,
        keywords: [
          'p2p',
          'sync',
          'device sync',
          'pair',
          'wifi sync',
          'pair device',
          'qr code',
          'paired devices',
          'p2p sync',
        ],
        onTap: () => AppRoute.push(context, const P2pSyncScreen()),
      ),
      SettingsSearchResult(
        title: 'Google Keep Import',
        subtitle: 'Import notes and archives from Google Takeout ZIP',
        section: 'Data',
        icon: Icons.archive_outlined,
        keywords: ['google keep', 'takeout', 'import notes', 'keep notes', 'migration', 'zip import'],
        onTap: () => AppRoute.push(context, const SettingsScreen(initialQuery: 'Google Keep')),
      ),

      // Features
      SettingsSearchResult(
        title: 'Period Tracker',
        subtitle: 'Optional cycle tracking and symptom logs',
        section: 'Features',
        icon: Icons.water_drop_outlined,
        keywords: [
          'period',
          'tracker',
          'cycle',
          'health',
          'symptoms',
          'ovulation',
          'menstrual',
          'lunar',
        ],
        onTap: () => AppRoute.push(context, const PeriodTrackerScreen()),
      ),
      SettingsSearchResult(
        title: 'Gemini Nano AI',
        subtitle: 'Offline note summaries, tag suggestions & smart SMS parsing',
        section: 'Features',
        icon: Icons.auto_awesome_outlined,
        keywords: [
          'ai',
          'gemini',
          'nano',
          'summaries',
          'tag suggestions',
          'smart sms',
          'on device ai',
        ],
        onTap: () => AppRoute.push(context, const SettingsScreen(initialQuery: 'Gemini')),
      ),
      SettingsSearchResult(
        title: 'Manage Tags',
        subtitle: 'View, edit, and organize all note tags',
        section: 'Features',
        icon: Icons.label_outlined,
        keywords: ['tags', 'manage tags', 'labels', 'tag colors', 'rename tag'],
        onTap: () => AppRoute.push(context, const ManageTagsScreen()),
      ),
      SettingsSearchResult(
        title: 'Archive',
        subtitle: 'View archived notes',
        section: 'Features',
        icon: Icons.archive_outlined,
        keywords: ['archive', 'archived', 'hidden notes'],
        onTap: () => AppRoute.push(context,
            const FilteredNotesScreen(filterType: FilterType.archived)),
      ),
      SettingsSearchResult(
        title: 'Trash',
        subtitle: 'View deleted notes',
        section: 'Features',
        icon: Icons.delete_outline,
        keywords: ['trash', 'deleted', 'restore deleted', 'bin', 'purge'],
        onTap: () => AppRoute.push(
            context, const FilteredNotesScreen(filterType: FilterType.trash)),
      ),
      SettingsSearchResult(
        title: 'Folders',
        subtitle: 'Organize and manage note folders',
        section: 'Features',
        icon: Icons.folder_outlined,
        keywords: [
          'folder',
          'folders',
          'organize',
          'category',
          'notebook',
          'move note',
          'create folder',
        ],
        onTap: () => AppRoute.push(context, const SettingsScreen(initialQuery: 'Folders')),
      ),

      // Appearance
      SettingsSearchResult(
        title: 'App Theme & Color',
        subtitle: 'Switch light/dark mode and dynamic Material You colors',
        section: 'Appearance',
        icon: Icons.palette_outlined,
        keywords: [
          'theme',
          'dark mode',
          'light mode',
          'color',
          'dynamic color',
          'material you',
          'wallpaper',
          'appearance',
          'dark',
          'light',
          'oled',
        ],
        onTap: () => AppRoute.push(context, const SettingsScreen(initialQuery: 'Theme')),
      ),
      SettingsSearchResult(
        title: 'Text Size',
        subtitle: 'Adjust app-wide font size for comfortable reading',
        section: 'Appearance',
        icon: Icons.text_fields_outlined,
        keywords: [
          'text size',
          'font size',
          'font',
          'reading',
          'accessibility',
          'large text',
          'small text',
          'text scale',
        ],
        onTap: () => AppRoute.push(context, const SettingsScreen(initialQuery: 'Text Size')),
      ),

      // About
      SettingsSearchResult(
        title: 'What\'s New / Changelog',
        subtitle: 'View latest release highlights and version history',
        section: 'About',
        icon: Icons.new_releases_outlined,
        keywords: ['changelog', 'whats new', 'updates', 'version', 'release notes', 'history'],
        onTap: () => AppRoute.push(context, const SettingsScreen(initialQuery: 'Changelog')),
      ),
      SettingsSearchResult(
        title: 'Replay Onboarding',
        subtitle: 'Tour features, personalization, and core architecture setup',
        section: 'About',
        icon: Icons.explore_outlined,
        keywords: ['onboarding', 'tutorial', 'tour', 'setup wizard', 'welcome', 'guide'],
        onTap: () => AppRoute.push(context, const SettingsScreen(initialQuery: 'Onboarding')),
      ),
    ];

    return allItems.where((item) {
      return _fuzzyMatch(item.title, search) ||
          _fuzzyMatch(item.subtitle, search) ||
          _fuzzyMatch(item.section, search) ||
          item.keywords.any((k) => _fuzzyMatch(k, search));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.query.trim().isEmpty) return const SizedBox.shrink();
    final settingsResults = _searchSettings(context, widget.query);
    final noteProvider = context.watch<NoteProvider>();

    return FutureBuilder<List<dynamic>>(
      future: _searchFuture,
      builder: (context, snapshot) {
        final transactions =
            (snapshot.data?[0] as List<TransactionModel>? ?? [])
                .where((t) =>
                    _fuzzyMatch(t.description, widget.query) ||
                    _fuzzyMatch(t.category, widget.query))
                .toList();
        final periodLogs = (snapshot.data?[1] as List<PeriodLog>? ?? [])
            .where((p) =>
                _fuzzyMatch(p.intensity, widget.query) ||
                _fuzzyMatch(p.notes, widget.query))
            .toList();
        final noteCount = noteProvider.filteredNotes.length;

        if (settingsResults.isEmpty &&
            transactions.isEmpty &&
            periodLogs.isEmpty &&
            noteCount == 0) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No results found',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try searching with a different keyword',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () {
                      noteProvider.setSearchQuery('');
                    },
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear Search'),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Category Filter Chips Bar (Scope Selection) ─────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildScopeChip(
                        'All',
                        settingsResults.length +
                            noteCount +
                            transactions.length +
                            periodLogs.length),
                    if (noteCount > 0) _buildScopeChip('Notes', noteCount),
                    if (settingsResults.isNotEmpty)
                      _buildScopeChip('Settings', settingsResults.length),
                    if (transactions.isNotEmpty)
                      _buildScopeChip('Finances', transactions.length),
                    if (periodLogs.isNotEmpty)
                      _buildScopeChip('Health', periodLogs.length),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Results Sections ────────────────────────────────────────
              if ((_selectedScope == 'All' || _selectedScope == 'Notes') &&
                  noteCount > 0) ...[
                _buildSectionHeader(
                    context, 'Notes', Icons.notes_rounded),
                const SizedBox(height: 8),
                ...noteProvider.filteredNotes.map((n) => _buildNoteCard(context, n)),
                const SizedBox(height: 12),
              ],
              if ((_selectedScope == 'All' || _selectedScope == 'Settings') &&
                  settingsResults.isNotEmpty) ...[
                _buildSectionHeader(
                    context, 'Settings & Tools', Icons.settings_outlined),
                const SizedBox(height: 8),
                ...settingsResults.map((s) => _buildSettingsCard(context, s)),
                const SizedBox(height: 12),
              ],
              if ((_selectedScope == 'All' || _selectedScope == 'Finances') &&
                  transactions.isNotEmpty) ...[
                _buildSectionHeader(context, 'Financial Transactions',
                    Icons.account_balance_wallet_outlined),
                const SizedBox(height: 8),
                ...transactions.map((t) => _buildTransactionCard(context, t)),
                const SizedBox(height: 12),
              ],
              if ((_selectedScope == 'All' || _selectedScope == 'Health') &&
                  periodLogs.isNotEmpty) ...[
                _buildSectionHeader(
                    context, 'Health Logs', Icons.health_and_safety_outlined),
                const SizedBox(height: 8),
                ...periodLogs.map((p) => _buildPeriodLogCard(context, p)),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildScopeChip(String label, int count) {
    final isSelected = _selectedScope == label;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        showCheckmark: false,
        selected: isSelected,
        label: Text('$label ($count)'),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
        ),
        selectedColor: theme.colorScheme.primaryContainer,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        onSelected: (val) {
          setState(() {
            _selectedScope = label;
          });
        },
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(BuildContext context, SettingsSearchResult s) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.radiusL),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(s.icon, color: primaryColor, size: 18),
        ),
        title: Row(
          children: [
            Expanded(
              child: HighlightedText(
                text: s.title,
                query: widget.query,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                highlightStyle: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14, color: primaryColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppLayout.radiusXS),
              ),
              child: Text(
                s.section,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ),
              ),
            ),
          ],
        ),
        subtitle: HighlightedText(
          text: s.subtitle,
          query: widget.query,
          style: TextStyle(
              fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
          highlightStyle: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: s.trailingWidget ??
            Icon(Icons.arrow_forward_ios,
                size: 14, color: theme.colorScheme.onSurfaceVariant),
        onTap: s.onTap,
      ),
    ),
  );
  }

  Widget _buildTransactionCard(BuildContext context, TransactionModel t) {
    final theme = Theme.of(context);
    final catColor = TransactionCategory.colorFor(t.category);
    final catIcon = TransactionCategory.iconFor(t.category);
    final primaryColor = theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.radiusL),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: catColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: catColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(catIcon, color: catColor, size: 18),
        ),
        title: HighlightedText(
          text: t.description,
          query: widget.query,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          highlightStyle: TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text("${t.category} • ${DateFormat.yMMMd().format(t.date)}",
            style: const TextStyle(fontSize: 12)),
        trailing: Text(
          "${t.isExpense ? '-' : '+'}${t.amount.toStringAsFixed(2)}",
          style: TextStyle(
            color: t.isExpense
                ? theme.colorScheme.error
                : (theme.extension<AppSemanticColors>()?.success ?? theme.colorScheme.primary),
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: () =>
            AppRoute.push(context, TransactionEditorScreen(transaction: t)),
      ),
    ),
  );
  }

  Widget _buildPeriodLogCard(BuildContext context, PeriodLog log) {
    final theme = Theme.of(context);
    final healthColor = theme.colorScheme.error;
    final primaryColor = theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.radiusL),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: healthColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: healthColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(Icons.water_drop_outlined, color: healthColor, size: 18),
        ),
        title: HighlightedText(
          text: "Period Log: ${log.intensity}",
          query: widget.query,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          highlightStyle: TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text("Started: ${DateFormat.yMMMd().format(log.startDate)}",
            style: const TextStyle(fontSize: 12)),
        onTap: () => AppRoute.push(context, const PeriodTrackerScreen()),
      ),
    ),
  );
  }

  Widget _buildNoteCard(BuildContext context, Note note) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.radiusL),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: note.isLocked
                  ? theme.colorScheme.error.withValues(alpha: 0.15)
                  : primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: note.isLocked
                    ? theme.colorScheme.error.withValues(alpha: 0.3)
                    : primaryColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(
              note.isLocked
                  ? Icons.lock_outline_rounded
                  : (note.isPinned ? Icons.push_pin_rounded : Icons.note_alt_outlined),
              color: note.isLocked ? theme.colorScheme.error : primaryColor,
              size: 18,
            ),
          ),
          title: HighlightedText(
            text: note.title.isNotEmpty ? note.title : 'Untitled',
            query: widget.query,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            highlightStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: primaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: note.isLocked
              ? Text(
                  'Locked Note (Tap to unlock)',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                )
              : HighlightedText(
                  text: note.previewText ?? '',
                  query: widget.query,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  highlightStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          onTap: () {
            AppRoute.push(context, NoteEditorScreen(note: note)).then((_) {
              if (context.mounted) {
                context.read<NoteProvider>().refreshNotes();
              }
            });
          },
        ),
      ),
    );
  }
}

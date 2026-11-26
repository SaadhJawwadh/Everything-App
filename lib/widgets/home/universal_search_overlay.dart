import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import '../../screens/app_lock_screen.dart';
import '../../features/finances/data/transaction_repository.dart';
import '../../features/health/data/period_repository.dart';
import '../../data/transaction_model.dart';
import '../../data/period_log_model.dart';
import '../../data/transaction_category.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import 'package:note_taking_app/features/notes/providers/note_provider.dart';
import '../../features/finances/presentation/screens/category_management_screen.dart';
import '../../features/finances/presentation/screens/financial_manager_screen.dart';
import '../../features/finances/presentation/screens/sms_contacts_screen.dart';
import '../../features/finances/presentation/screens/sms_rules_screen.dart';
import '../../features/finances/presentation/screens/transaction_editor_screen.dart';
import '../../features/finances/providers/financial_manager_provider.dart';
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
import '../../core/routes/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/app_card.dart';
import '../../core/ui/module_lock_gate.dart';
import '../../utils/app_globals.dart';
import 'a2ui_smart_action_card.dart';
import 'keyboard_shortcuts_dialog.dart';

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
    AppLockScreen.moduleSessionEpoch.addListener(_onModuleSessionChanged);
    _updateSearchFuture();
  }

  @override
  void dispose() {
    AppLockScreen.moduleSessionEpoch.removeListener(_onModuleSessionChanged);
    super.dispose();
  }

  void _onModuleSessionChanged() {
    if (!mounted) return;
    setState(() {
      _updateSearchFuture();
    });
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
      return;
    }
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final canSearchFinances = settings.showFinancialManager &&
        !ModuleLockGate.isModuleCurrentlyLocked(settings, 'finances');
    final canSearchHealth = settings.isPeriodTrackerEnabled &&
        !ModuleLockGate.isModuleCurrentlyLocked(settings, 'health');

    _searchFuture = Future.wait([
      canSearchFinances
          ? TransactionRepository.instance.searchTransactions(q)
          : Future.value(<TransactionModel>[]),
      canSearchHealth
          ? PeriodRepository.instance.searchPeriodLogs(q)
          : Future.value(<PeriodLog>[]),
    ]);
  }

  static final RegExp _whitespaceRegex = RegExp(r'\s+');

  bool _fuzzyMatch(String text, String search) {
    if (search.isEmpty) return false;
    final t = text.toLowerCase();
    final q = search.toLowerCase();

    // Fast path 1: Instant substring check
    if (t.contains(q)) return true;

    // Fast path 2: Fuzzy match only for queries >= 4 chars to prevent CPU matrix churn
    if (q.length < 4) return false;

    final words = t.split(_whitespaceRegex);
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
    final isFinancesLocked =
        ModuleLockGate.isModuleCurrentlyLocked(settings, 'finances');
    final isHealthLocked =
        ModuleLockGate.isModuleCurrentlyLocked(settings, 'health');

    void openFinancesFeature(VoidCallback action) {
      if (isFinancesLocked) {
        appTabNavigationRequest.value = 'finances';
        return;
      }
      action();
    }

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
        onTap: () => AppRouter.push(context, const SettingsScreen(initialQuery: 'App Lock')),
        trailingWidget: Switch.adaptive(
          value: settings.appLockEnabled,
          onChanged: (val) async {
            if (!val) {
              final auth = LocalAuthentication();
              try {
                final canCheck = await auth.canCheckBiometrics ||
                    await auth.isDeviceSupported();
                if (canCheck) {
                  final didAuth = await AppLockScreen.withLockIgnored(
                    () => auth.authenticate(
                      localizedReason: 'Authenticate to disable App Lock',
                      options: const AuthenticationOptions(
                        stickyAuth: true,
                        biometricOnly: false,
                      ),
                    ),
                  );
                  if (!didAuth) return;
                  await AppLockScreen.resetNativeLockFlag();
                }
              } on PlatformException catch (e) {
                if (e.code != 'NotAvailable' &&
                    e.code != 'PasscodeNotSet' &&
                    e.code != 'NotEnrolled') {
                  return;
                }
              } catch (_) {
                return;
              }
            } else {
              AppLockScreen.unlockSession();
            }
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
        onTap: () => AppRouter.push(context, const SettingsScreen(initialQuery: 'SMS')),
        trailingWidget: !settings.showFinancialManager
            ? null
            : (_isTestingSync
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10)),
                    onPressed: () => openFinancesFeature(() async {
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
                    }),
                    child: const Text('Test'),
                  )),
      ),
      SettingsSearchResult(
        title: 'Currency',
        subtitle: 'Select currency symbol (${settings.currencySymbol} - LKR, USD, EUR, INR...)',
        section: 'Finances',
        icon: Icons.monetization_on_outlined,
        keywords: ['currency', 'symbol', 'usd', 'lkr', 'eur', 'gbp', 'inr', 'rupee', 'dollar', 'money'],
        onTap: () => AppRouter.push(context, const SettingsScreen(initialQuery: 'Currency')),
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
        onTap: () => openFinancesFeature(
          () => AppRouter.push(context, const CategoryManagementScreen()),
        ),
      ),
      SettingsSearchResult(
        title: 'Savings Goals & Vault',
        subtitle: 'Goal pockets, milestone targets & vault reserve transfers',
        section: 'Finances',
        icon: Icons.savings_outlined,
        keywords: ['savings', 'savings goals', 'vault', 'pocket', 'piggy bank', 'deposit', 'emergency fund'],
        onTap: () => AppRouter.push(context, const SettingsScreen(initialQuery: 'Savings')),
      ),
      SettingsSearchResult(
        title: 'Split Bills & Shared Debts',
        subtitle: 'Split receipts with friends and record settlement repayments',
        section: 'Finances',
        icon: Icons.call_split_rounded,
        keywords: ['split bills', 'split', 'iou', 'shared debt', 'group expense', 'friends', 'settle up', 'whatsapp'],
        onTap: () => AppRouter.push(context, const SettingsScreen(initialQuery: 'Split Bills')),
      ),
      SettingsSearchResult(
        title: 'SMS Contacts',
        subtitle: 'Manage recognized bank senders for auto-import',
        section: 'Finances',
        icon: Icons.contacts_outlined,
        keywords: ['sms contacts', 'contacts', 'senders', 'bank', 'phone', 'whitelist', 'blacklist'],
        onTap: () => openFinancesFeature(
          () => AppRouter.push(context, const SmsContactsScreen()),
        ),
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
        onTap: () => openFinancesFeature(
          () => AppRouter.push(context, const SmsRulesScreen()),
        ),
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
        onTap: () => openFinancesFeature(() {
          final currency = context.read<SettingsProvider>().currencySymbol;
          RecurringRulesSheet.show(
            context: context,
            currency: currency,
            onRulesUpdated: () {
              if (!mounted) return;
              setState(() {
                _updateSearchFuture();
              });
              context.read<FinancialManagerProvider?>()?.loadTransactions();
              FinancialManagerScreen.refreshNotifier.value++;
            },
          );
        }),
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
        onTap: () => AppRouter.push(context, const SettingsScreen(initialQuery: 'Backup')),
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
        onTap: () => openFinancesFeature(
          () => BackupService.importTransactionsFromCsv(context),
        ),
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
        onTap: () => AppRouter.push(context, const P2pSyncScreen()),
      ),
      SettingsSearchResult(
        title: 'Google Keep Import',
        subtitle: 'Import notes and archives from Google Takeout ZIP',
        section: 'Data',
        icon: Icons.archive_outlined,
        keywords: ['google keep', 'takeout', 'import notes', 'keep notes', 'migration', 'zip import'],
        onTap: () => AppRouter.push(context, const SettingsScreen(initialQuery: 'Google Keep')),
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
        onTap: () {
          if (isHealthLocked) {
            appTabNavigationRequest.value = 'health';
            return;
          }
          AppRouter.push(context, const PeriodTrackerScreen());
        },
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
        onTap: () => AppRouter.push(context, const SettingsScreen(initialQuery: 'Gemini')),
      ),
      SettingsSearchResult(
        title: 'Manage Tags',
        subtitle: 'View, edit, and organize all note tags',
        section: 'Features',
        icon: Icons.label_outlined,
        keywords: ['tags', 'manage tags', 'labels', 'tag colors', 'rename tag'],
        onTap: () {
          AppRouter.push(context, const ManageTagsScreen()).then((_) {
            if (context.mounted) {
              context.read<NoteProvider>().refreshNotes();
            }
          });
        },
      ),
      SettingsSearchResult(
        title: 'Archive',
        subtitle: 'View archived notes',
        section: 'Features',
        icon: Icons.archive_outlined,
        keywords: ['archive', 'archived', 'hidden notes'],
        onTap: () {
          AppRouter.push(
            context,
            const FilteredNotesScreen(filterType: FilterType.archived),
          ).then((_) {
            if (context.mounted) {
              context.read<NoteProvider>().refreshNotes();
            }
          });
        },
      ),
      SettingsSearchResult(
        title: 'Trash',
        subtitle: 'View deleted notes',
        section: 'Features',
        icon: Icons.delete_outline,
        keywords: ['trash', 'deleted', 'restore deleted', 'bin', 'purge'],
        onTap: () {
          AppRouter.push(
            context,
            const FilteredNotesScreen(filterType: FilterType.trash),
          ).then((_) {
            if (context.mounted) {
              context.read<NoteProvider>().refreshNotes();
            }
          });
        },
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
        onTap: () => AppRouter.push(context, const SettingsScreen(initialQuery: 'Folders')),
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
        onTap: () => AppRouter.push(context, const SettingsScreen(initialQuery: 'Theme')),
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
        onTap: () => AppRouter.push(context, const SettingsScreen(initialQuery: 'Text Size')),
      ),

      // About
      SettingsSearchResult(
        title: 'What\'s New / Changelog',
        subtitle: 'View latest release highlights and version history',
        section: 'About',
        icon: Icons.new_releases_outlined,
        keywords: ['changelog', 'whats new', 'updates', 'version', 'release notes', 'history'],
        onTap: () => AppRouter.push(context, const SettingsScreen(initialQuery: 'Changelog')),
      ),
      SettingsSearchResult(
        title: 'Replay Onboarding',
        subtitle: 'Tour features, personalization, and core architecture setup',
        section: 'About',
        icon: Icons.explore_outlined,
        keywords: ['onboarding', 'tutorial', 'tour', 'setup wizard', 'welcome', 'guide'],
        onTap: () => AppRouter.push(context, const SettingsScreen(initialQuery: 'Onboarding')),
      ),
      SettingsSearchResult(
        title: 'Keyboard Shortcuts',
        subtitle: 'View hardware keyboard shortcuts for Google Books, tablets, and desktops (Ctrl + /)',
        section: 'Shortcuts',
        icon: Icons.keyboard_alt_outlined,
        keywords: [
          'keyboard',
          'shortcuts',
          'hotkeys',
          'google book',
          'laptop',
          'tablet',
          'ctrl',
          'cmd',
        ],
        onTap: () => KeyboardShortcutsDialog.show(context),
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
    final settings = context.watch<SettingsProvider>();
    final canShowFinances = settings.showFinancialManager &&
        !ModuleLockGate.isModuleCurrentlyLocked(settings, 'finances');
    final canShowHealth = settings.isPeriodTrackerEnabled &&
        !ModuleLockGate.isModuleCurrentlyLocked(settings, 'health');
    final settingsResults = _searchSettings(context, widget.query);
    final noteProvider = context.watch<NoteProvider>();

    return FutureBuilder<List<dynamic>>(
      future: _searchFuture,
      builder: (context, snapshot) {
        final transactions = canShowFinances
            ? (snapshot.data?[0] as List<TransactionModel>? ?? [])
                .where((t) =>
                    _fuzzyMatch(t.description, widget.query) ||
                    _fuzzyMatch(t.category, widget.query))
                .toList()
            : <TransactionModel>[];
        final periodLogs = canShowHealth
            ? (snapshot.data?[1] as List<PeriodLog>? ?? [])
                .where((p) =>
                    _fuzzyMatch(p.intensity, widget.query) ||
                    _fuzzyMatch(p.notes, widget.query))
                .toList()
            : <PeriodLog>[];
        final noteCount = noteProvider.filteredNotes.length;

        if (settingsResults.isEmpty &&
            transactions.isEmpty &&
            periodLogs.isEmpty &&
            noteCount == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                A2uiSmartActionCard(
                  query: widget.query,
                  onActionExecuted: () {
                    noteProvider.setSearchQuery('');
                  },
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 40.0),
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
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try searching with a different keyword',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
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
                ),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              A2uiSmartActionCard(
                query: widget.query,
                onActionExecuted: () {
                  noteProvider.setSearchQuery('');
                },
              ),
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
                ...List.generate(
                  noteProvider.filteredNotes.length,
                  (i) => _buildNoteCard(
                    context,
                    noteProvider.filteredNotes[i],
                    _groupPosition(i, noteProvider.filteredNotes.length),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if ((_selectedScope == 'All' || _selectedScope == 'Settings') &&
                  settingsResults.isNotEmpty) ...[
                _buildSectionHeader(
                    context, 'Settings & Tools', Icons.settings_outlined),
                const SizedBox(height: 8),
                ...List.generate(
                  settingsResults.length,
                  (i) => _buildSettingsCard(
                    context,
                    settingsResults[i],
                    _groupPosition(i, settingsResults.length),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if ((_selectedScope == 'All' || _selectedScope == 'Finances') &&
                  transactions.isNotEmpty) ...[
                _buildSectionHeader(context, 'Financial Transactions',
                    Icons.account_balance_wallet_outlined),
                const SizedBox(height: 8),
                ...List.generate(
                  transactions.length,
                  (i) => _buildTransactionCard(
                    context,
                    transactions[i],
                    _groupPosition(i, transactions.length),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if ((_selectedScope == 'All' || _selectedScope == 'Health') &&
                  periodLogs.isNotEmpty) ...[
                _buildSectionHeader(
                    context, 'Health Logs', Icons.health_and_safety_outlined),
                const SizedBox(height: 8),
                ...List.generate(
                  periodLogs.length,
                  (i) => _buildPeriodLogCard(
                    context,
                    periodLogs[i],
                    _groupPosition(i, periodLogs.length),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }

  AppCardGroupPosition _groupPosition(int index, int length) {
    if (length <= 1) return AppCardGroupPosition.single;
    if (index == 0) return AppCardGroupPosition.first;
    if (index == length - 1) return AppCardGroupPosition.last;
    return AppCardGroupPosition.middle;
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
        labelStyle: theme.textTheme.labelLarge?.copyWith(
          fontFamily: AppTheme.fontGoogleSansFlex,
          fontFamilyFallback: AppTheme.fontFallbacks,
          fontSize: 13.0,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          fontFeatures: const [FontFeature.tabularFigures()],
          fontVariations: AppTheme.buildFontVariations(
            size: 13.0,
            brightness: theme.brightness,
            weight: isSelected ? 700 : 500,
          ),
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

  Widget _buildSettingsCard(
      BuildContext context, SettingsSearchResult s, AppCardGroupPosition groupPosition) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
          fontFamily: AppTheme.fontGoogleSansFlex,
          fontFamilyFallback: AppTheme.fontFallbacks,
          fontWeight: FontWeight.w600,
          fontVariations: AppTheme.buildFontVariations(
            size: 14.0,
            brightness: theme.brightness,
            weight: 600,
          ),
        ) ??
        const TextStyle(fontWeight: FontWeight.w600, fontSize: 14);
    final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
          fontSize: 13.0,
          color: theme.colorScheme.onSurfaceVariant,
        ) ??
        TextStyle(fontSize: 13.0, color: theme.colorScheme.onSurfaceVariant);

    return AppCard(
      groupPosition: groupPosition,
      margin: const EdgeInsets.only(bottom: 2),
      padding: EdgeInsets.zero,
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(s.icon, color: primaryColor, size: 18),
        ),
        title: HighlightedText(
          text: s.title,
          query: widget.query,
          style: titleStyle,
          highlightStyle: titleStyle.copyWith(color: primaryColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: HighlightedText(
          text: '${s.section} · ${s.subtitle}',
          query: widget.query,
          style: subtitleStyle,
          highlightStyle: subtitleStyle.copyWith(
            fontWeight: FontWeight.w600,
            color: primaryColor,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: s.trailingWidget ??
            Icon(Icons.arrow_forward_ios,
                size: 14, color: theme.colorScheme.onSurfaceVariant),
        onTap: s.onTap,
      ),
    );
  }

  Widget _buildTransactionCard(
      BuildContext context, TransactionModel t, AppCardGroupPosition groupPosition) {
    final theme = Theme.of(context);
    final catColor = TransactionCategory.colorFor(t.category);
    final catIcon = TransactionCategory.iconFor(t.category);
    final primaryColor = theme.colorScheme.primary;
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
          fontFamily: AppTheme.fontGoogleSansFlex,
          fontFamilyFallback: AppTheme.fontFallbacks,
          fontWeight: FontWeight.w600,
          fontVariations: AppTheme.buildFontVariations(
            size: 14.0,
            brightness: theme.brightness,
            weight: 600,
          ),
        ) ??
        const TextStyle(fontSize: 14, fontWeight: FontWeight.w600);

    return AppCard(
      groupPosition: groupPosition,
      margin: const EdgeInsets.only(bottom: 2),
      padding: EdgeInsets.zero,
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: catColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(catIcon, color: catColor, size: 18),
        ),
        title: HighlightedText(
          text: t.description,
          query: widget.query,
          style: titleStyle,
          highlightStyle: titleStyle.copyWith(color: primaryColor),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          "${t.category} • ${DateFormat.yMMMd().format(t.date)}",
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13.0,
            color: theme.colorScheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        trailing: Text(
          "${t.isExpense ? '-' : '+'}${context.select<SettingsProvider, String>((s) => s.currencySymbol)} ${t.amount.toStringAsFixed(2)}",
          style: theme.textTheme.titleSmall?.copyWith(
            fontFamily: AppTheme.fontGoogleSansFlex,
            fontFamilyFallback: AppTheme.fontFallbacks,
            color: t.isExpense
                ? theme.colorScheme.error
                : (theme.extension<AppSemanticColors>()?.success ?? theme.colorScheme.primary),
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
            fontVariations: AppTheme.buildFontVariations(
              size: 14.0,
              brightness: theme.brightness,
              weight: 700,
            ),
          ),
        ),
        onTap: () {
          final settings = context.read<SettingsProvider>();
          if (ModuleLockGate.isModuleCurrentlyLocked(settings, 'finances')) {
            appTabNavigationRequest.value = 'finances';
            return;
          }
          AppRouter.push(context, TransactionEditorScreen(transaction: t)).then((_) {
            if (!mounted || !context.mounted) return;
            setState(() {
              _updateSearchFuture();
            });
            context.read<FinancialManagerProvider?>()?.loadTransactions();
          });
        },
      ),
    );
  }

  Widget _buildPeriodLogCard(
      BuildContext context, PeriodLog log, AppCardGroupPosition groupPosition) {
    final theme = Theme.of(context);
    final healthColor = theme.colorScheme.error;
    final primaryColor = theme.colorScheme.primary;
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
          fontFamily: AppTheme.fontGoogleSansFlex,
          fontFamilyFallback: AppTheme.fontFallbacks,
          fontWeight: FontWeight.w600,
          fontVariations: AppTheme.buildFontVariations(
            size: 14.0,
            brightness: theme.brightness,
            weight: 600,
          ),
        ) ??
        const TextStyle(fontSize: 14, fontWeight: FontWeight.w600);

    return AppCard(
      groupPosition: groupPosition,
      margin: const EdgeInsets.only(bottom: 2),
      padding: EdgeInsets.zero,
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: healthColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.water_drop_outlined, color: healthColor, size: 18),
        ),
        title: HighlightedText(
          text: "Period Log: ${log.intensity}",
          query: widget.query,
          style: titleStyle,
          highlightStyle: titleStyle.copyWith(color: primaryColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          "Started: ${DateFormat.yMMMd().format(log.startDate)}",
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 13.0,
            color: theme.colorScheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        onTap: () {
          final settings = context.read<SettingsProvider>();
          if (ModuleLockGate.isModuleCurrentlyLocked(settings, 'health')) {
            appTabNavigationRequest.value = 'health';
            return;
          }
          AppRouter.push(context, const PeriodTrackerScreen());
        },
      ),
    );
  }

  Widget _buildNoteCard(
      BuildContext context, Note note, AppCardGroupPosition groupPosition) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
          fontFamily: AppTheme.fontGoogleSansFlex,
          fontFamilyFallback: AppTheme.fontFallbacks,
          fontWeight: FontWeight.w600,
          fontVariations: AppTheme.buildFontVariations(
            size: 14.0,
            brightness: theme.brightness,
            weight: 600,
          ),
        ) ??
        const TextStyle(fontWeight: FontWeight.w600, fontSize: 14);
    final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(
          fontSize: 13.0,
          color: theme.colorScheme.onSurfaceVariant,
        ) ??
        TextStyle(fontSize: 13.0, color: theme.colorScheme.onSurfaceVariant);

    return AppCard(
      groupPosition: groupPosition,
      margin: const EdgeInsets.only(bottom: 2),
      padding: EdgeInsets.zero,
      backgroundColor: theme.colorScheme.surfaceContainerLow,
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: note.isLocked
                ? theme.colorScheme.error.withValues(alpha: 0.15)
                : primaryColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
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
          style: titleStyle,
          highlightStyle: titleStyle.copyWith(color: primaryColor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: note.isLocked
            ? Text(
                'Locked note (tap to unlock)',
                style: subtitleStyle.copyWith(fontStyle: FontStyle.italic),
              )
            : HighlightedText(
                text: note.previewText ?? '',
                query: widget.query,
                style: subtitleStyle,
                highlightStyle: subtitleStyle.copyWith(
                  fontWeight: FontWeight.w600,
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
          AppRouter.push(context, NoteEditorScreen(note: note)).then((_) {
            if (context.mounted) {
              context.read<NoteProvider>().refreshNotes();
            }
          });
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:note_taking_app/features/finances/data/transaction_repository.dart';
import 'package:note_taking_app/data/sms_contact.dart';
import 'package:note_taking_app/services/sms_service.dart';
import 'package:note_taking_app/core/theme/app_layout.dart';
import 'package:note_taking_app/core/ui/expressive_sliver_app_bar.dart';

class SmsContactsScreen extends StatefulWidget {
  const SmsContactsScreen({super.key});

  @override
  State<SmsContactsScreen> createState() => _SmsContactsScreenState();
}

class _SmsContactsScreenState extends State<SmsContactsScreen> {
  List<SmsContact> _contacts = [];
  bool _loading = true;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final contacts = await TransactionRepository.instance.getAllSmsContacts();
    if (mounted) {
      setState(() {
        _contacts = contacts;
        _loading = false;
      });
    }
  }

  Future<void> _addCustomSender() async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    final id = value.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
    await TransactionRepository.instance.upsertSmsContact(SmsContact(
      id: 'custom_$id',
      senderIds: [value],
      label: value,
    ));
    await SmsService.reloadSmsContacts();
    _controller.clear();
    await _load();
  }

  Future<void> _toggleBlocked(SmsContact contact) async {
    await TransactionRepository.instance
        .setSmsContactBlocked(contact.id, !contact.isBlocked);
    await SmsService.reloadSmsContacts();
    await _load();
  }

  Future<void> _deleteCustom(SmsContact contact) async {
    await TransactionRepository.instance.deleteSmsContact(contact.id);
    await SmsService.reloadSmsContacts();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final banks = _contacts.where((c) => c.isBuiltIn).toList();
    final custom = _contacts.where((c) => !c.isBuiltIn).toList();

    final items = <Widget>[
      // ── Info banner ──────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Card(
          color: cs.secondaryContainer,
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: cs.onSecondaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Manage which SMS senders are imported as '
                    'transactions. Toggle the switch to block a '
                    'sender. Add custom sender IDs for non-bank '
                    'services (e.g. KOKO, FriMi).',
                    style:
                        tt.bodySmall?.copyWith(color: cs.onSecondaryContainer),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // ── Add custom sender row ────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'Sender ID (e.g. KOKO)',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  isDense: true,
                ),
                onSubmitted: (_) => _addCustomSender(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _addCustomSender,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
      ),

      const SizedBox(height: 16),

      // ── Banks section ────────────────────────────────────────
      if (banks.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text('Banks',
              style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
        ),
        ...banks.map((c) => _contactTile(cs, tt, c, canDelete: false)),
        const SizedBox(height: 16),
      ],

      // ── Custom senders section ──────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Text('Custom Senders',
            style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
      ),
      if (custom.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.sms_outlined,
                    size: 40,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                const SizedBox(height: 8),
                Text('No custom senders yet',
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        )
      else
        ...custom.map((c) => _contactTile(cs, tt, c, canDelete: true)),

      const SizedBox(height: 32),
    ];

    return Scaffold(
      body: AnimationLimiter(
        child: CustomScrollView(
          slivers: [
            const ExpressiveSliverAppBar(
              titleText: 'Financial Senders',
              showBackButton: true,
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator.adaptive()),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    return AnimationConfiguration.staggeredList(
                      position: i.clamp(0, 8),
                      duration: AppLayout.animShort,
                      child: SlideAnimation(
                        verticalOffset: AppLayout.shouldReduceMotion(context) ? 0.0 : 16.0,
                        child: FadeInAnimation(child: items[i]),
                      ),
                    );
                  },
                  childCount: items.length,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _contactTile(ColorScheme cs, TextTheme tt, SmsContact contact,
      {required bool canDelete}) {
    final blocked = contact.isBlocked;
    final label = contact.label ?? contact.id;
    final subtitle = contact.senderIds.join(', ');
    final avatarColor = blocked ? cs.error : cs.primary;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppLayout.radiusL),
        side: BorderSide(
          color: cs.outlineVariant.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: avatarColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: avatarColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(
            blocked ? Icons.block : Icons.message_outlined,
            color: avatarColor,
            size: 20,
          ),
        ),
        title: Text(
          label,
          style: tt.bodyMedium?.copyWith(
            decoration: blocked ? TextDecoration.lineThrough : null,
            color: blocked ? cs.onSurfaceVariant : null,
          ),
        ),
        subtitle: Text(subtitle,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch.adaptive(
              value: !blocked,
              onChanged: (_) => _toggleBlocked(contact),
              activeTrackColor: cs.primary,
            ),
            if (canDelete)
              IconButton(
                icon: Icon(Icons.delete_outline, color: cs.error),
                tooltip: 'Remove',
                onPressed: () => _confirmDelete(contact),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(SmsContact contact) {
    showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Remove sender?'),
        content:
            Text('SMS from "${contact.label ?? contact.id}" will no longer be '
                'auto-imported as transactions.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true) _deleteCustom(contact);
    });
  }
}

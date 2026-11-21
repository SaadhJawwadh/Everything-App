import '../data/models/split_bill_model.dart';

class SimplifiedTransfer {
  final String from;
  final String to;
  final double amount;

  const SimplifiedTransfer({
    required this.from,
    required this.to,
    required this.amount,
  });
}

/// Pure-Dart, integer-cent greedy min-cash-flow debt simplifier for grouped
/// split bills. Read-only and shareable (never mutates ledger or bill rows).
class DebtSimplifierService {
  const DebtSimplifierService._();

  /// Computes the minimal list of transfers needed to settle all unpaid balances
  /// across [groupBills].
  static List<SimplifiedTransfer> simplifyGroupDebts(List<SplitBillModel> groupBills) {
    final Map<String, int> netCents = {};
    final Map<String, String> displayNames = {'you': 'You'};

    String canonicalKey(String raw) {
      final trimmed = raw.trim();
      final lower = trimmed.toLowerCase();
      if (lower == 'you') return 'you';
      displayNames.putIfAbsent(lower, () => trimmed);
      return lower;
    }

    for (final bill in groupBills) {
      if (bill.deletedAt != null) continue;

      final payerKey = bill.isPayerUser ? 'you' : canonicalKey(bill.payerName);

      // Track whether 'you' was explicitly covered in participants on friend-paid bills
      bool sawUserParticipant = false;

      for (final p in bill.participants) {
        final pKey = canonicalKey(p.contactName);
        if (pKey == 'you') sawUserParticipant = true;
        if (p.hasPaid || pKey == payerKey) continue;

        final shareCents = (p.shareAmount * 100).round();
        if (shareCents <= 0) continue;

        netCents[payerKey] = (netCents[payerKey] ?? 0) + shareCents;
        netCents[pKey] = (netCents[pKey] ?? 0) - shareCents;
      }

      // Legacy / imported friend-paid bills may omit 'You' from participants
      if (!bill.isPayerUser && !sawUserParticipant && !bill.isUserSharePaid) {
        final userCents = (bill.userShare * 100).round();
        if (userCents > 0) {
          netCents[payerKey] = (netCents[payerKey] ?? 0) + userCents;
          netCents['you'] = (netCents['you'] ?? 0) - userCents;
        }
      }
    }

    final creditors = <MapEntry<String, int>>[];
    final debtors = <MapEntry<String, int>>[];

    netCents.forEach((key, cents) {
      if (cents > 0) {
        creditors.add(MapEntry(key, cents));
      } else if (cents < 0) {
        debtors.add(MapEntry(key, -cents));
      }
    });

    creditors.sort((a, b) => b.value.compareTo(a.value));
    debtors.sort((a, b) => b.value.compareTo(a.value));

    final transfers = <SimplifiedTransfer>[];
    int cIdx = 0;
    int dIdx = 0;

    while (cIdx < creditors.length && dIdx < debtors.length) {
      final cred = creditors[cIdx];
      final debt = debtors[dIdx];
      final settledCents = cred.value < debt.value ? cred.value : debt.value;

      if (settledCents > 0) {
        transfers.add(
          SimplifiedTransfer(
            from: displayNames[debt.key] ?? debt.key,
            to: displayNames[cred.key] ?? cred.key,
            amount: settledCents / 100.0,
          ),
        );
      }

      final remCred = cred.value - settledCents;
      final remDebt = debt.value - settledCents;
      creditors[cIdx] = MapEntry(cred.key, remCred);
      debtors[dIdx] = MapEntry(debt.key, remDebt);

      if (remCred == 0) cIdx++;
      if (remDebt == 0) dIdx++;
    }

    return transfers;
  }
}

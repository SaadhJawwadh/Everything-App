import '../data/transaction_model.dart';
import '../data/transaction_category.dart';
import '../data/category_constants.dart';
import '../data/custom_sms_rule.dart';
import 'sms_constants.dart';

class SmsParser {
  /// Safely parses a raw numerical amount string supporting both standard
  /// Anglo-American formats ("1,500.50", "1500.50") and European/Russian
  /// formats ("1 500,50", "1.500,50", "1500,50").
  static double? parseAmountString(String raw) {
    var cleaned = raw.replaceAll(' ', '').trim();
    if (cleaned.isEmpty) return null;

    // Both comma and dot present: determine which is decimal by last occurrence
    if (cleaned.contains(',') && cleaned.contains('.')) {
      if (cleaned.lastIndexOf(',') > cleaned.lastIndexOf('.')) {
        // e.g. 1.500,50 -> dot is thousands, comma is decimal
        cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // e.g. 1,500.50 -> comma is thousands, dot is decimal
        cleaned = cleaned.replaceAll(',', '');
      }
    } else if (cleaned.contains(',')) {
      // Only comma present: check if it's a decimal separator (followed by 1 or 2 digits at the end)
      // e.g. "1500,50" or "15,5" vs "1,500" or "1,500,000"
      final commaDecimalRegex = RegExp(r',\d{1,2}$');
      if (commaDecimalRegex.hasMatch(cleaned)) {
        cleaned = cleaned.replaceAll(',', '.');
      } else {
        cleaned = cleaned.replaceAll(',', '');
      }
    }
    return double.tryParse(cleaned);
  }

  static bool isPotentiallyRelevant({
    required String body,
    required String address,
    required Set<String> allowedSenderIds,
    required Set<String> blockedSenderIds,
    String? preferredCurrency,
    List<CustomSmsRule>? customSmsRules,
  }) {
    if (body.trim().isEmpty) return false;

    // Cancellation check
    final isReversal = SmsConstants.reversalRegex.hasMatch(body);
    final isCancellation = SmsConstants.cancellationRegex.hasMatch(body);
    if (isCancellation && !isReversal) return false;

    // Blocked sender check
    final senderLower = address.toLowerCase();
    if (blockedSenderIds.any((s) => senderLower.contains(s))) return false;

    final bodyLower = body.toLowerCase();
    final matchingRule = customSmsRules?.cast<CustomSmsRule?>().firstWhere(
      (r) => r != null && r.isEnabled && bodyLower.contains(r.keyword.toLowerCase()),
      orElse: () => null,
    );

    // Reject OTP/verification messages unless explicitly bypassed by a custom rule
    if (SmsConstants.otpRegex.hasMatch(body)) {
      if (matchingRule == null || !matchingRule.bypassOtpFilter) {
        return false;
      }
    }

    // Reject promotional SMS unless explicit executed transaction terms exist
    final isPromotional = SmsConstants.promotionalRegex.hasMatch(body);
    final hasExecuted = SmsConstants.executedTransactionRegex.hasMatch(body);
    if (isPromotional && !hasExecuted && matchingRule == null) return false;

    // Check if it has a valid amount match (checking preferred currency, general currencies, or bare amount)
    var cleanBody = body.replaceAll(SmsConstants.piiBalanceRegex, '');
    final hasPreferred = preferredCurrency != null &&
        preferredCurrency.trim().isNotEmpty &&
        SmsConstants.buildPreferredAmountRegex(preferredCurrency).hasMatch(cleanBody);
    final hasAmount = hasPreferred ||
        SmsConstants.amountRegex.hasMatch(cleanBody) ||
        SmsConstants.bareAmountRegex.hasMatch(cleanBody);
    if (!hasAmount) return false;

    // Check if known sender, or matches transaction action terms
    final isBank = SmsConstants.bankSenders.any((s) => address.toUpperCase().contains(s.toUpperCase())) ||
        address.toUpperCase().contains('BANK') ||
        address.toUpperCase().contains('ALERT') ||
        address.toUpperCase().contains('CARD') ||
        address == 'TEST' ||
        address == 'BANK_SMS';
    final isKnownSender = isBank ||
        allowedSenderIds.any((s) => senderLower.contains(s)) ||
        matchingRule != null;
    
    final hasTransactionAction = SmsConstants.debitRegex.hasMatch(body) || 
                                 SmsConstants.creditRegex.hasMatch(body) ||
                                 SmsConstants.transferRegex.hasMatch(body) ||
                                 SmsConstants.depositRegex.hasMatch(body) ||
                                 SmsConstants.purchaseRegex.hasMatch(body) ||
                                 matchingRule != null;

    return isKnownSender || hasTransactionAction;
  }

  static TransactionModel? parseMessage({
    required String body,
    required String address,
    required int? messageId,
    required int? messageDate,
    required Set<String> allowedSenderIds,
    required Set<String> blockedSenderIds,
    required List<String> customExpenseRules,
    required List<String> customIncomeRules,
    List<CustomSmsRule>? customSmsRules,
    String? preferredCurrency,
    Map<String, String>? categoryAccountRouting,
  }) {
    if (body.trim().isEmpty) return null;

    final isReversal = SmsConstants.reversalRegex.hasMatch(body);
    final senderLower = address.toLowerCase().trim();
    final bodyLower = body.toLowerCase();

    // Check custom taught rules first (takes precedence)
    CustomSmsRule? matchingRule;
    if (customSmsRules != null && customSmsRules.isNotEmpty) {
      for (final rule in customSmsRules) {
        if (rule.isEnabled && rule.keyword.trim().isNotEmpty) {
          if (bodyLower.contains(rule.keyword.trim().toLowerCase())) {
            matchingRule = rule;
            break;
          }
        }
      }
    }

    if (blockedSenderIds.contains(senderLower)) return null;

    // Guardrail: Reject standard OTP / 2FA / Authorization messages
    // UNLESS the matching custom rule explicitly has bypassOtpFilter: true
    if (SmsConstants.otpRegex.hasMatch(body)) {
      if (matchingRule == null || !matchingRule.bypassOtpFilter) {
        return null;
      }
    }

    // Reject promotional SMS unless explicit executed transaction terms exist
    final isPromotional = SmsConstants.promotionalRegex.hasMatch(body);
    final hasExecuted = SmsConstants.executedTransactionRegex.hasMatch(body);
    if (isPromotional && !hasExecuted && matchingRule == null) return null;

    final matchesExpenseRule = (matchingRule != null && (matchingRule.type == RuleTransactionType.expense || matchingRule.type == RuleTransactionType.transfer)) ||
        customExpenseRules.any((r) => bodyLower.contains(r.toLowerCase()));
    final matchesIncomeRule = (matchingRule != null && matchingRule.type == RuleTransactionType.income) ||
        customIncomeRules.any((r) => bodyLower.contains(r.toLowerCase()));

    final isBank = SmsConstants.bankSenders.any((s) => address.toUpperCase().contains(s.toUpperCase())) ||
        address.toUpperCase().contains('BANK') ||
        address.toUpperCase().contains('ALERT') ||
        address.toUpperCase().contains('CARD') ||
        address == 'TEST' ||
        address == 'BANK_SMS';
    final isKnownSender = isBank ||
        allowedSenderIds.any((s) => senderLower.contains(s)) ||
        matchingRule != null;
    
    final isInwardTransfer = SmsConstants.inwardTransferRegex.hasMatch(body);
    final isExplicitCredit = SmsConstants.creditRegex.hasMatch(body) || SmsConstants.depositRegex.hasMatch(body);
    final isSelfTransfer = SmsConstants.selfTransferRegex.hasMatch(body) || (matchingRule != null && matchingRule.type == RuleTransactionType.transfer);

    final isCredit = matchesIncomeRule || (!matchesExpenseRule && (isInwardTransfer || isExplicitCredit));
    final isDebit = matchesExpenseRule || (!isCredit && isBank && SmsConstants.debitRegex.hasMatch(body));
    final hasInstalment = isBank && SmsConstants.instalmentRegex.hasMatch(body);
    final isTransfer = isBank && SmsConstants.transferRegex.hasMatch(body);

    if (!isKnownSender && !isDebit && !isCredit && !hasInstalment && !isTransfer) return null;

    if (SmsConstants.dueReminderRegex.hasMatch(body) && !isDebit && !isCredit) return null;

    double? amount;
    // Strip balance strings to prevent balance amount from being captured instead of transaction amount
    final amountSearchBody = body.replaceAll(SmsConstants.piiBalanceRegex, '');

    // 1. Try preferred currency specific pattern first if available
    if (preferredCurrency != null && preferredCurrency.trim().isNotEmpty) {
      final preferredRegex = SmsConstants.buildPreferredAmountRegex(preferredCurrency);
      final preferredMatch = preferredRegex.firstMatch(amountSearchBody) ?? preferredRegex.firstMatch(body);
      if (preferredMatch != null) {
        final raw = preferredMatch.group(1) ?? preferredMatch.group(2);
        if (raw != null) {
          amount = parseAmountString(raw);
        }
      }
    }

    // 2. Try general multi-currency amount regex
    if (amount == null) {
      final amountMatch = SmsConstants.amountRegex.firstMatch(amountSearchBody) ?? SmsConstants.amountRegex.firstMatch(body);
      if (amountMatch != null) {
        final raw = amountMatch.group(1) ?? amountMatch.group(2);
        if (raw != null) {
          amount = parseAmountString(raw);
        }
      }
    }

    // 3. Fallback to bare amount regex ("of 1,500.00")
    if (amount == null) {
      final bareMatch = SmsConstants.bareAmountRegex.firstMatch(amountSearchBody) ?? SmsConstants.bareAmountRegex.firstMatch(body);
      if (bareMatch != null) {
        amount = parseAmountString(bareMatch.group(1)!);
      }
    }
    if (amount == null || amount <= 0) return null;

    if (!isReversal && !isDebit && !isCredit && !hasInstalment && !isTransfer) return null;

    final isExpense = !isCredit && !isReversal;

    // Use custom description if specified by user-taught rule
    final String description;
    if (matchingRule != null && matchingRule.customDescription != null && matchingRule.customDescription!.trim().isNotEmpty) {
      description = matchingRule.customDescription!.trim();
    } else {
      description = buildDescription(body, address, amount, isExpense: isExpense);
    }

    final String category;
    if (isReversal) {
      category = SmsConstants.reversalSentinel;
    } else if (matchingRule != null && matchingRule.category != null && matchingRule.category!.trim().isNotEmpty) {
      category = matchingRule.category!.trim();
    } else if (isSelfTransfer || (matchingRule != null && matchingRule.type == RuleTransactionType.transfer)) {
      category = CategoryConstants.transfer;
    } else {
      category = TransactionCategory.fromDescriptionCached('$description $body');
    }

    final date = resolveMessageDate(messageDate);
    final normalizedBody = body.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final smsId = messageId != null
        ? '${messageId}_$messageDate'
        : 'hash_${address.toLowerCase()}_${normalizedBody.hashCode}_$messageDate';

    final account = resolveAccount(
      body: body,
      category: category,
      matchingRule: matchingRule,
      categoryAccountRouting: categoryAccountRouting,
    );

    return TransactionModel(
      amount: amount,
      description: description,
      date: date,
      isExpense: isExpense,
      category: category,
      smsId: smsId,
      account: account,
    );
  }

  /// Resolves the destination account ('daily' or 'savings') applying
  /// taught rule target account -> category routing -> keyword checks -> 'daily'.
  static String resolveAccount({
    required String body,
    required String category,
    CustomSmsRule? matchingRule,
    Map<String, String>? categoryAccountRouting,
  }) {
    if (matchingRule != null && matchingRule.targetAccount != null && matchingRule.targetAccount!.trim().isNotEmpty) {
      return matchingRule.targetAccount!.trim();
    }
    if (categoryAccountRouting != null && categoryAccountRouting.containsKey(category)) {
      return categoryAccountRouting[category]!;
    }
    final bodyLower = body.toLowerCase();
    final isSavings = bodyLower.contains('saving') ||
                      bodyLower.contains('fixed deposit') ||
                      bodyLower.contains('fd interest') ||
                      bodyLower.contains('vault');
    return isSavings ? AccountType.savings : AccountType.daily;
  }

  static String buildDescription(String body, String sender, double amount, {required bool isExpense}) {
    final amountLabel = formatAmount(amount);
    final bankName = getBankName(sender);

    var text = body;
    text = text.replaceAll(SmsConstants.urlRegex, '');
    text = text.replaceAll(SmsConstants.piiBalanceRegex, '');
    text = text.replaceAll(SmsConstants.piiCardRegex, '');
    text = text.replaceAll(SmsConstants.piiRefRegex, '');
    text = text.replaceAll(SmsConstants.piiDateTimePhoneRegex, '');
    text = text.replaceAll(SmsConstants.amountRegex, '');
    text = text.replaceAll(SmsConstants.bareAmountRegex, '');

    // Inward transfer / deposit from sender
    if (SmsConstants.inwardTransferRegex.hasMatch(body)) {
      final senderEntity = _extractEntity(body, r"\b(?:from|received\s+from|sent\s+by)\s+(?!(?:your|the|our|my|lkr|rs)\b)([A-Za-z][A-Za-z0-9\s&'\-\.]{1,30}?)(?=\s*(?:[,.\n]|$|\baccount\b|\ba\/c\b))");
      if (senderEntity != null) {
        return appendBankSuffix('Received from $senderEntity $amountLabel', bankName);
      }
      return appendBankSuffix('Transfer from Sender $amountLabel', bankName);
    }

    if (SmsConstants.depositRegex.hasMatch(body) || SmsConstants.creditRegex.hasMatch(body)) {
      if (bankName != null && !SmsConstants.creditRegex.hasMatch(body)) return 'Deposit of $amountLabel in $bankName';
      final branch = _extractEntity(text, r'\bthrough\s+([A-Za-z][A-Za-z0-9\s\-]{1,25}?)\s+(?:BR|branch)\b') ??
                    _extractEntity(text, r'\bat\s+([A-Za-z][A-Za-z0-9\s\-]{1,35}?)($|\n)');
      if (branch != null) {
        return SmsConstants.creditRegex.hasMatch(body) ? 'Credit of $amountLabel at $branch – ${bankName ?? "Bank"}' : 'Deposit of $amountLabel at $branch';
      }
      return SmsConstants.creditRegex.hasMatch(body) ? 'Credit of $amountLabel${bankName != null ? ' – $bankName' : ''}' : 'Deposit of $amountLabel';
    }

    if (SmsConstants.instalmentRegex.hasMatch(body)) {
      final provider = bankName ?? extractBodySender(body);
      final merchant = _extractEntity(body, r"\bfor\s+(?:your\s+)?([A-Za-z][A-Za-z0-9\s&'\-\.]{1,25}?)\s+(?:order|purchase|plan|account)\b");
      String desc;
      if (provider != null && merchant != null) {
        desc = '$provider Instalment $merchant';
      } else if (provider != null) {
        desc = '$provider Instalment $amountLabel';
      } else if (merchant != null) {
        desc = 'Instalment – $merchant $amountLabel';
      } else {
        desc = 'Instalment $amountLabel';
      }
      return appendBankSuffix(desc, bankName);
    }

    if (SmsConstants.withdrawalRegex.hasMatch(body)) return bankName != null ? 'Withdrawal of $amountLabel – $bankName' : 'ATM Withdrawal $amountLabel';

    if (SmsConstants.transferRegex.hasMatch(body)) {
      final recipient = _extractEntity(text, r"\bto\s+(?!(?:your|the|our|my)\b)([A-Za-z][A-Za-z0-9\s&'\-\.]{1,30}?)(?=\s*(?:[,.\n]|$|\baccount\b|\ba\/c\b))");
      return appendBankSuffix(recipient != null ? 'Transfer to $recipient $amountLabel' : 'Fund Transfer $amountLabel', bankName);
    }

    if (SmsConstants.purchaseRegex.hasMatch(body)) {
      final merchant = extractMerchant(text);
      return appendBankSuffix(merchant != null ? 'Purchase at $merchant $amountLabel' : 'Purchase $amountLabel', bankName);
    }

    final merchant = extractMerchant(text);
    if (merchant != null) return appendBankSuffix('${isExpense ? "Payment at" : "Received from"} $merchant $amountLabel', bankName);

    text = text.replaceAll(SmsConstants.debitRegex, '').replaceAll(SmsConstants.creditRegex, '').replaceAll(SmsConstants.noiseWordsRegex, '').replaceAll(RegExp(r"[^A-Za-z0-9\u0400-\u04FF\s&'\-]"), ' ').replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    if (text.length > 50) text = text.substring(0, 50).trim();
    final direction = isExpense ? 'Debit' : 'Credit';
    return appendBankSuffix(text.isNotEmpty ? '$direction – ${cleanTitle(text)} $amountLabel' : '$direction $amountLabel', bankName ?? sender);
  }

  static String? _extractEntity(String text, String pattern) {
    final m = RegExp(pattern, caseSensitive: false).firstMatch(text);
    return m != null ? cleanTitle(m.group(1)!.trim()) : null;
  }

  static String? extractMerchant(String text) {
    // 1. Check quoted merchant name: at "STARBUCKS" or for 'UBER'
    final quotedMatch = SmsConstants.quotedMerchantRegex.firstMatch(text);
    if (quotedMatch != null) {
      final candidate = quotedMatch.group(1)!.trim();
      if (candidate.length >= 2) return cleanTitle(candidate);
    }

    // 2. Check POS / ECOM merchant name: POS/UBER TRIP or POS 49201 STARBUCKS
    final posMatch = SmsConstants.posMerchantRegex.firstMatch(text);
    if (posMatch != null) {
      final candidate = posMatch.group(1)!.trim();
      if (candidate.length >= 2 && !candidate.toLowerCase().startsWith('ref')) return cleanTitle(candidate);
    }

    // 3. Check UPI / VPA handle: to coffee@hdfc
    final vpaMatch = SmsConstants.vpaMerchantRegex.firstMatch(text);
    if (vpaMatch != null) {
      final handle = vpaMatch.group(1)!.trim().replaceAll('.', ' ').replaceAll('_', ' ').replaceAll('-', ' ');
      if (handle.length >= 2) return cleanTitle(handle);
    }

    // 4. Standard prefix search: at / for / from
    const terminators = r"(?=\s*(?:[,.\n]|$|\bref\b|\bauth\b|\bavl\b|\bbal\b|\bon\b|\bvia\b|\bif\b|\bfor\b|\bhas\b|\bto\b))";
    for (final prefix in ['at', 'for', 'from']) {
      final m = RegExp(r"\b" + prefix + r"\s+(?!(?:your|the|our|my|lkr|rs|inr|usd|eur|gbp|aed|sar)\b)([A-Za-z][A-Za-z0-9\s&'\-\.]{1,60}?)" + terminators, caseSensitive: false).firstMatch(text);
      if (m != null) {
        var candidate = m.group(1)!.trim()
            .replaceAll(RegExp(r'\b0\d{9}\b|\b\d{10,11}\b'), '')
            .replaceAll(RegExp(r'\b(?:COLOMBO\s*\d*|LK|SRI\s*LANKA)\b', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s{2,}'), ' ')
            .trim();
        if (candidate.length >= 2) return cleanTitle(candidate);
      }
    }
    return null;
  }

  static String? extractBodySender(String body) {
    final m = RegExp(r'^\s*\(?[Ff]rom\s+([A-Za-z][A-Za-z0-9\s]{1,20}?)\)?[\s,]').firstMatch(body);
    if (m != null) return cleanTitle(m.group(1)!.trim());
    for (final entry in SmsConstants.senderToBankName.entries) {
      if (body.contains(entry.key)) return entry.value;
    }
    return null;
  }

  static String? getBankName(String sender) {
    for (final entry in SmsConstants.senderToBankName.entries) {
      if (sender.contains(entry.key)) return entry.value;
    }
    return null;
  }

  static String formatAmount(double amount) {
    final s = amount == amount.truncateToDouble() ? amount.toInt().toString() : amount.toStringAsFixed(2);
    final parts = s.split('.');
    final intPart = parts[0];
    final buffer = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write(',');
      buffer.write(intPart[i]);
    }
    if (parts.length > 1) buffer..write('.')..write(parts[1]);
    return buffer.toString();
  }

  static String cleanTitle(String s) => s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).map((w) => (w.length <= 3 && w == w.toUpperCase() && RegExp(r'^[A-Z]+$').hasMatch(w)) ? w : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}').join(' ');

  static String appendBankSuffix(String desc, String? bankName) => (bankName == null || desc.contains(bankName)) ? desc : '$desc – $bankName';

  /// Resolves the authentic transaction timestamp from the SMS epoch timestamp.
  /// Handles both 13-digit millisecond and 10-digit second epoch values safely.
  static DateTime resolveMessageDate(int? messageDate) {
    if (messageDate == null || messageDate <= 0) return DateTime.now();
    if (messageDate < 10000000000) {
      return DateTime.fromMillisecondsSinceEpoch(messageDate * 1000);
    }
    return DateTime.fromMillisecondsSinceEpoch(messageDate);
  }
}

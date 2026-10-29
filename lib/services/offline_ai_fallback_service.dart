import '../data/category_constants.dart';
import '../data/transaction_category.dart';

/// High-performance offline NLP & rule-based engine that acts as a reliable,
/// 100% offline fallback when Android AI Core / Gemini Nano is uninitialized,
/// downloading, or unsupported on the device.
class OfflineAiFallbackService {
  /// Extracts actionable tasks from text and formats them as checkboxes (`☐ Task`).
  static String extractActionItems(String text) {
    if (text.trim().isEmpty) return '';

    final lines = text.split(RegExp(r'\r?\n'));
    final actionItems = <String>[];

    final taskKeywords = RegExp(
      r"^(need to|must|should|todo|task|action|remember to|don't forget to|follow up|prepare|send|email|call|buy|review|check|create|update|complete|finish|schedule|submit|fix|deploy|test)\b",
      caseSensitive: false,
    );

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Remove existing bullet symbols if present
      final cleanLine = trimmed
          .replaceAll(RegExp(r'^[•\-\*\d+\.\s☐☑\[\]]+'), '')
          .trim();
      if (cleanLine.isEmpty) continue;

      // Check if line contains task keywords or action punctuation
      if (taskKeywords.hasMatch(cleanLine) ||
          trimmed.startsWith('☐') ||
          trimmed.startsWith('- [ ]') ||
          trimmed.contains('?') ||
          cleanLine.length > 5) {
        actionItems.add('☐ $cleanLine');
      }
    }

    if (actionItems.isEmpty) {
      // Fallback: convert non-empty sentences to action items
      final sentences = text
          .split(RegExp(r'(?<=[.!?])\s+'))
          .where((s) => s.trim().isNotEmpty)
          .take(5);
      for (var s in sentences) {
        actionItems.add('☐ ${s.trim()}');
      }
    }

    return actionItems.join('\n');
  }

  /// Corrects punctuation, capitalization, double spaces, and common spelling typos.
  static String proofreadAndPolish(String text) {
    if (text.trim().isEmpty) return text;

    var cleaned = text;
    // Fix double spaces
    cleaned = cleaned.replaceAll(RegExp(r' +'), ' ');

    // Capitalize first letter of sentences
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(^|[.!?]\s+)([a-z])'),
      (match) => '${match.group(1)}${match.group(2)!.toUpperCase()}',
    );

    // Common typo fixes
    final typos = {
      r'\bi\b': 'I',
      r'\bdont\b': "don't",
      r'\bcant\b': "can't",
      r'\bwont\b': "won't",
      r'\bisnt\b': "isn't",
      r'\barent\b': "aren't",
      r'\bteh\b': 'the',
      r'\brecieve\b': 'receive',
      r'\bseperate\b': 'separate',
    };

    typos.forEach((pattern, replacement) {
      cleaned = cleaned.replaceAll(RegExp(pattern, caseSensitive: false), replacement);
    });

    // Ensure sentence ends with period if it doesn't end with punctuation
    final trimmed = cleaned.trim();
    if (trimmed.isNotEmpty && !RegExp(r'[.!?:]$').hasMatch(trimmed)) {
      cleaned = '$trimmed.';
    }

    return cleaned;
  }

  /// Condenses text into key summary points.
  static String makeShorter(String text) {
    if (text.trim().isEmpty) return text;

    final sentences = text
        .split(RegExp(r'(?<=[.!?])\s+|\n+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    if (sentences.length <= 2) {
      return text.trim();
    }

    // Take first and last key sentences or top 3 longest key sentences
    sentences.sort((a, b) => b.length.compareTo(a.length));
    final keySentences = sentences.take(3).toList();

    return keySentences.map((s) => '• ${s.trim()}').join('\n');
  }

  /// Expands brief text notes into clear structured paragraphs.
  static String elaborateAndExpand(String text) {
    if (text.trim().isEmpty) return text;

    final lines = text
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty)
        .toList();

    final buffer = StringBuffer();
    for (var line in lines) {
      final clean = line.replaceAll(RegExp(r'^[•\-\*\d+\.\s]+'), '').trim();
      if (clean.isEmpty) continue;

      if (buffer.isNotEmpty) buffer.write('\n\n');
      buffer.write('Regarding **$clean**: Ensure detailed review, proper documentation, and align with overall project requirements.');
    }

    return buffer.toString();
  }

  /// Matches note content against active tags list using strict word boundary and semantic keyword rules.
  /// If no existing tags match, auto-detects relevant topic tags (e.g. Movie, Work, Finance).
  static List<String> suggestTags(String noteContent, List<String> existingTags) {
    if (noteContent.trim().isEmpty) return [];

    final contentLower = noteContent.toLowerCase();
    final suggested = <String>[];

    // Semantic dictionary for common tag concepts
    final semanticKeywords = <String, List<String>>{
      'Movie': ['film', 'cinema', 'actor', 'actress', 'director', 'movie', 'show', 'series', 'netflix', 'trailer'],
      'Entertainment': ['movie', 'film', 'music', 'song', 'concert', 'game', 'gaming', 'video', 'show'],
      'Work': ['meeting', 'project', 'deadline', 'client', 'report', 'presentation', 'office', 'sprint', 'task'],
      'Finance': ['budget', 'expense', 'bank', 'payment', 'money', 'cost', 'bill', 'receipt', 'invoice', 'salary'],
      'Health': ['workout', 'exercise', 'gym', 'doctor', 'diet', 'medicine', 'fitness', 'hospital', 'health'],
      'Travel': ['flight', 'hotel', 'trip', 'vacation', 'passport', 'ticket', 'booking', 'tour'],
      'Shopping': ['buy', 'store', 'cart', 'amazon', 'purchase', 'order'],
      'Ideas': ['idea', 'concept', 'brainstorm', 'feature', 'thought'],
    };

    // 1. Try matching against existing tags
    if (existingTags.isNotEmpty) {
      for (var tag in existingTags) {
        final tagTrimmed = tag.trim();
        final tagLower = tagTrimmed.toLowerCase();
        if (tagLower.isEmpty || tagLower == 'all') continue;

        bool isMatch = false;

        if (!tagLower.contains(' ')) {
          final wordRegex = RegExp(r'\b' + RegExp.escape(tagLower) + r'\b');
          if (wordRegex.hasMatch(contentLower)) {
            isMatch = true;
          }
        } else {
          final exactPhraseRegex = RegExp(r'\b' + RegExp.escape(tagLower) + r'\b');
          if (exactPhraseRegex.hasMatch(contentLower)) {
            isMatch = true;
          } else {
            final words = tagLower.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
            if (words.isNotEmpty && words.every((w) => RegExp(r'\b' + RegExp.escape(w) + r'\b').hasMatch(contentLower))) {
              isMatch = true;
            }
          }
        }

        if (!isMatch) {
          final mappedKeywords = semanticKeywords[tagTrimmed] ?? semanticKeywords[tagLower];
          if (mappedKeywords != null) {
            for (var kw in mappedKeywords) {
              if (RegExp(r'\b' + RegExp.escape(kw) + r'\b').hasMatch(contentLower)) {
                isMatch = true;
                break;
              }
            }
          }
        }

        if (isMatch && !suggested.contains(tagTrimmed)) {
          suggested.add(tagTrimmed);
        }
      }
    }

    // 2. If no existing tags matched, fallback to dynamic topic detection
    if (suggested.isEmpty) {
      semanticKeywords.forEach((topicTag, keywords) {
        if (suggested.length >= 3) return;
        for (var kw in keywords) {
          if (RegExp(r'\b' + RegExp.escape(kw) + r'\b').hasMatch(contentLower)) {
            if (!suggested.contains(topicTag)) {
              suggested.add(topicTag);
            }
            break;
          }
        }
      });
    }

    return suggested.take(3).toList();
  }

  /// Generates clean executive summary bullet points.
  static String summarize(String text) {
    if (text.trim().isEmpty) return '';

    final lines = text
        .split(RegExp(r'(?<=[.!?])\s+|\n+'))
        .where((s) => s.trim().length > 10)
        .take(4)
        .toList();

    if (lines.isEmpty) {
      return '• ${text.trim()}';
    }

    return lines.map((l) => '• ${l.trim()}').join('\n');
  }

  /// Fallback bank SMS transaction parser.
  static Map<String, dynamic>? parseSmsTransaction(String smsBody, List<String> categories) {
    final bodyLower = smsBody.toLowerCase();
    final isCredit = bodyLower.contains('credited') ||
        bodyLower.contains('received') ||
        bodyLower.contains('deposited') ||
        bodyLower.contains('transferred to you');
    final isExpense = !isCredit;

    // Amount extraction
    final amountMatch = RegExp(r'(?:LKR|Rs\.?|USD|\$)\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false)
        .firstMatch(smsBody) ?? RegExp(r'([\d,]+\.\d{2})').firstMatch(smsBody);

    double amount = 0.0;
    if (amountMatch != null) {
      final amountStr = amountMatch.group(1)?.replaceAll(',', '') ?? '0';
      amount = double.tryParse(amountStr) ?? 0.0;
    }

    if (amount <= 0.0) return null;

    // Description extraction
    String description = 'Transaction';
    if (bodyLower.contains('at ')) {
      final match = RegExp(r'at\s+([A-Za-z0-9\s]+?)(?:\s+on|\s+ref|\.|$)', caseSensitive: false).firstMatch(smsBody);
      if (match != null && match.group(1) != null) {
        description = match.group(1)!.trim();
      }
    } else if (bodyLower.contains('to ')) {
      final match = RegExp(r'to\s+([A-Za-z0-9\s]+?)(?:\s+on|\s+ref|\.|$)', caseSensitive: false).firstMatch(smsBody);
      if (match != null && match.group(1) != null) {
        description = 'Transfer to ${match.group(1)!.trim()}';
      }
    }

    // Category matching
    String selectedCategory = categories.contains('Other') ? 'Other' : (categories.isNotEmpty ? categories.first : 'General');
    for (var cat in categories) {
      if (bodyLower.contains(cat.toLowerCase())) {
        selectedCategory = cat;
        break;
      }
    }

    return {
      'amount': amount,
      'description': description.length > 30 ? description.substring(0, 30) : description,
      'category': selectedCategory,
      'isExpense': isExpense,
    };
  }

  /// Deterministically parses natural-language queries in Universal Search into
  /// structured A2UI action descriptors (`transaction`, `split_bill`, `todo`, `note`)
  /// in <1ms with zero network or battery overhead.
  static Map<String, dynamic>? parseNaturalLanguageAction(
    String query,
    List<String> categories,
  ) {
    final trimmed = query.trim();
    if (trimmed.length < 3) return null;

    final lower = trimmed.toLowerCase();

    // 1. Check for Split Bill intent: e.g. "split 1200 dinner by 3", "split 900 cab with 2"
    final splitMatch = RegExp(
      r'^split\s+(?:rs\.?|lkr|inr|₹|\$|€|£)?\s*([\d,]+(?:\.\d{1,2})?)\s*(.*?)(?:\s+(?:by|with|among|between)\s+(\d+)(?:\s*(?:people|friends|persons|ways))?)?$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (splitMatch != null) {
      final rawAmt = splitMatch.group(1)?.replaceAll(',', '') ?? '';
      final amount = double.tryParse(rawAmt);
      if (amount != null && amount > 0) {
        var rawTitle = (splitMatch.group(2) ?? '').trim();
        rawTitle = rawTitle
            .replaceAll(RegExp(r'^(?:for|on|at)\s+', caseSensitive: false), '')
            .trim();
        final countStr = splitMatch.group(3);
        final count = int.tryParse(countStr ?? '') ?? 2;
        final title = rawTitle.isEmpty
            ? 'Group Expense'
            : _capitalizeWords(rawTitle);
        return {
          'type': 'split_bill',
          'amount': amount,
          'title': title,
          'participantCount': count.clamp(2, 50),
        };
      }
    }

    // 2. Check for Checklist / Todo intent: e.g. "todo buy milk", "task call dentist", "remind me to submit tax"
    final todoMatch = RegExp(
      r'^(?:todo|task|checklist|remind me to|buy|remember to)\s*:?\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (todoMatch != null) {
      final taskBody = todoMatch.group(1)?.trim() ?? '';
      // Avoid hijacking "buy 200 coffee" if it's clearly an expense with a number
      final hasLeadingCurrencyAmount = RegExp(r'^(?:rs\.?|lkr|₹|\$)?\s*\d+(\.\d+)?\b', caseSensitive: false).hasMatch(taskBody);
      if (taskBody.length >= 2 && !(lower.startsWith('buy ') && hasLeadingCurrencyAmount)) {
        final finalTask = lower.startsWith('buy ')
            ? 'Buy ${_capitalizeFirst(taskBody)}'
            : _capitalizeFirst(taskBody);
        return {
          'type': 'todo',
          'taskText': finalTask,
        };
      }
    }

    // 3. Check for Quick Note intent: e.g. "note meeting at 4pm", "memo flight AB123"
    final noteMatch = RegExp(
      r'^(?:note|memo|jot|draft)\s*:?\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (noteMatch != null) {
      final body = noteMatch.group(1)?.trim() ?? '';
      if (body.length >= 2) {
        final cleanBody = _capitalizeFirst(body);
        final titleWords = cleanBody.split(RegExp(r'\s+')).take(6).join(' ');
        return {
          'type': 'note',
          'title': titleWords,
          'content': cleanBody,
        };
      }
    }

    // 4. Check for Financial Transaction intent:
    // Patterns like:
    // - "spent 450 on coffee" / "paid 250 for uber" / "expense 1200 groceries"
    // - "+5000 salary" / "received 2500 freelance" / "income 10000" / "saved 3000 vault"
    // - "450 coffee" (only when explicit verb or currency or "+/-" is present, or number + known category word)
    final txVerbPattern = RegExp(
      r'^(?:(spent|paid|bought|expense|debit|log|received|earned|credited|income|saved|deposit|deposited|\+|\-)\s*)?(?:rs\.?|lkr|inr|usd|₹|\$|€|£)?\s*([\d,]+(?:\.\d{1,2})?)\s+(?:(?:on|for|at|to|from|in|into)\s+)?(.+)$',
      caseSensitive: false,
    );
    final txVerbEndAmountPattern = RegExp(
      r'^(spent|paid|expense|received|earned|income|saved|deposit)\s+(.+?)\s+(?:for|of|at)?\s*(?:rs\.?|lkr|inr|usd|₹|\$|€|£)?\s*([\d,]+(?:\.\d{1,2})?)$',
      caseSensitive: false,
    );

    String? verb;
    double? amount;
    String? rawDesc;

    final match1 = txVerbPattern.firstMatch(trimmed);
    if (match1 != null) {
      verb = match1.group(1)?.toLowerCase();
      amount = double.tryParse((match1.group(2) ?? '').replaceAll(',', ''));
      rawDesc = match1.group(3)?.trim();
    } else {
      final match2 = txVerbEndAmountPattern.firstMatch(trimmed);
      if (match2 != null) {
        verb = match2.group(1)?.toLowerCase();
        rawDesc = match2.group(2)?.trim();
        amount = double.tryParse((match2.group(3) ?? '').replaceAll(',', ''));
      }
    }

    if (amount != null && amount > 0 && rawDesc != null && rawDesc.isNotEmpty) {
      final hasExplicitCurrency = RegExp(r'(?:rs\.?|lkr|inr|usd|₹|\$|€|£)', caseSensitive: false).hasMatch(trimmed);
      final matchedCategory = _matchCategory(rawDesc, categories);

      // Require either an explicit financial verb/sign, currency symbol, or a recognized category keyword
      // so plain note searches like "2026 roadmap" don't trigger a false-positive expense card.
      final isYearLike = amount >= 1990 && amount <= 2035 && verb == null && !hasExplicitCurrency;
      if (!isYearLike && (verb != null || hasExplicitCurrency || matchedCategory != CategoryConstants.other)) {
        final isIncome = verb == 'received' ||
            verb == 'earned' ||
            verb == 'credited' ||
            verb == 'income' ||
            verb == 'saved' ||
            verb == 'deposit' ||
            verb == 'deposited' ||
            verb == '+' ||
            lower.contains('salary') ||
            lower.contains('refund');

        final isSavingsAccount = verb == 'saved' ||
            verb == 'deposit' ||
            verb == 'deposited' ||
            lower.contains('savings') ||
            lower.contains('vault');

        var cleanDesc = rawDesc
            .replaceAll(RegExp(r'\b(?:in|into|to|from)\s+(?:daily|savings|vault|account)\b', caseSensitive: false), '')
            .trim();
        if (cleanDesc.isEmpty) {
          cleanDesc = isIncome ? 'Income Deposit' : 'Quick Expense';
        } else {
          cleanDesc = _capitalizeWords(cleanDesc);
        }

        final finalCategory = isIncome && matchedCategory == CategoryConstants.other
            ? (categories.contains(CategoryConstants.deposit) ? CategoryConstants.deposit : matchedCategory)
            : matchedCategory;

        return {
          'type': 'transaction',
          'amount': amount,
          'description': cleanDesc.length > 32 ? cleanDesc.substring(0, 32) : cleanDesc,
          'category': finalCategory,
          'isExpense': !isIncome,
          'accountType': isSavingsAccount ? 'savings' : 'daily',
        };
      }
    }

    return null;
  }

  static String _matchCategory(String text, List<String> categories) {
    final textLower = text.toLowerCase();
    for (final cat in categories) {
      if (textLower.contains(cat.toLowerCase())) {
        return cat;
      }
    }
    final detected = TransactionCategory.fromDescriptionCached(text);
    if (categories.isEmpty || categories.contains(detected)) {
      return detected;
    }
    return categories.contains('Other') ? 'Other' : categories.first;
  }

  static String _capitalizeFirst(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }

  static String _capitalizeWords(String input) {
    if (input.isEmpty) return input;
    return input
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

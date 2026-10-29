import 'dart:convert';
import 'package:gemini_nano_android/gemini_nano_android.dart';
import 'local_ai_service.dart';
import 'offline_ai_fallback_service.dart';

class GeminiNanoService implements LocalAiService {
  final GeminiNanoAndroid _gemini = GeminiNanoAndroid();
  bool? _cachedSupport;

  @override
  Future<bool> isSupported() async {
    if (_cachedSupport != null) return _cachedSupport!;
    try {
      _cachedSupport = await _gemini.isAvailable();
    } catch (_) {
      _cachedSupport = false;
    }
    return _cachedSupport!;
  }

  @override
  Future<String?> generateText(String prompt) async {
    if (!await isSupported()) return null;
    try {
      final results = await _gemini.generate(
        prompt: prompt,
        temperature: 0.3, // Lower temperature for more analytical/accurate responses
      );
      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<String?> summarize(String text) async {
    final prompt = """
Summarize the following text concisely using a few bullet points. 
If the text is in Tamil, write the summary in Tamil. Otherwise, write the summary in English.
Keep it clear and readable.

Text:
$text
""";
    final result = await generateText(prompt);
    if (result != null && result.trim().isNotEmpty) {
      return result;
    }
    return OfflineAiFallbackService.summarize(text);
  }

  @override
  Future<List<String>> suggestTags(String noteContent, List<String> existingTags) async {
    final existingTagsList = existingTags.join(', ');
    final prompt = """
You are an intelligent tagging assistant. Analyze the note content below and select 1 to 3 relevant tags from the provided existing tags list.

STRICT GUARDRAILS:
1. ONLY select tags that exist in this exact list: [$existingTagsList].
2. The selected tag MUST represent the main topic of the note.
3. Do NOT match tags based on random word prefixes or common English words (for example, do NOT match "Event Summary" just because the word "even" appears).
4. If no tags in the list match the topic with high confidence, respond with nothing.
5. Respond with ONLY a comma-separated list of selected tag names.

Note content:
$noteContent
""";

    final response = await generateText(prompt);
    if (response != null && response.trim().isNotEmpty) {
      final cleanedTags = response
          .split(',')
          .map((tag) => tag.trim().toLowerCase().replaceAll('#', ''))
          .map((tag) => tag.replaceAll(RegExp(r'[^a-z0-9_-]'), ''))
          .where((tag) => tag.length >= 2 && tag != 'all')
          .toList();

      final result = <String>[];
      for (final tag in cleanedTags) {
        final matchedExisting = existingTags.firstWhere(
          (existing) => existing.trim().toLowerCase() == tag,
          orElse: () => '',
        );
        if (matchedExisting.isNotEmpty) {
          result.add(matchedExisting.trim());
        }
      }
      if (result.isNotEmpty) return result;
    }

    return OfflineAiFallbackService.suggestTags(noteContent, existingTags);
  }

  @override
  Future<Map<String, dynamic>?> parseSmsTransaction(String smsBody, List<String> categories) async {
    final categoriesStr = categories.map((c) => '"$c"').join(', ');
    final prompt = """
Analyze the following bank SMS and extract the transaction details.
Respond with ONLY a raw JSON object with keys:
"amount" (decimal number/float, without currency symbol or commas, e.g., 1500.50),
"description" (string, a refined, clean, and professional description of the transaction, max 30 chars. Extract the actual merchant name, utility provider, or peer-to-peer transfer details like "Transfer to [Name]" or "Received from [Name]". For ATM withdrawals, use "ATM Withdrawal"),
"category" (string, MUST be exactly one of these values: [$categoriesStr]. Select the category that best matches the transaction description or purpose),
"isExpense" (boolean, true if debited/spent/withdrawn/transferred out or for all bank digital transfers like "Digital-Transfer", false ONLY if credited/received/deposited).

No formatting, no markdown code block (like ```json), no other text. Just the JSON object.

SMS body:
$smsBody
""";

    final response = await generateText(prompt);
    if (response != null && response.trim().isNotEmpty) {
      try {
        var cleaned = response.trim();
        final startIndex = cleaned.indexOf('{');
        final endIndex = cleaned.lastIndexOf('}');
        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          cleaned = cleaned.substring(startIndex, endIndex + 1);
        }

        final data = json.decode(cleaned);
        if (data is Map<String, dynamic>) {
          String matchedCategory = 'Other';
          final parsedCat = data['category']?.toString().trim().toLowerCase();
          if (parsedCat != null) {
            for (final cat in categories) {
              if (cat.trim().toLowerCase() == parsedCat) {
                matchedCategory = cat;
                break;
              }
            }
          }

          final description = data['description']?.toString().trim() ?? data['merchant']?.toString().trim();
          return {
            'amount': data['amount'] != null ? double.tryParse(data['amount'].toString()) : null,
            'merchant': description,
            'description': description,
            'category': matchedCategory,
            'isExpense': data['isExpense'] == true,
          };
        }
      } catch (_) {
        // Fall through to offline fallback parser
      }
    }
    return OfflineAiFallbackService.parseSmsTransaction(smsBody, categories);
  }

  @override
  Future<String?> refineTransactionDescription(String rawDescription, String smsBody) async {
    final prompt = """
You are a financial assistant. Refine the following transaction description to be short, clean, and professional.
Extract the most relevant merchant name or transaction purpose.
Remove any "Purchase at", "Payment to", account numbers, dates, or technical codes.
If it's a peer-to-peer transfer, use "Transfer to [Name]" or "Received from [Name]".
If it's an ATM withdrawal, use "ATM Withdrawal".

Raw Description: $rawDescription
Original SMS: $smsBody

Respond with ONLY the refined description (max 30 characters). No punctuation at the end.
""";
    final result = await generateText(prompt);
    if (result != null && result.trim().isNotEmpty) {
      var cleaned = result.trim();
      if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
        cleaned = cleaned.substring(1, cleaned.length - 1);
      }
      return cleaned.length > 35 ? cleaned.substring(0, 35) : cleaned;
    }
    return rawDescription.length > 30 ? rawDescription.substring(0, 30) : rawDescription;
  }

  @override
  Future<String?> refineText(String text, String mode) async {
    String instruction;
    switch (mode.toLowerCase()) {
      case 'polish':
        instruction = "Correct any grammar, spelling, punctuation, and style issues in the text. Respond with ONLY the corrected text, with no explanations, introduction, or quotes.";
        break;
      case 'shorten':
        instruction = "Summarize or shorten the text to make it extremely concise and direct while preserving all essential information. Respond with ONLY the shortened version.";
        break;
      case 'expand':
        instruction = "Elaborate and expand the text, adding helpful details, descriptions, or professional formatting. Respond with ONLY the expanded version.";
        break;
      case 'professional':
        instruction = "Rewrite the text in a formal, professional, and business-ready tone. Respond with ONLY the rewritten text.";
        break;
      case 'casual':
        instruction = "Rewrite the text in a friendly, approachable, and casual tone. Respond with ONLY the rewritten text.";
        break;
      default:
        instruction = "Refine the text based on standard editing rules. Respond with ONLY the refined version.";
    }

    final prompt = """
$instruction

Text to process:
$text
""";
    final result = await generateText(prompt);
    if (result != null && result.trim().isNotEmpty) {
      return result;
    }

    switch (mode.toLowerCase()) {
      case 'polish':
      case 'professional':
      case 'casual':
        return OfflineAiFallbackService.proofreadAndPolish(text);
      case 'shorten':
        return OfflineAiFallbackService.makeShorter(text);
      case 'expand':
        return OfflineAiFallbackService.elaborateAndExpand(text);
      default:
        return text;
    }
  }

  @override
  Future<Map<String, dynamic>?> parseNaturalLanguageAction(
    String query,
    List<String> categories,
  ) async {
    final baseAction = OfflineAiFallbackService.parseNaturalLanguageAction(
      query,
      categories,
    );
    if (!await isSupported()) return baseAction;

    final categoriesStr = categories.map((c) => '"$c"').join(', ');
    final prompt = """
You are an on-device Android A2UI intent parser. Parse the user's natural language input into a JSON object.
Respond with ONLY a raw JSON object with one of these schemas:
1. For expense/income: {"type": "transaction", "amount": 450.0, "description": "Coffee", "category": "Food & Dining", "isExpense": true, "accountType": "daily"} (category MUST be from [$categoriesStr]; accountType is "daily" or "savings")
2. For split bill: {"type": "split_bill", "amount": 1200.0, "title": "Dinner", "participantCount": 3}
3. For checklist task: {"type": "todo", "taskText": "Buy milk"}
4. For quick note: {"type": "note", "title": "Meeting Notes", "content": "Meeting at 4pm"}

User input: $query
""";

    final response = await generateText(prompt);
    if (response != null && response.trim().isNotEmpty) {
      try {
        var cleaned = response.trim();
        final start = cleaned.indexOf('{');
        final end = cleaned.lastIndexOf('}');
        if (start != -1 && end != -1 && end > start) {
          cleaned = cleaned.substring(start, end + 1);
        }
        final decoded = json.decode(cleaned);
        if (decoded is Map<String, dynamic> && decoded['type'] != null) {
          return decoded;
        }
      } catch (_) {
        // Fall through to deterministic baseAction
      }
    }
    return baseAction;
  }
}

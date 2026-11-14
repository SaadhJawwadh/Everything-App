import '../features/finances/data/transaction_repository.dart';
import 'gemini_nano_service.dart';
import 'lite_rt_service.dart';
import 'local_ai_service.dart';
import 'offline_ai_fallback_service.dart';

typedef HistoryCategoryLookup = Future<String?> Function(String normalizedMerchant);

/// Hybrid on-device AI service implementing the 4-layer cascade:
/// Tier 2 (Gemini Nano / AICore) -> Personal History -> Tier 1 (MediaPipe Embeddings) -> OfflineAiFallbackService.
class HybridLocalAiService implements LocalAiService {
  final GeminiNanoService _genAi;
  final LiteRtService _liteRt;
  final HistoryCategoryLookup _historyLookup;

  Map<String, String>? _cachedMerchantHistory;

  HybridLocalAiService({
    GeminiNanoService? genAi,
    LiteRtService? liteRt,
    HistoryCategoryLookup? historyLookup,
  })  : _genAi = genAi ?? GeminiNanoService(),
        _liteRt = liteRt ?? LiteRtService.instance,
        _historyLookup = historyLookup ?? _defaultHistoryLookup;

  static Future<String?> _defaultHistoryLookup(String normalizedMerchant) async {
    return null;
  }

  Future<String?> _lookupMerchantCategory(String normalizedMerchant) async {
    final key = normalizedMerchant.toLowerCase().trim();
    if (key.isEmpty) return null;

    // Allow injected test/custom lookup first
    final injected = await _historyLookup(key);
    if (injected != null && injected.isNotEmpty) return injected;

    // Lazy-build normalized merchant -> category map from non-deleted SQLite transactions
    if (_cachedMerchantHistory == null) {
      try {
        final txns = await TransactionRepository.instance.readAllTransactions();
        final map = <String, String>{};
        // readAllTransactions is ordered newest-first; keep the most recent non-Other category
        for (final t in txns) {
          if (t.deletedAt != null || t.category == 'Other' || t.category.isEmpty) continue;
          final norm = LiteRtService.normalizeMerchantText(t.description).toLowerCase();
          if (norm.length >= 3 && !map.containsKey(norm)) {
            map[norm] = t.category;
          }
        }
        _cachedMerchantHistory = map;
      } catch (_) {
        _cachedMerchantHistory = {};
      }
    }

    return _cachedMerchantHistory![key];
  }

  void invalidateHistoryCache() {
    _cachedMerchantHistory = null;
  }

  @override
  Future<bool> isSupported() async {
    final results = await Future.wait([isGenAiSupported(), isEmbeddingSupported()]);
    return results[0] || results[1];
  }

  @override
  Future<bool> isGenAiSupported() => _genAi.isSupported();

  @override
  Future<bool> isEmbeddingSupported() => _liteRt.isSupported();

  @override
  Future<String?> generateText(String prompt) async {
    if (!await isGenAiSupported()) return null;
    return _genAi.generateText(prompt);
  }

  @override
  Future<String?> summarize(String text) async {
    if (await isGenAiSupported()) {
      final result = await _genAi.summarize(text);
      if (result != null && result.trim().isNotEmpty) return result;
    }
    return OfflineAiFallbackService.summarize(text);
  }

  @override
  Future<String?> refineText(String text, String mode) async {
    if (await isGenAiSupported()) {
      final result = await _genAi.refineText(text, mode);
      if (result != null && result.trim().isNotEmpty) return result;
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
  Future<String?> refineTransactionDescription(String rawDescription, String smsBody) async {
    if (await isGenAiSupported()) {
      final result = await _genAi.refineTransactionDescription(rawDescription, smsBody);
      if (result != null && result.trim().isNotEmpty) return result;
    }
    final normalized = LiteRtService.normalizeMerchantText(rawDescription);
    if (normalized.isNotEmpty) {
      return normalized.length > 30 ? normalized.substring(0, 30) : normalized;
    }
    return rawDescription.length > 30 ? rawDescription.substring(0, 30) : rawDescription;
  }

  @override
  Future<List<String>> suggestTags(String noteContent, List<String> existingTags) async {
    if (await isGenAiSupported()) {
      final result = await _genAi.suggestTags(noteContent, existingTags);
      if (result.isNotEmpty) return result;
    }

    if (existingTags.isNotEmpty && await isEmbeddingSupported()) {
      final suggested = await _liteRt.suggestTopLabels(
        text: noteContent,
        labels: existingTags,
        maxResults: 3,
        minConfidence: 0.25,
      );
      if (suggested.isNotEmpty) return suggested;
    }

    return OfflineAiFallbackService.suggestTags(noteContent, existingTags);
  }

  @override
  Future<Map<String, dynamic>?> parseSmsTransaction(
    String smsBody,
    List<String> categories,
  ) async {
    if (await isGenAiSupported()) {
      final result = await _genAi.parseSmsTransaction(smsBody, categories);
      if (result != null) return result;
    }

    final base = OfflineAiFallbackService.parseSmsTransaction(smsBody, categories);
    if (base == null) return null;

    final rawMerchant = (base['description'] ?? base['merchant'] ?? '').toString();
    final normalizedMerchant = LiteRtService.normalizeMerchantText(rawMerchant);
    if (normalizedMerchant.isNotEmpty) {
      base['description'] = normalizedMerchant;
      base['merchant'] = normalizedMerchant;
    }

    // 1. Personal History Lookup (resolves opaque local merchants like "ARABIAN KNIGHTS")
    if (normalizedMerchant.isNotEmpty) {
      final learnedCategory = await _lookupMerchantCategory(normalizedMerchant);
      if (learnedCategory != null && categories.contains(learnedCategory)) {
        base['category'] = learnedCategory;
        return base;
      }
    }

    // 2. Tier 1 MediaPipe Semantic Classification when deterministic rules returned 'Other'
    final currentCategory = base['category']?.toString() ?? 'Other';
    if ((currentCategory == 'Other' || !categories.contains(currentCategory)) &&
        categories.isNotEmpty &&
        await isEmbeddingSupported()) {
      final isExpense = base['isExpense'] == true;
      final candidateCategories = isExpense
          ? categories.where((c) => c != 'Deposit').toList()
          : categories;

      final queryText = normalizedMerchant.isNotEmpty ? normalizedMerchant : smsBody;
      final bestCategory = await _liteRt.classifyBestLabel(
        text: queryText,
        labels: candidateCategories,
        minConfidence: 0.25,
      );
      if (bestCategory != null) {
        base['category'] = bestCategory;
      }
    }

    return base;
  }

  @override
  Future<Map<String, dynamic>?> parseNaturalLanguageAction(
    String query,
    List<String> categories,
  ) async {
    if (await isGenAiSupported()) {
      final result = await _genAi.parseNaturalLanguageAction(query, categories);
      if (result != null) return result;
    }

    final base = OfflineAiFallbackService.parseNaturalLanguageAction(query, categories);
    if (base != null &&
        base['type'] == 'transaction' &&
        (base['category'] == null || base['category'] == 'Other') &&
        categories.isNotEmpty &&
        await isEmbeddingSupported()) {
      final bestCategory = await _liteRt.classifyBestLabel(
        text: LiteRtService.normalizeMerchantText(query),
        labels: categories,
        minConfidence: 0.25,
      );
      if (bestCategory != null) {
        base['category'] = bestCategory;
      }
    }
    return base;
  }
}

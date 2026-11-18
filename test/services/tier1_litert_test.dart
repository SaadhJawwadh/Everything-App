import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import 'package:note_taking_app/services/gemini_nano_service.dart';
import 'package:note_taking_app/services/hybrid_local_ai_service.dart';
import 'package:note_taking_app/services/lite_rt_service.dart';
import 'package:note_taking_app/services/local_ai_service.dart';

class _FakeGeminiNanoService extends GeminiNanoService {
  final bool supported;
  _FakeGeminiNanoService({required this.supported});

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<String?> generateText(String prompt) async =>
      supported ? 'GenAI response' : null;
}

class _FakeLocalAiService implements LocalAiService {
  final bool genAi;
  final bool embedding;
  _FakeLocalAiService({required this.genAi, required this.embedding});

  @override
  Future<bool> isSupported() async => genAi || embedding;
  @override
  Future<bool> isGenAiSupported() async => genAi;
  @override
  Future<bool> isEmbeddingSupported() async => embedding;
  @override
  Future<String?> generateText(String prompt) async => null;
  @override
  Future<Map<String, dynamic>?> parseNaturalLanguageAction(String query, List<String> categories) async => null;
  @override
  Future<Map<String, dynamic>?> parseSmsTransaction(String smsBody, List<String> categories) async => null;
  @override
  Future<String?> refineText(String text, String mode) async => null;
  @override
  Future<String?> refineTransactionDescription(String rawDescription, String smsBody) async => null;
  @override
  Future<List<String>> suggestTags(String noteContent, List<String> existingTags) async => [];
  @override
  Future<String?> summarize(String text) async => null;
}

class _FakeLiteRtService implements LiteRtService {
  final Map<String, double> scores;
  List<String>? lastLabels;

  _FakeLiteRtService({this.scores = const {}});

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<Map<String, double>> scoreLabels({
    required String text,
    required List<String> labels,
  }) async {
    lastLabels = labels;
    return scores;
  }

  @override
  Future<String?> classifyBestLabel({
    required String text,
    required List<String> labels,
    double minConfidence = 0.25,
    double minMargin = 0.02,
  }) async {
    lastLabels = labels;
    final filtered = scores.entries
        .where((e) => labels.contains(e.key))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (filtered.isEmpty || filtered.first.value < minConfidence) return null;
    if (filtered.length > 1 && (filtered.first.value - filtered[1].value) < minMargin) {
      return null;
    }
    return filtered.first.key;
  }

  @override
  Future<List<String>> suggestTopLabels({
    required String text,
    required List<String> labels,
    int maxResults = 3,
    double minConfidence = 0.25,
  }) async => [];

  @override
  Future<void> clearLabelCache() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.saadhjawwadh.notebook/litert');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('LiteRtService.normalizeMerchantText (CSV patterns)', () {
    test('strips phone number, LK suffix, and trailing "for" from PickMe Food', () {
      expect(
        LiteRtService.normalizeMerchantText('PickMe Food 0117433433 LK for '),
        'PickMe Food',
      );
    });

    test('strips (PVT) LTD from CITY OIL (PVT) LTD', () {
      expect(
        LiteRtService.normalizeMerchantText('CITY OIL (PVT) LTD'),
        'CITY OIL',
      );
    });

    test('strips COLOMBO-3 LK and RATMALANA LK', () {
      expect(
        LiteRtService.normalizeMerchantText('MR BAKERS COLOMBO-3 LK'),
        'MR BAKERS',
      );
      expect(
        LiteRtService.normalizeMerchantText('MATARA KITCHEN RATMALANA LK'),
        'MATARA KITCHEN',
      );
    });
  });

  group('HybridLocalAiService Tier 1 routing', () {
    test('uses personal history lookup before Tier 1 embeddings', () async {
      final hybrid = HybridLocalAiService(
        genAi: _FakeGeminiNanoService(supported: false),
        historyLookup: (normalized) async {
          if (normalized == 'arabian knights') return 'Food & Dining';
          return null;
        },
      );

      final parsed = await hybrid.parseSmsTransaction(
        'Rs. 6,191.46 spent at ARABIAN KNIGHTS on 2026-11-09',
        ['Food & Dining', 'Shopping', 'Transport', 'Other'],
      );

      expect(parsed, isNotNull);
      expect(parsed!['category'], 'Food & Dining');
    });

    test('falls back cleanly when LiteRT channel throws PlatformException', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'UNAVAILABLE', message: 'test error');
      });

      final scores = await LiteRtService.instance.scoreLabels(
        text: 'S N S UNITED HARDWARE',
        labels: ['Shopping', 'Food & Dining'],
      );
      expect(scores, isEmpty);
    });

    test('classifyTransactionCategory uses history lookup first', () async {
      final hybrid = HybridLocalAiService(
        genAi: _FakeGeminiNanoService(supported: false),
        historyLookup: (normalized) async {
          if (normalized == 'pickme food') return 'Food & Dining';
          return null;
        },
      );

      final category = await hybrid.classifyTransactionCategory(
        description: 'PickMe Food 0117433433 LK',
        smsBody: 'Rs. 1,250.00 spent at PickMe Food 0117433433 LK',
        isExpense: true,
        categories: ['Food & Dining', 'Transport', 'Deposit', 'Other'],
      );

      expect(category, 'Food & Dining');
    });

    test('classifyTransactionCategory falls back to Tier 1 LiteRT and excludes Deposit for expenses', () async {
      final fakeLiteRt = _FakeLiteRtService(
        scores: {
          'Transport': 0.82,
          'Food & Dining': 0.12,
          'Other': 0.06,
        },
      );

      final hybrid = HybridLocalAiService(
        genAi: _FakeGeminiNanoService(supported: false),
        liteRt: fakeLiteRt,
        historyLookup: (_) async => null,
      );

      final category = await hybrid.classifyTransactionCategory(
        description: 'UBER TRIP COLOMBO LK',
        smsBody: 'Rs. 850.00 spent at UBER TRIP COLOMBO LK',
        isExpense: true,
        categories: ['Food & Dining', 'Transport', 'Deposit', 'Other'],
      );

      expect(category, 'Transport');
      expect(fakeLiteRt.lastLabels, isNotNull);
      expect(fakeLiteRt.lastLabels, isNot(contains('Deposit')));
    });
  });

  group('SettingsProvider Tier 1 & Tier 2 capability gating', () {
    test('exposes isEmbeddingActive independently of isGenAiActive', () async {
      SharedPreferences.setMockInitialValues({'useOnDeviceAi': true});
      final settings = SettingsProvider();
      await settings.setUseOnDeviceAi(true);

      await settings.checkAiCoreSupport(
        _FakeLocalAiService(genAi: false, embedding: true),
      );

      expect(settings.isGenAiSupported, isFalse);
      expect(settings.isEmbeddingSupported, isTrue);
      expect(settings.isGenAiActive, isFalse);
      expect(settings.isEmbeddingActive, isTrue);
      expect(settings.isAiActive, isTrue);
    });

    test('checkAiCoreSupport auto-enables useOnDeviceAi when hardware is supported and no prior pref exists', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsProvider();

      await settings.checkAiCoreSupport(
        _FakeLocalAiService(genAi: false, embedding: true),
      );

      expect(settings.isDeviceAiSupported, isTrue);
      expect(settings.useOnDeviceAi, isTrue);
      expect(settings.isAiActive, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('useOnDeviceAi'), isTrue);
    });

    test('checkAiCoreSupport preserves false when useOnDeviceAi was explicitly set to false', () async {
      SharedPreferences.setMockInitialValues({'useOnDeviceAi': false});
      final settings = SettingsProvider();
      await settings.setUseOnDeviceAi(false);

      await settings.checkAiCoreSupport(
        _FakeLocalAiService(genAi: true, embedding: true),
      );

      expect(settings.isDeviceAiSupported, isTrue);
      expect(settings.useOnDeviceAi, isFalse);
      expect(settings.isAiActive, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('useOnDeviceAi'), isFalse);
    });
  });
}

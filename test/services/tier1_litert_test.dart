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
  });
}

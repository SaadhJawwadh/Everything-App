import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'native_core_bridge.dart';

class SyncCryptoService {
  static final SyncCryptoService instance = SyncCryptoService._init();
  SyncCryptoService._init();
  factory SyncCryptoService() => instance;

  static const String _p2pDomainSalt = 'EverythingApp_P2P_Sync_Salt_v2';
  static const int _pbkdf2Iterations = 10000;

  static final Map<String, enc.Key> _derivedKeyCache = {};

  /// Derives a 32-byte (256-bit) AES key using PBKDF2-HMAC-SHA256 with domain salt.
  /// Uses hardware-accelerated native crypto when available with pure-Dart fallback.
  enc.Key deriveKey(String secret) {
    final trimmed = secret.trim();
    final cached = _derivedKeyCache[trimmed];
    if (cached != null) return cached;

    final keyBytes = utf8.encode(trimmed);
    final saltBytes = utf8.encode(_p2pDomainSalt);

    final t = NativeCoreBridge.instance.derivePbkdf2Sha256(
      secret: Uint8List.fromList(keyBytes),
      salt: Uint8List.fromList(saltBytes),
      iterations: _pbkdf2Iterations,
    );

    final derived = enc.Key(t);
    _derivedKeyCache[trimmed] = derived;
    return derived;
  }

  /// Legacy single-round SHA-256 derivation for backward compatibility with v1 endpoints.
  enc.Key deriveLegacyKey(String secret) {
    final bytes = utf8.encode(secret.trim());
    final digest = NativeCoreBridge.instance.sha256Digest(Uint8List.fromList(bytes));
    return enc.Key(digest);
  }

  /// Encrypts a raw text string into a base64 ciphertext with IV.
  /// Set [legacyMode] to true when responding to older legacy clients.
  String? encryptPayload(String rawText, String secretKey, {bool legacyMode = false}) {
    try {
      final key = legacyMode ? deriveLegacyKey(secretKey) : deriveKey(secretKey);
      final iv = enc.IV.fromSecureRandom(16);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encrypt(rawText, iv: iv);
      
      final payloadMap = {
        'v': legacyMode ? 1 : 2,
        'iv': iv.base64,
        'data': encrypted.base64,
      };
      return base64.encode(utf8.encode(json.encode(payloadMap)));
    } catch (_) {
      return null;
    }
  }

  /// Asynchronously encrypts payload, offloading large payloads (>= 2KB) to a background isolate
  /// so the UI thread experiences 0ms stutter.
  Future<String?> encryptPayloadAsync(String rawText, String secretKey, {bool legacyMode = false}) async {
    if (rawText.length < 2048) {
      return encryptPayload(rawText, secretKey, legacyMode: legacyMode);
    }
    return Isolate.run(() {
      return SyncCryptoService.instance.encryptPayload(rawText, secretKey, legacyMode: legacyMode);
    });
  }

  /// Decrypts payload and returns both raw text and whether legacy key derivation was used.
  (String?, bool) decryptPayloadDetailed(String encryptedBase64Payload, String secretKey) {
    try {
      final decodedJson = utf8.decode(base64.decode(encryptedBase64Payload));
      final map = json.decode(decodedJson) as Map<String, dynamic>;
      
      final iv = enc.IV.fromBase64(map['iv'] as String);
      final encryptedData = enc.Encrypted.fromBase64(map['data'] as String);
      final version = map['v'] as int? ?? 1;

      // If version is explicitly 1 (legacy), try legacy first
      if (version == 1) {
        try {
          final legacyKey = deriveLegacyKey(secretKey);
          final encrypter = enc.Encrypter(enc.AES(legacyKey, mode: enc.AESMode.cbc));
          final decrypted = encrypter.decrypt(encryptedData, iv: iv);
          if (decrypted.trim().isNotEmpty) {
            json.decode(decrypted);
            return (decrypted, true);
          }
        } catch (_) {}
      }
      
      // Attempt 1: Standard PBKDF2 key
      try {
        final key = deriveKey(secretKey);
        final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
        final decrypted = encrypter.decrypt(encryptedData, iv: iv);
        if (decrypted.trim().isNotEmpty) {
          json.decode(decrypted);
          return (decrypted, false);
        }
      } catch (_) {}

      // Attempt 2: Legacy single-SHA256 fallback (v1 compatibility)
      try {
        final legacyKey = deriveLegacyKey(secretKey);
        final encrypter = enc.Encrypter(enc.AES(legacyKey, mode: enc.AESMode.cbc));
        final decrypted = encrypter.decrypt(encryptedData, iv: iv);
        if (decrypted.trim().isNotEmpty) {
          json.decode(decrypted);
          return (decrypted, true);
        }
      } catch (_) {}

      return (null, false);
    } catch (_) {
      return (null, false);
    }
  }

  /// Asynchronously decrypts detailed payload offloading payloads >= 2KB to a background isolate.
  Future<(String?, bool)> decryptPayloadDetailedAsync(String encryptedBase64Payload, String secretKey) async {
    if (encryptedBase64Payload.length < 2048) {
      return decryptPayloadDetailed(encryptedBase64Payload, secretKey);
    }
    return Isolate.run(() {
      return SyncCryptoService.instance.decryptPayloadDetailed(encryptedBase64Payload, secretKey);
    });
  }

  /// Decrypts a base64 ciphertext string back to raw text payload.
  /// Seamlessly tries PBKDF2 key first, falling back to legacy key if payload was from older versions.
  String? decryptPayload(String encryptedBase64Payload, String secretKey) {
    return decryptPayloadDetailed(encryptedBase64Payload, secretKey).$1;
  }

  /// Asynchronously decrypts payload string back to raw text.
  Future<String?> decryptPayloadAsync(String encryptedBase64Payload, String secretKey) async {
    final (decrypted, _) = await decryptPayloadDetailedAsync(encryptedBase64Payload, secretKey);
    return decrypted;
  }
}

import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

class SyncCryptoService {
  static final SyncCryptoService instance = SyncCryptoService._init();
  SyncCryptoService._init();
  factory SyncCryptoService() => instance;

  static const String _p2pDomainSalt = 'EverythingApp_P2P_Sync_Salt_v2';
  static const int _pbkdf2Iterations = 10000;

  static final Map<String, enc.Key> _derivedKeyCache = {};

  /// Derives a 32-byte (256-bit) AES key using PBKDF2-HMAC-SHA256 with domain salt.
  enc.Key deriveKey(String secret) {
    final trimmed = secret.trim();
    final cached = _derivedKeyCache[trimmed];
    if (cached != null) return cached;

    final keyBytes = utf8.encode(trimmed);
    final saltBytes = utf8.encode(_p2pDomainSalt);
    final hmac = Hmac(sha256, keyBytes);

    // PBKDF2 for 1 block (32 bytes)
    // U_1 = HMAC(secret, salt || 0x00000001)
    final saltPlusBlockIndex = Uint8List(saltBytes.length + 4)
      ..setRange(0, saltBytes.length, saltBytes)
      ..setRange(saltBytes.length, saltBytes.length + 4, [0, 0, 0, 1]);

    List<int> u = hmac.convert(saltPlusBlockIndex).bytes;
    final t = Uint8List.fromList(u);

    for (int i = 1; i < _pbkdf2Iterations; i++) {
      u = hmac.convert(u).bytes;
      for (int j = 0; j < 32; j++) {
        t[j] ^= u[j];
      }
    }

    final derived = enc.Key(t);
    _derivedKeyCache[trimmed] = derived;
    return derived;
  }

  /// Legacy single-round SHA-256 derivation for backward compatibility with v1 endpoints.
  enc.Key deriveLegacyKey(String secret) {
    final bytes = utf8.encode(secret.trim());
    final digest = sha256.convert(bytes);
    return enc.Key(Uint8List.fromList(digest.bytes));
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

  /// Decrypts a base64 ciphertext string back to raw text payload.
  /// Seamlessly tries PBKDF2 key first, falling back to legacy key if payload was from older versions.
  String? decryptPayload(String encryptedBase64Payload, String secretKey) {
    return decryptPayloadDetailed(encryptedBase64Payload, secretKey).$1;
  }
}

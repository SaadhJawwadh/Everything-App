import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the hardware-backed 256-bit key used to encrypt automated
/// background backups (`performAutoBackup`) without prompting the user.
class BackupVaultKeyService {
  BackupVaultKeyService._init();
  static final BackupVaultKeyService instance = BackupVaultKeyService._init();
  factory BackupVaultKeyService() => instance;

  static const String _vaultKeyStorageKey = 'backup_vault_key_v1';
  static const String _vaultInitializedPrefKey = 'autoBackupVaultInitialized';

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  @visibleForTesting
  static String? mockVaultKeyForTest;

  @visibleForTesting
  static bool simulateReadFailureForTest = false;

  /// Reads the existing vault key from secure storage with 3-attempt
  /// exponential backoff (matching `DatabaseHelper._getOrCreateEncryptionKey`).
  /// Returns `null` if missing or unreadable.
  Future<String?> readVaultKey() async {
    if (simulateReadFailureForTest) return null;
    if (mockVaultKeyForTest != null) return mockVaultKeyForTest;

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final key = await _secureStorage.read(key: _vaultKeyStorageKey);
        if (key != null && key.isNotEmpty) {
          return key;
        }
      } catch (e) {
        debugPrint('[BackupVaultKeyService] Read attempt $attempt failed: $e');
      }
      if (attempt < 3) {
        await Future.delayed(Duration(milliseconds: 100 * (1 << (attempt - 1))));
      }
    }
    return null;
  }

  /// Returns the existing vault key, or creates one if the vault has never been
  /// initialized. If `autoBackupVaultInitialized` is already `true` and secure
  /// storage cannot be read, **fails closed** by returning `null` (never
  /// silently rotating or minting a replacement key).
  Future<String?> getOrCreateVaultKey({bool allowCreate = true}) async {
    final existing = await readVaultKey();
    final prefs = await SharedPreferences.getInstance();

    if (existing != null && existing.isNotEmpty) {
      if (!(prefs.getBool(_vaultInitializedPrefKey) ?? false)) {
        await prefs.setBool(_vaultInitializedPrefKey, true);
      }
      return existing;
    }

    final alreadyInitialized = prefs.getBool(_vaultInitializedPrefKey) ?? false;
    if (alreadyInitialized || !allowCreate || simulateReadFailureForTest) {
      debugPrint('[BackupVaultKeyService] Fail-closed: vault key unavailable (initialized=$alreadyInitialized).');
      return null;
    }

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final generatedKey = base64UrlEncode(bytes);

    if (mockVaultKeyForTest == null) {
      await _secureStorage.write(key: _vaultKeyStorageKey, value: generatedKey);
    }
    await prefs.setBool(_vaultInitializedPrefKey, true);
    return generatedKey;
  }

  /// Imports a recovery key pasted by the user (e.g., after migrating devices).
  Future<bool> importVaultKey(String rawKey) async {
    final trimmed = rawKey.trim();
    if (trimmed.length < 16) return false;
    try {
      if (mockVaultKeyForTest != null) {
        mockVaultKeyForTest = trimmed;
      } else {
        await _secureStorage.write(key: _vaultKeyStorageKey, value: trimmed);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_vaultInitializedPrefKey, true);
      return true;
    } catch (e) {
      debugPrint('[BackupVaultKeyService] Failed to import vault key: $e');
      return false;
    }
  }
}

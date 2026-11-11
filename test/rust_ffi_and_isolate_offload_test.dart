import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_taking_app/services/native_core_bridge.dart';
import 'package:note_taking_app/services/sync_crypto_service.dart';
import 'package:note_taking_app/services/backup_service.dart';
import 'package:note_taking_app/features/notes/services/note_migration_service.dart';
import 'package:note_taking_app/services/sms_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NativeCoreBridge & FFI / Pure-Dart Parity', () {
    test('Native library status and SHA-256 byte parity', () {
      final bridge = NativeCoreBridge.instance;
      expect(bridge.isNativeLoaded, isTrue, reason: 'Native dylib should load on macOS development');

      const testStr = 'The quick brown fox jumps over the lazy dog';
      final testBytes = Uint8List.fromList(utf8.encode(testStr));

      final nativeDigest = bridge.sha256Digest(testBytes);
      final dartDigest = Uint8List.fromList(sha256.convert(testBytes).bytes);

      expect(nativeDigest.length, 32);
      expect(nativeDigest, equals(dartDigest));
    });

    test('PBKDF2-HMAC-SHA256 10,000 iterations byte-for-byte parity', () {
      final bridge = NativeCoreBridge.instance;
      final secret = Uint8List.fromList(utf8.encode('TestSecretPassphrase123!'));
      final salt = Uint8List.fromList(utf8.encode('EverythingApp_P2P_Sync_Salt_v2'));

      final nativeKey = bridge.derivePbkdf2Sha256(
        secret: secret,
        salt: salt,
        iterations: 10000,
      );

      // Manual pure-Dart HMAC calculation to verify mathematical parity
      final hmac = Hmac(sha256, secret);
      final saltPlusBlock = Uint8List(salt.length + 4)
        ..setRange(0, salt.length, salt)
        ..setRange(salt.length, salt.length + 4, [0, 0, 0, 1]);
      List<int> u = hmac.convert(saltPlusBlock).bytes;
      final dartKey = Uint8List.fromList(u);
      for (int i = 1; i < 10000; i++) {
        u = hmac.convert(u).bytes;
        for (int j = 0; j < 32; j++) {
          dartKey[j] ^= u[j];
        }
      }

      expect(nativeKey.length, 32);
      expect(nativeKey, equals(dartKey));
    });

    test('Fast digit scanner accurately detects presence of digits', () {
      final bridge = NativeCoreBridge.instance;
      expect(bridge.containsDigits('Hello World'), isFalse);
      expect(bridge.containsDigits(''), isFalse);
      expect(bridge.containsDigits('Your OTP is none today'), isFalse);

      expect(bridge.containsDigits('Debited Rs. 500 at Store'), isTrue);
      expect(bridge.containsDigits('0'), isTrue);
      expect(bridge.containsDigits('Spent 12.50 USD'), isTrue);
    });
  });

  group('SyncCryptoService Isolate Offloading & Compatibility', () {
    test('Encrypt and Decrypt Async round-trip with large payload', () async {
      final crypto = SyncCryptoService.instance;
      final largePayload = json.encode({
        'action': 'sync_snapshot',
        'records': List.generate(100, (i) => {
          'id': 'note_$i',
          'title': 'Test Note Title $i',
          'content': 'This is a large string content designed to trigger isolate background execution.' * 10,
        }),
      });

      expect(largePayload.length, greaterThan(2048));

      // Asynchronous isolate encryption
      final encrypted = await crypto.encryptPayloadAsync(largePayload, '654321');
      expect(encrypted, isNotNull);

      // Asynchronous isolate decryption
      final decrypted = await crypto.decryptPayloadAsync(encrypted!, '654321');
      expect(decrypted, equals(largePayload));

      // Cross-compatibility: sync decrypt handles async-encrypted payload
      final (syncDecrypted, isLegacy) = crypto.decryptPayloadDetailed(encrypted, '654321');
      expect(syncDecrypted, equals(largePayload));
      expect(isLegacy, isFalse);
    });

    test('Legacy v1 single-round key compatibility', () async {
      final crypto = SyncCryptoService.instance;
      final text = json.encode({'type': 'legacy_packet', 'msg': 'Legacy format packet'});
      final legacyEncrypted = await crypto.encryptPayloadAsync(text, '123456', legacyMode: true);
      expect(legacyEncrypted, isNotNull);

      final (decrypted, isLegacy) = await crypto.decryptPayloadDetailedAsync(legacyEncrypted!, '123456');
      expect(decrypted, equals(text));
      expect(isLegacy, isTrue);
    });
  });

  group('BackupService Isolate Offloading', () {
    test('Encrypt and decrypt backup JSON across isolates', () async {
      final backupData = json.encode({
        'version': 11,
        'notes': [
          {'id': '1', 'title': 'Meeting Notes', 'content': 'Discuss project roadmap'}
        ],
        'transactions': [
          {'_id': 1, 'amount': 1500.0, 'description': 'Grocery Store', 'date': '2026-11-11T12:00:00'}
        ],
      });

      final encrypted = await BackupService.encryptBackupJsonAsync(backupData, 'SuperSecurePassword');
      expect(encrypted, isNotEmpty);
      expect(encrypted.contains('"encrypted": true'), isTrue);

      final container = json.decode(encrypted) as Map<String, dynamic>;
      final decrypted = await BackupService.decryptBackupJsonAsync(container, 'SuperSecurePassword');

      expect(decrypted, equals(backupData));
    });
  });

  group('NoteMigrationService Isolate ZIP Parsing', () {
    test('parseZipForTesting executes decompression in background isolate', () async {
      // Build a minimal in-memory Google Takeout ZIP archive
      final archive = Archive();

      final keepNote = json.encode({
        'title': 'Test Keep Note',
        'textContent': 'This is imported note text from Keep Takeout.',
        'isPinned': true,
        'isArchived': false,
      });

      final keepBytes = utf8.encode(keepNote);
      archive.addFile(ArchiveFile('Takeout/Keep/Test Note.json', keepBytes.length, keepBytes));

      const mdContent = '# Markdown Title\nThis is markdown body.';
      final mdBytes = utf8.encode(mdContent);
      archive.addFile(ArchiveFile('Takeout/Keep/sample.md', mdBytes.length, mdBytes));

      final zipData = ZipEncoder().encode(archive);
      expect(zipData, isNotNull);

      final tempDir = Directory.systemTemp.createTempSync('zip_test_');
      final zipFile = File('${tempDir.path}/takeout.zip')..writeAsBytesSync(zipData);

      final parsed = await NoteMigrationService.parseZipForTesting(zipFile);
      expect(parsed.length, 2);

      final titles = parsed.map((n) => n.title).toList();
      expect(titles, contains('Test Keep Note'));
      expect(titles, contains('Markdown Title'));

      tempDir.deleteSync(recursive: true);
    });
  });

  group('SmsParser Isolate Batch Processing & Fast Prefilter', () {
    test('isPotentiallyRelevant instantly skips pure-text messages without regex overhead', () {
      final relevant = SmsParser.isPotentiallyRelevant(
        body: 'Hey how are you doing today? Let us meet up later.',
        address: 'FRIEND',
        allowedSenderIds: {},
        blockedSenderIds: {},
      );
      expect(relevant, isFalse);
    });

    test('parseBatchInIsolate correctly extracts transactions', () async {
      final batch = [
        (
          body: 'Debited LKR 1,500.00 from Acct XX1234 at SUPERMARKET on 11-Nov-2026.',
          address: 'COMBANK',
          messageId: 101,
          messageDate: DateTime.now().millisecondsSinceEpoch,
        ),
        (
          body: 'Your OTP code is 987654. Do not share.',
          address: 'BANK_OTP',
          messageId: 102,
          messageDate: DateTime.now().millisecondsSinceEpoch,
        ),
        (
          body: 'No money involved here just chat.',
          address: 'BOB',
          messageId: 103,
          messageDate: DateTime.now().millisecondsSinceEpoch,
        ),
      ];

      final results = await SmsParser.parseBatchInIsolate(
        batch: batch,
        allowedSenderIds: {'combank'},
        blockedSenderIds: {},
        customExpenseRules: [],
        customIncomeRules: [],
      );

      expect(results.length, 3);
      // Message 0: Valid debit transaction
      expect(results[0], isNotNull);
      expect(results[0]!.amount, 1500.0);
      expect(results[0]!.isExpense, isTrue);

      // Message 1: OTP rejected
      expect(results[1], isNull);

      // Message 2: No transaction terms
      expect(results[2], isNull);
    });
  });
}

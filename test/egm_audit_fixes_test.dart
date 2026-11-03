import 'dart:convert';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:note_taking_app/data/database_helper.dart';
import 'package:note_taking_app/data/transaction_model.dart';
import 'package:note_taking_app/data/note_model.dart';
import 'package:note_taking_app/features/finances/data/transaction_repository.dart';
import 'package:note_taking_app/features/notes/data/note_repository.dart';
import 'package:note_taking_app/screens/app_lock_screen.dart';
import 'package:note_taking_app/features/settings/providers/settings_provider.dart';
import 'package:note_taking_app/services/backup_service.dart';
import 'package:note_taking_app/services/sync_crypto_service.dart';
import 'package:note_taking_app/services/sync_merge_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late TransactionRepository transactionRepo;
  late NoteRepository noteRepo;

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 26,
      onCreate: (db, version) async {
        await DatabaseHelper.instance.createTestDatabase(db);
      },
    );
    DatabaseHelper.setMockDatabase(db);
    transactionRepo = TransactionRepository.instance;
    noteRepo = NoteRepository.instance;
  });

  tearDown(() async {
    await db.close();
  });

  group('Finances: Atomic Transfer & Summary Exclusion Tests', () {
    test('createTransferTransactions creates withdrawal and deposit atomically', () async {
      final now = DateTime.now();
      final withdrawal = TransactionModel(
        amount: 500.0,
        description: 'Vault Deposit (Transfer Out)',
        date: now,
        isExpense: true,
        category: 'Transfer',
        account: AccountType.daily,
      );
      final deposit = TransactionModel(
        amount: 500.0,
        description: 'Vault Deposit (Transfer In)',
        date: now,
        isExpense: false,
        category: 'Transfer',
        account: AccountType.savings,
      );

      final results = await transactionRepo.createTransferTransactions(
        withdrawal: withdrawal,
        deposit: deposit,
      );

      expect(results.length, 2);
      expect(results[0].id, isNotNull);
      expect(results[1].id, isNotNull);

      final allTxns = await transactionRepo.readAllTransactions();
      expect(allTxns.length, 2);
    });

    test('getMonthlyTransactionSummary and getAllTimeSummary exclude Transfer category', () async {
      final now = DateTime.now();

      // Regular income and expense
      await transactionRepo.createTransaction(TransactionModel(
        amount: 2000.0,
        description: 'Salary',
        date: now,
        isExpense: false,
        category: 'Salary',
        account: AccountType.daily,
      ));
      await transactionRepo.createTransaction(TransactionModel(
        amount: 300.0,
        description: 'Groceries',
        date: now,
        isExpense: true,
        category: 'Food',
        account: AccountType.daily,
      ));

      // Transfer records (should NOT inflate income or expense)
      await transactionRepo.createTransferTransactions(
        withdrawal: TransactionModel(
          amount: 500.0,
          description: 'Transfer Out',
          date: now,
          isExpense: true,
          category: 'Transfer',
          account: AccountType.daily,
        ),
        deposit: TransactionModel(
          amount: 500.0,
          description: 'Transfer In',
          date: now,
          isExpense: false,
          category: 'transfer',
          account: AccountType.savings,
        ),
      );

      final monthlySummary = await transactionRepo.getMonthlyTransactionSummary(1);
      expect(monthlySummary.first['totalIncome'], 2000.0,
          reason: 'Internal transfer must not be counted as income');
      expect(monthlySummary.first['totalExpense'], 300.0,
          reason: 'Internal transfer must not be counted as expense');

      final allTimeSummary = await transactionRepo.getAllTimeSummary();
      expect(allTimeSummary['totalIncome'], 2000.0);
      expect(allTimeSummary['totalExpense'], 300.0);
    });
  });

  group('Notes: Search Preview vs Delta Metadata Tests', () {
    test('searchNotes searches previewText and avoids matching raw Delta JSON syntax', () async {
      final now = DateTime.now();

      // Note with Delta JSON content containing 'insert' and 'bold'
      final note1 = Note(
        id: 'note-1',
        title: 'Meeting Notes',
        content: r'[{"insert":"Meeting with the team about project alpha\n","attributes":{"bold":true}}]',
        dateCreated: now,
        dateModified: now,
      );
      await noteRepo.createNote(note1);

      // Note with legitimate text containing 'insert'
      final note2 = Note(
        id: 'note-2',
        title: 'SQL Tutorial',
        content: r'[{"insert":"Learn how to insert records into a database table\n"}]',
        dateCreated: now,
        dateModified: now,
      );
      await noteRepo.createNote(note2);

      // Searching for 'alpha' should only find note1
      final alphaResults = await noteRepo.searchNotes('alpha');
      expect(alphaResults.length, 1);
      expect(alphaResults.first.id, 'note-1');

      // Searching for 'insert' should only match note2 (whose text actually has the word 'insert'),
      // NOT note1 (whose JSON syntax merely has 'insert')
      final insertResults = await noteRepo.searchNotes('insert');
      expect(insertResults.length, 1);
      expect(insertResults.first.id, 'note-2');

      // Searching for 'bold' should return nothing because neither has the word 'bold' in text
      final boldResults = await noteRepo.searchNotes('bold');
      expect(boldResults.length, 0);
    });
  });

  group('Lock Screen: PopScope & Authentication Protection Tests', () {
    testWidgets('Unauthenticated AppLockScreen contains PopScope preventing pop', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/local_auth'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'authenticate') {
            return false;
          }
          if (methodCall.method == 'isDeviceSupported') {
            return true;
          }
          return null;
        },
      );

      SharedPreferences.setMockInitialValues({
        'appLockEnabled': true,
        'appLockTimeout': 0,
      });
      final settings = SettingsProvider();
      await settings.loadSettings();

      AppLockScreen.sessionAuthenticated.value = false;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<SettingsProvider>.value(
            value: settings,
            child: const AppLockScreen(
              child: Text('Protected Content'),
            ),
          ),
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Lock screen should be active and App Locked displayed
      expect(find.text('App Locked'), findsOneWidget);

      // Protected content should be hidden behind lock overlay wrapped in PopScope(canPop: false)
      final popScopeFinder = find.byWidgetPredicate((w) => w is PopScope);
      expect(popScopeFinder, findsOneWidget);
      final popScope = tester.widget<PopScope>(popScopeFinder);
      expect(popScope.canPop, isFalse);
    });
  });

  group('Backup & Restore: Savings Goals, Period Logs, and FK Integrity', () {
    test('restoreFromBackupData cleanly replaces savings_goals and deleted_period_logs', () async {
      // 1. Insert existing local goal and tombstone that are NOT in the incoming backup
      await db.insert('savings_goals', {
        'id': 'stale-goal-1',
        'title': 'Old Stale Goal',
        'targetAmount': 1000.0,
        'currentAmount': 100.0,
        'isCompleted': 0,
        'createdAt': DateTime.now().toIso8601String(),
      });
      await db.insert('deleted_period_logs', {
        'id': 'stale-tombstone-1',
        'deletedAt': DateTime.now().toIso8601String(),
      });

      // 2. Prepare backup data containing only fresh new goal and tombstone
      final backupData = <String, dynamic>{
        'savingsGoals': [
          {
            'id': 'fresh-goal-2',
            'title': 'New Emergency Fund',
            'targetAmount': 5000.0,
            'currentAmount': 500.0,
            'isCompleted': 0,
          }
        ],
        'deletedPeriodLogs': [
          {
            'id': 'fresh-tombstone-2',
            'deletedAt': DateTime.now().toIso8601String(),
          }
        ],
      };

      // 3. Restore backup
      await BackupService.restoreFromBackupData(backupData);

      // 4. Assert old stale records were cleared and only fresh records exist
      final restoredGoals = await db.query('savings_goals');
      expect(restoredGoals.length, 1);
      expect(restoredGoals.first['id'], 'fresh-goal-2');
      expect(restoredGoals.first['title'], 'New Emergency Fund');

      final restoredTombstones = await db.query('deleted_period_logs');
      expect(restoredTombstones.length, 1);
      expect(restoredTombstones.first['id'], 'fresh-tombstone-2');
    });

    test('restoreFromBackupData supports snake_case savings_goals key', () async {
      final backupData = <String, dynamic>{
        'savings_goals': [
          {
            'id': 'snake-goal-1',
            'title': 'Snake Case Goal',
            'targetAmount': 2500.0,
            'currentAmount': 250.0,
            'isCompleted': 0,
          }
        ],
      };

      await BackupService.restoreFromBackupData(backupData);

      final restoredGoals = await db.query('savings_goals');
      expect(restoredGoals.length, 1);
      expect(restoredGoals.first['id'], 'snake-goal-1');
    });
  });

  group('P2P Sync: Split Bills, Savings Goals LWW and SMS Edit Propagation', () {
    test('mergeRemoteData preserves soft-delete states on split_bills and savings_goals', () async {
      // Setup local deleted split bill and active savings goal
      final now = DateTime.now().toIso8601String();
      await db.insert('split_bills', {
        'id': 'bill-1',
        'title': 'Dinner',
        'totalAmount': 100.0,
        'payerName': 'Alice',
        'isPayerUser': 1,
        'splitMode': 'equal',
        'date': now,
        'deletedAt': now, // Locally deleted!
      });

      await db.insert('savings_goals', {
        'id': 'goal-1',
        'title': 'Vacation',
        'targetAmount': 2000.0,
        'currentAmount': 300.0,
        'isCompleted': 0,
        'createdAt': now,
        'deletedAt': null, // Locally active!
      });

      // Remote incoming data:
      // - bill-1 has deletedAt: null (remote older/active shouldn't un-delete local deletion)
      // - goal-1 has deletedAt: now (remote deleted should propagate to local)
      final remoteData = {
        'splitBills': [
          {
            'id': 'bill-1',
            'title': 'Dinner',
            'totalAmount': 100.0,
            'payerName': 'Alice',
            'isPayerUser': 1,
            'splitMode': 'equal',
            'date': now,
            'deletedAt': null,
          }
        ],
        'savingsGoals': [
          {
            'id': 'goal-1',
            'title': 'Vacation',
            'targetAmount': 2000.0,
            'currentAmount': 300.0,
            'isCompleted': 0,
            'deletedAt': now,
          }
        ],
      };

      final result = await SyncMergeService.instance.mergeRemoteData(remoteData);

      final bills = await db.query('split_bills', where: 'id = ?', whereArgs: ['bill-1']);
      expect(bills.first['deletedAt'], isNotNull,
          reason: 'Remote active bill should not resurrect locally soft-deleted bill');

      final goals = await db.query('savings_goals', where: 'id = ?', whereArgs: ['goal-1']);
      expect(goals.first['deletedAt'], isNotNull,
          reason: 'Remote soft-delete should propagate to local savings goal');
      expect(result.savingsGoalsMerged, 1);
    });

    test('mergeRemoteData propagates SMS transaction category and account updates', () async {
      final now = DateTime.now().toIso8601String();
      // Local transaction
      await db.insert('transactions', {
        'smsId': 'sms_12345',
        'amount': 50.0,
        'description': 'Coffee Shop',
        'date': now,
        'isExpense': 1,
        'category': 'Other',
        'account': 'daily',
        'isAiRefined': 0,
      });

      // Remote transaction with updated category and account
      final remoteData = {
        'transactions': [
          {
            'smsId': 'sms_12345',
            'amount': 50.0,
            'description': 'Coffee Shop Premium',
            'date': now,
            'isExpense': 1,
            'category': 'Food & Drinks',
            'account': 'savings',
            'isAiRefined': 1,
          }
        ]
      };

      final result = await SyncMergeService.instance.mergeRemoteData(remoteData);
      expect(result.transactionsMerged, 1);

      final txns = await db.query('transactions', where: 'smsId = ?', whereArgs: ['sms_12345']);
      expect(txns.first['category'], 'Food & Drinks');
      expect(txns.first['account'], 'savings');
      expect(txns.first['isAiRefined'], 1);
      expect(txns.first['description'], 'Coffee Shop Premium');
    });
  });

  group('DatabaseHelper: KeyStore Resilience & Anti-Wipe Guardrail', () {
    test('SecureStorageKeyMissingException formats correctly and preserves message', () {
      const defaultException = SecureStorageKeyMissingException();
      expect(defaultException.toString(), contains('Database file exists on disk'));
      expect(defaultException.toString(), contains('SecureStorageKeyMissingException:'));

      const customException = SecureStorageKeyMissingException('Custom Keystore Error');
      expect(customException.toString(), 'SecureStorageKeyMissingException: Custom Keystore Error');
      expect(customException.message, 'Custom Keystore Error');
    });

    test('DatabaseAuthException formats correctly and preserves message', () {
      const defaultAuthException = DatabaseAuthException();
      expect(defaultAuthException.toString(), contains('Database authentication failed'));
      expect(defaultAuthException.toString(), contains('DatabaseAuthException:'));

      const customAuthException = DatabaseAuthException('Wrong SQLCipher password');
      expect(customAuthException.toString(), 'DatabaseAuthException: Wrong SQLCipher password');
      expect(customAuthException.message, 'Wrong SQLCipher password');
    });
  });

  group('SyncCryptoService: PBKDF2 Key Derivation & P2P Transport Hardening', () {
    test('deriveKey produces stable 256-bit AES key with PBKDF2 and caches results', () {
      final crypto = SyncCryptoService.instance;
      final key1 = crypto.deriveKey('123456');
      final key2 = crypto.deriveKey('123456');

      expect(key1.bytes.length, 32);
      expect(identical(key1, key2), isTrue, reason: 'Subsequent calls should hit the key derivation cache');

      final keyDiff = crypto.deriveKey('654321');
      expect(keyDiff.bytes, isNot(equals(key1.bytes)));
    });

    test('encryptPayload and decryptPayload round-trip successfully with PBKDF2', () {
      final crypto = SyncCryptoService.instance;
      const originalPayload = '{"action":"ping","timestamp":1700000000}';
      const secret = '987654';

      final encrypted = crypto.encryptPayload(originalPayload, secret);
      expect(encrypted, isNotNull);
      expect(encrypted, isNotEmpty);

      final decrypted = crypto.decryptPayload(encrypted!, secret);
      expect(decrypted, originalPayload);

      final wrongKeyAttempt = crypto.decryptPayload(encrypted, '000000');
      expect(wrongKeyAttempt, isNull, reason: 'Wrong secret key must fail decryption');
    });

    test('decryptPayload seamlessly decrypts legacy single-round SHA-256 payload (v1 backward compatibility)', () {
      final crypto = SyncCryptoService.instance;
      const secret = '555555';
      const originalPayload = '{"type":"legacy_note","content":"Hello world"}';

      // Manually construct legacy encrypted payload using deriveLegacyKey
      final legacyKey = crypto.deriveLegacyKey(secret);
      final iv = enc.IV.fromLength(16);
      final encrypter = enc.Encrypter(enc.AES(legacyKey, mode: enc.AESMode.cbc));
      final encryptedData = encrypter.encrypt(originalPayload, iv: iv);
      final legacyJson = json.encode({
        'iv': iv.base64,
        'data': encryptedData.base64,
      });
      final legacyBase64Payload = base64.encode(utf8.encode(legacyJson));

      // Decrypt using standard decryptPayload
      final decrypted = crypto.decryptPayload(legacyBase64Payload, secret);
      expect(decrypted, originalPayload, reason: 'Legacy payloads must decrypt cleanly via fallback');
    });
  });

  group('SyncMergeService: Transaction LWW & UUID Duplication Guard', () {
    test('Merging updated manual transaction with matching UUID updates in place with 0 duplicates', () async {
      final now = DateTime.now();
      const txUuid = 'tx-uuid-12345';

      // 1. Insert local manual transaction
      final localTx = TransactionModel(
        amount: 25.0,
        description: 'Team Lunch',
        date: now,
        category: 'Food & Drinks',
        account: AccountType.daily,
        uuid: txUuid,
        dateModified: now,
      );
      final inserted = await transactionRepo.createTransaction(localTx);
      expect(inserted.id, isNotNull);

      // Verify 1 local transaction
      final initialRows = await db.query('transactions');
      expect(initialRows.length, 1);
      expect(initialRows.first['description'], 'Team Lunch');

      // 2. Peer updates transaction description and adds 10 minutes to dateModified
      final remoteUpdatedTime = now.add(const Duration(minutes: 10));
      final remoteData = {
        'transactions': [
          {
            'uuid': txUuid,
            'amount': 30.0,
            'description': 'Team Lunch Buffet',
            'date': now.toIso8601String(),
            'isExpense': 1,
            'category': 'Food & Drinks',
            'account': 'daily',
            'isAiRefined': 0,
            'dateModified': remoteUpdatedTime.toIso8601String(),
          }
        ]
      };

      // 3. Merge remote data
      final result = await SyncMergeService.instance.mergeRemoteData(remoteData);
      expect(result.transactionsMerged, 1);

      // 4. Assert local transaction was updated in place with zero duplicate records
      final finalRows = await db.query('transactions');
      expect(finalRows.length, 1, reason: 'Must not create duplicate rows when manual transaction details are edited');
      expect(finalRows.first['description'], 'Team Lunch Buffet');
      expect(finalRows.first['amount'], 30.0);
      expect(finalRows.first['uuid'], txUuid);
    });

    test('Merging soft-deleted remote transaction soft-deletes local transaction', () async {
      final now = DateTime.now();
      const txUuid = 'tx-uuid-to-delete';

      final localTx = TransactionModel(
        amount: 100.0,
        description: 'Subscription',
        date: now,
        category: 'Entertainment',
        uuid: txUuid,
        dateModified: now,
      );
      await transactionRepo.createTransaction(localTx);

      final deleteTime = now.add(const Duration(minutes: 5));
      final remoteData = {
        'transactions': [
          {
            'uuid': txUuid,
            'amount': 100.0,
            'description': 'Subscription',
            'date': now.toIso8601String(),
            'isExpense': 1,
            'category': 'Entertainment',
            'account': 'daily',
            'isAiRefined': 0,
            'deletedAt': deleteTime.toIso8601String(),
            'dateModified': deleteTime.toIso8601String(),
          }
        ]
      };

      final result = await SyncMergeService.instance.mergeRemoteData(remoteData);
      expect(result.transactionsMerged, 1);

      final finalRows = await db.query('transactions');
      expect(finalRows.length, 1);
      expect(finalRows.first['deletedAt'], deleteTime.toIso8601String());
    });
  });

  group('BackupService: AES-256 Encryption & Decryption Container', () {
    test('encryptBackupJson generates AES-256 container with no plaintext data', () {
      const rawJson = '{"notes": [{"title": "Confidential Note", "content": "Secret Information"}], "version": 11}';
      const passphrase = 'SuperSecretBackupPassword123!';

      final encryptedOutput = BackupService.encryptBackupJson(rawJson, passphrase);
      final container = json.decode(encryptedOutput) as Map<String, dynamic>;

      expect(container['version'], 2);
      expect(container['encrypted'], isTrue);
      expect(container['salt'], isNotNull);
      expect(container['iv'], isNotNull);
      expect(container['ciphertext'], isNotNull);

      // Ciphertext and JSON container must NOT leak plain text
      expect(encryptedOutput.contains('Confidential Note'), isFalse);
      expect(encryptedOutput.contains('Secret Information'), isFalse);
    });

    test('decryptBackupJson successfully round-trips encrypted backup with correct passphrase', () {
      const rawJson = '{"notes": [{"title": "My Note", "content": "Important Text"}], "version": 11}';
      const passphrase = 'MyCorrectPassphrase456!';

      final encryptedOutput = BackupService.encryptBackupJson(rawJson, passphrase);
      final container = json.decode(encryptedOutput) as Map<String, dynamic>;

      final decrypted = BackupService.decryptBackupJson(container, passphrase);
      expect(decrypted, rawJson);
    });

    test('decryptBackupJson fails with incorrect passphrase', () {
      const rawJson = '{"notes": [], "version": 11}';
      const passphrase = 'ValidPassword';

      final encryptedOutput = BackupService.encryptBackupJson(rawJson, passphrase);
      final container = json.decode(encryptedOutput) as Map<String, dynamic>;

      expect(
        () => BackupService.decryptBackupJson(container, 'WrongPassword'),
        throwsA(anything),
      );
    });
  });
}

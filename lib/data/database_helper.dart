import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/rich_text_utils.dart';
import 'database_constants.dart';
import 'database_seed.dart';

class DatabaseHelper {
  static const int _databaseVersion = 26;
  static const String _dbName = 'notes.db';
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static Future<Database>? _databaseFuture;

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  static const _keyStorageKey = 'db_encryption_key';

  DatabaseHelper._init();

  @visibleForTesting
  static void setMockDatabase(Database? db) {
    _database = db;
    _databaseFuture = db != null ? Future.value(db) : null;
  }

  @visibleForTesting
  Future<void> createTestDatabase(Database db) async {
    await _createDB(db, _databaseVersion);
  }

  @visibleForTesting
  Future<void> upgradeTestDatabase(Database db, int oldVersion, int newVersion) async {
    await _upgradeDB(db, oldVersion, newVersion);
  }

  Future<Database> get database {
    if (_database != null) return Future.value(_database!);
    
    _databaseFuture ??= _initDB(_dbName).then((db) {
      _database = db;
      return db;
    }).catchError((error) {
      _databaseFuture = null;
      throw error;
    });
    
    return _databaseFuture!;
  }

  static Future<String> _getOrCreateEncryptionKey({bool databaseFileExists = false}) async {
    String? key;
    int readAttempts = 0;
    while (readAttempts < 3) {
      readAttempts++;
      try {
        key = await _secureStorage.read(key: _keyStorageKey);
        if (key != null && key.isNotEmpty) break;
      } catch (e) {
        debugPrint('[DatabaseHelper] Keystore read attempt $readAttempts failed: $e');
      }
      if (readAttempts < 3) {
        await Future.delayed(Duration(milliseconds: 100 * (1 << (readAttempts - 1))));
      }
    }

    final prefs = await SharedPreferences.getInstance();
    
    // Migrate key from SharedPreferences if it exists, then delete it to prevent leakage
    final backupKey = prefs.getString('db_encryption_key_backup');
    if (backupKey != null && backupKey.isNotEmpty) {
      if (key == null || key.isEmpty) {
        key = backupKey;
        try {
          await _secureStorage.write(key: _keyStorageKey, value: key);
        } catch (_) {}
      }
      await prefs.remove('db_encryption_key_backup');
    }

    if (key == null || key.isEmpty) {
      if (databaseFileExists) {
        debugPrint('[DatabaseHelper] ERROR: Database file exists on disk, but Keystore key could not be retrieved. Halting key generation to prevent data loss.');
        throw const SecureStorageKeyMissingException();
      }

      final random = Random.secure();
      final bytes = List<int>.generate(32, (_) => random.nextInt(256));
      key = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      
      try {
        await _secureStorage.write(key: _keyStorageKey, value: key);
        final verified = await _secureStorage.read(key: _keyStorageKey);
        if (verified != key) {
          debugPrint('[DatabaseHelper] Warning: Keystore write verification mismatch.');
        }
      } catch (e) {
        debugPrint('[DatabaseHelper] Warning: Failed to persist encryption key to secure storage: $e');
      }
    }
    return key;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    final dbFile = File(path);
    final dbExists = await dbFile.exists();

    final password = await _getOrCreateEncryptionKey(databaseFileExists: dbExists);

    if (dbExists) {
      if (await _isUnencryptedDb(path)) {
        await _migrateToEncrypted(path, password);
      }
      await _checkAndCreatePreMigrationSnapshot(path, password, _databaseVersion);
    }

    int attempts = 0;
    const maxAttempts = 5;
    while (true) {
      attempts++;
      try {
        return await openDatabase(
          path,
          password: password,
          version: _databaseVersion,
          onCreate: _createDB,
          onUpgrade: _upgradeDB,
          onOpen: _onOpenDB,
        );
      } catch (e) {
        if (_isTransientLockError(e)) {
          debugPrint('[DatabaseHelper] Database busy or locked on attempt $attempts of $maxAttempts: $e');
          if (attempts < maxAttempts) {
            final delayMs = 100 * (1 << (attempts - 1));
            await Future.delayed(Duration(milliseconds: delayMs));
            continue;
          }
          debugPrint('[DatabaseHelper] Database remained locked after $maxAttempts attempts. Aborting without destructive action.');
          rethrow;
        }

        final isCorrupt = e.toString().contains('code 26') ||
            e.toString().contains('SQLITE_NOTADB') ||
            e.toString().contains('malformed') ||
            e.toString().contains('file is not a database');

        if (isCorrupt) {
          debugPrint('[DatabaseHelper] Corrupt or unreadable database detected ($e), checking snapshot recovery...');
          
          final hasData = await dbFile.exists() && (await dbFile.length()) > 0;

          // Attempt recovery from rolling snapshot first without destroying the current file
          final recovered = await _tryRecoverFromLatestSnapshot(path);
          if (recovered) {
            debugPrint('[DatabaseHelper] Recovered database from latest rolling snapshot');
            return await openDatabase(
              path,
              password: password,
              version: _databaseVersion,
              onCreate: _createDB,
              onUpgrade: _upgradeDB,
              onOpen: _onOpenDB,
            );
          }

          // If recovery was not possible and the file contains data, DO NOT wipe or create an empty DB!
          if (hasData) {
            debugPrint('[DatabaseHelper] Refusing to overwrite non-empty database ($path). Halting without destructive action to protect user data.');
            throw DatabaseAuthException(
              'Database file exists with valid data but could not be decrypted or opened: $e. Preserving file to prevent data loss.',
            );
          }

          // Only if the file is empty or missing do we rename and create fresh DB
          try {
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            if (await dbFile.exists()) await dbFile.rename('${path}_corrupt_backup_$timestamp');
            final walFile = File('$path-wal');
            final shmFile = File('$path-shm');
            if (await walFile.exists()) await walFile.rename('$path-wal_corrupt_backup_$timestamp');
            if (await shmFile.exists()) await shmFile.rename('$path-shm_corrupt_backup_$timestamp');
          } catch (backupError) {
            debugPrint('[DatabaseHelper] Could not backup corrupt file: $backupError');
          }

          return await openDatabase(
            path,
            password: password,
            version: _databaseVersion,
            onCreate: _createDB,
            onUpgrade: _upgradeDB,
            onOpen: _onOpenDB,
          );
        }

        rethrow;
      }
    }
  }

  static bool _isTransientLockError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('busy') ||
        msg.contains('locked') ||
        msg.contains('code 5') ||
        msg.contains('code 6') ||
        msg.contains('code 261') ||
        msg.contains('code 517') ||
        msg.contains('sqlite_busy') ||
        msg.contains('sqlite_locked');
  }

  static Future<void> _checkAndCreatePreMigrationSnapshot(
    String path,
    String password,
    int targetVersion,
  ) async {
    Database? testDb;
    try {
      testDb = await openDatabase(
        path,
        password: password,
        readOnly: true,
        singleInstance: false,
      );
      final result = await testDb.rawQuery('PRAGMA user_version');
      final currentVersion = (result.first.values.first as num?)?.toInt() ?? 0;
      await testDb.close();
      testDb = null;

      if (currentVersion > 0 && currentVersion < targetVersion) {
        debugPrint('[DatabaseHelper] DB version $currentVersion < target $targetVersion. Generating pre-migration snapshot...');
        final dbPath = await getDatabasesPath();
        final snapshotsDir = Directory(join(dbPath, 'snapshots'));
        if (!await snapshotsDir.exists()) {
          await snapshotsDir.create(recursive: true);
        }
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final snapshotFile = File(join(
          snapshotsDir.path,
          'snapshot_pre_migration_v${currentVersion}_to_v${targetVersion}_$timestamp.db',
        ));

        Database? exportDb;
        try {
          exportDb = await openDatabase(path, password: password, singleInstance: false);
          try {
            await exportDb.rawQuery('PRAGMA wal_checkpoint(PASSIVE);');
          } catch (_) {}
          await exportDb.execute("ATTACH DATABASE '${snapshotFile.path}' AS pre_mig_snap KEY '$password'");
          await exportDb.rawQuery("SELECT sqlcipher_export('pre_mig_snap')");
          await exportDb.execute("DETACH DATABASE pre_mig_snap");
          debugPrint('[DatabaseHelper] Created pre-migration snapshot: ${snapshotFile.path}');
          await _rotateSnapshots(snapshotsDir);
        } finally {
          await exportDb?.close();
        }
      }
    } catch (e) {
      debugPrint('[DatabaseHelper] Pre-migration check error: $e');
    } finally {
      await testDb?.close();
    }
  }

  static Future<bool> _tryRecoverFromLatestSnapshot(String targetDbPath) async {
    try {
      final dbPath = await getDatabasesPath();
      final snapshotsDir = Directory(join(dbPath, 'snapshots'));
      if (!await snapshotsDir.exists()) return false;
      final files = <File>[];
      await for (final entity in snapshotsDir.list()) {
        if (entity is File && entity.path.endsWith('.db')) {
          files.add(entity);
        }
      }
      if (files.isEmpty) return false;
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      final latest = files.first;
      await latest.copy(targetDbPath);
      final walFile = File('$targetDbPath-wal');
      final shmFile = File('$targetDbPath-shm');
      if (await walFile.exists()) await walFile.delete();
      if (await shmFile.exists()) await shmFile.delete();
      return true;
    } catch (e) {
      debugPrint('[DatabaseHelper] Recovery from latest snapshot failed: $e');
      return false;
    }
  }


  static Future<void> _onOpenDB(Database db) async {
    try {
      await db.rawQuery('PRAGMA journal_mode = WAL;');
      await db.rawQuery('PRAGMA synchronous = NORMAL;');
      await db.rawQuery('PRAGMA busy_timeout = 5000;');

      // Performance Indexes
      await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_deleted ON notes(deletedAt);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_modified ON notes(dateModified);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_modified_deleted ON notes(dateModified, deletedAt);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_category_deleted ON notes(category, deletedAt, isArchived);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_note_tags_tag ON note_tags(tag_name);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_smsid ON transactions(smsId);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_deleted ON transactions(deletedAt);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_active_date ON transactions(deletedAt, date DESC);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_cat_deleted ON transactions(category, deletedAt);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_date_account ON transactions(date, account);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_tombstones_smsid ON deleted_transaction_sms_ids(smsId);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_recurring_rules_nextdue ON recurring_rules(nextDue);');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_split_bills_deleted ON ${TableNames.splitBills}(${SplitBillFields.deletedAt});');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_split_bills_txid ON ${TableNames.splitBills}(${SplitBillFields.transactionId});');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_split_bills_active ON ${TableNames.splitBills}(${SplitBillFields.deletedAt}, ${SplitBillFields.status});');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_split_participants_bill ON ${TableNames.splitParticipants}(${SplitParticipantFields.billId});');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_split_participants_contact ON ${TableNames.splitParticipants}(${SplitParticipantFields.contactName});');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_split_participants_settletx ON ${TableNames.splitParticipants}(${SplitParticipantFields.settlementTransactionId});');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_period_logs_start ON ${TableNames.periodLogs}(${PeriodLogFields.startDate});');

      final cols = await db.rawQuery('PRAGMA table_info(${TableNames.transactions})');
      final hasAiRefinedCol = cols.any((col) => col['name'] == 'isAiRefined');
      if (!hasAiRefinedCol) {
        await db.execute("ALTER TABLE ${TableNames.transactions} ADD COLUMN isAiRefined INTEGER NOT NULL DEFAULT 0");
      }
      final hasUuid = cols.any((col) => col['name'] == 'uuid');
      if (!hasUuid) {
        await db.execute('ALTER TABLE ${TableNames.transactions} ADD COLUMN uuid TEXT');
      }
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_uuid ON ${TableNames.transactions}(uuid);');
      await db.execute("UPDATE ${TableNames.transactions} SET uuid = lower(hex(randomblob(16))) WHERE uuid IS NULL OR uuid = '';");

      final participantCols = await db.rawQuery('PRAGMA table_info(${TableNames.splitParticipants})');
      final hasSettlementTxCol = participantCols.any((col) => col['name'] == SplitParticipantFields.settlementTransactionId);
      if (!hasSettlementTxCol) {
        await db.execute('ALTER TABLE ${TableNames.splitParticipants} ADD COLUMN ${SplitParticipantFields.settlementTransactionId} INTEGER');
      }

      await ensureRecurringRulesColumns(db);
    } catch (e) {
      debugPrint('[DatabaseHelper] PRAGMA & Index creation onOpen warning: $e');
    }
  }


  static Future<bool> _isUnencryptedDb(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;
    try {
      final bytes = await file.openRead(0, 16).first;
      final header = String.fromCharCodes(bytes);
      if (!header.startsWith('SQLite format 3')) return false;
    } catch (_) {
      return false;
    }

    Database? db;
    try {
      db = await openDatabase(path, password: '', readOnly: true, singleInstance: false);
      await db.rawQuery('SELECT count(*) FROM sqlite_master');
      return true;
    } catch (_) {
      return false;
    } finally {
      await db?.close();
    }
  }

  static Future<void> _migrateToEncrypted(String path, String password) async {
    final encryptedPath = '$path.encrypted';
    try {
      final oldDb = await openDatabase(path, singleInstance: false);
      final versionResult = await oldDb.rawQuery("PRAGMA user_version");
      final userVersion = versionResult.first.values.first as int;

      await oldDb.execute("ATTACH DATABASE '$encryptedPath' AS encrypted KEY '$password'");
      await oldDb.rawQuery("SELECT sqlcipher_export('encrypted')");
      await oldDb.execute("PRAGMA encrypted.user_version = $userVersion");
      await oldDb.execute("DETACH DATABASE encrypted");
      await oldDb.close();

      final oldFile = File(path);
      final encFile = File(encryptedPath);
      if (await oldFile.exists()) await oldFile.delete();
      await encFile.rename(path);
    } catch (e) {
      final encFile = File(encryptedPath);
      if (await encFile.exists()) await encFile.delete();
      rethrow;
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${TableNames.notes} (
        ${NoteFields.id} TEXT PRIMARY KEY,
        ${NoteFields.title} TEXT NOT NULL,
        ${NoteFields.content} TEXT NOT NULL,
        ${NoteFields.dateCreated} TEXT NOT NULL,
        ${NoteFields.dateModified} TEXT NOT NULL,
        ${NoteFields.color} INTEGER NOT NULL,
        ${NoteFields.isPinned} INTEGER NOT NULL,
        ${NoteFields.isArchived} INTEGER NOT NULL DEFAULT 0,
        ${NoteFields.imagePath} TEXT,
        ${NoteFields.category} TEXT,
        ${NoteFields.tags} TEXT,
        ${NoteFields.previewText} TEXT,
        ${NoteFields.deletedAt} TEXT,
        ${NoteFields.reminderAt} TEXT,
        ${NoteFields.isLocked} INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${TableNames.tags} (
        ${TagFields.name} TEXT PRIMARY KEY,
        ${TagFields.color} INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS note_tags (
        note_id TEXT NOT NULL,
        tag_name TEXT NOT NULL,
        PRIMARY KEY (note_id, tag_name),
        FOREIGN KEY (note_id) REFERENCES ${TableNames.notes} (${NoteFields.id}) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${TableNames.transactions} (
        _id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        date TEXT NOT NULL,
        isExpense INTEGER NOT NULL,
        category TEXT NOT NULL DEFAULT 'Other',
        smsId TEXT,
        deletedAt TEXT,
        account TEXT NOT NULL DEFAULT 'daily',
        isAiRefined INTEGER NOT NULL DEFAULT 0,
        dateModified TEXT,
        uuid TEXT
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_transactions_smsId ON ${TableNames.transactions}(smsId) WHERE smsId IS NOT NULL',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${TableNames.deletedTransactionSmsIds} (
        smsId TEXT PRIMARY KEY,
        deletedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${TableNames.categoryDefinitions} (
        ${CategoryFields.name} TEXT PRIMARY KEY,
        ${CategoryFields.color} INTEGER NOT NULL,
        ${CategoryFields.keywords} TEXT NOT NULL DEFAULT '[]',
        ${CategoryFields.isBuiltIn} INTEGER NOT NULL DEFAULT 0,
        ${CategoryFields.iconCodePoint} INTEGER
      )
    ''');
    await DatabaseSeed.seedBuiltInCategories(db);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${TableNames.smsContacts} (
        ${SmsContactFields.id} TEXT PRIMARY KEY,
        ${SmsContactFields.senderIds} TEXT NOT NULL DEFAULT '[]',
        ${SmsContactFields.label} TEXT,
        ${SmsContactFields.isBuiltIn} INTEGER NOT NULL DEFAULT 0,
        ${SmsContactFields.isBlocked} INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await DatabaseSeed.seedBuiltInSmsContacts(db);

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${TableNames.periodLogs} (
        ${PeriodLogFields.id} TEXT PRIMARY KEY,
        ${PeriodLogFields.startDate} TEXT NOT NULL,
        ${PeriodLogFields.endDate} TEXT,
        ${PeriodLogFields.intensity} TEXT NOT NULL,
        ${PeriodLogFields.notes} TEXT NOT NULL DEFAULT '',
        ${PeriodLogFields.symptoms} TEXT NOT NULL DEFAULT '[]'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${TableNames.recurringRules} (
        ${RecurringRuleFields.id} TEXT PRIMARY KEY,
        ${RecurringRuleFields.description} TEXT NOT NULL,
        ${RecurringRuleFields.amount} REAL NOT NULL,
        ${RecurringRuleFields.category} TEXT NOT NULL,
        ${RecurringRuleFields.isExpense} INTEGER NOT NULL,
        ${RecurringRuleFields.frequency} TEXT NOT NULL,
        ${RecurringRuleFields.nextDue} TEXT NOT NULL,
        ${RecurringRuleFields.account} TEXT NOT NULL DEFAULT 'daily',
        ${RecurringRuleFields.anchorDay} INTEGER
      )
    ''');

    // tombstone table — must match the _upgradeDB < 18 migration
    await db.execute('CREATE TABLE IF NOT EXISTS deleted_notes (id TEXT PRIMARY KEY, deletedAt TEXT NOT NULL)');
    await db.execute('CREATE TABLE IF NOT EXISTS ${TableNames.deletedPeriodLogs} (id TEXT PRIMARY KEY, deletedAt TEXT NOT NULL)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${TableNames.splitBills} (
        ${SplitBillFields.id} TEXT PRIMARY KEY,
        ${SplitBillFields.transactionId} INTEGER,
        ${SplitBillFields.title} TEXT NOT NULL,
        ${SplitBillFields.totalAmount} REAL NOT NULL,
        ${SplitBillFields.payerName} TEXT NOT NULL,
        ${SplitBillFields.isPayerUser} INTEGER NOT NULL DEFAULT 1,
        ${SplitBillFields.splitMode} TEXT NOT NULL DEFAULT 'equal',
        ${SplitBillFields.groupTag} TEXT,
        ${SplitBillFields.date} TEXT NOT NULL,
        ${SplitBillFields.notes} TEXT,
        ${SplitBillFields.receiptImagePath} TEXT,
        ${SplitBillFields.status} TEXT NOT NULL DEFAULT 'unsettled',
        ${SplitBillFields.deletedAt} TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${TableNames.splitParticipants} (
        ${SplitParticipantFields.id} TEXT PRIMARY KEY,
        ${SplitParticipantFields.billId} TEXT NOT NULL,
        ${SplitParticipantFields.contactName} TEXT NOT NULL,
        ${SplitParticipantFields.shareAmount} REAL NOT NULL,
        ${SplitParticipantFields.hasPaid} INTEGER NOT NULL DEFAULT 0,
        ${SplitParticipantFields.paidAt} TEXT,
        ${SplitParticipantFields.settlementTransactionId} INTEGER,
        FOREIGN KEY (${SplitParticipantFields.billId}) REFERENCES ${TableNames.splitBills} (${SplitBillFields.id}) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${TableNames.splitContacts} (
        ${SplitContactFields.name} TEXT PRIMARY KEY,
        ${SplitContactFields.phoneNumber} TEXT,
        ${SplitContactFields.colorValue} INTEGER NOT NULL,
        ${SplitContactFields.lastUsed} TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${TableNames.savingsGoals} (
        ${SavingsGoalFields.id} TEXT PRIMARY KEY,
        ${SavingsGoalFields.title} TEXT NOT NULL,
        ${SavingsGoalFields.targetAmount} REAL NOT NULL,
        ${SavingsGoalFields.currentAmount} REAL NOT NULL DEFAULT 0.0,
        ${SavingsGoalFields.targetDate} TEXT,
        ${SavingsGoalFields.targetMonths} INTEGER NOT NULL DEFAULT 6,
        ${SavingsGoalFields.monthlyContribution} REAL NOT NULL DEFAULT 0.0,
        ${SavingsGoalFields.category} TEXT NOT NULL DEFAULT 'Savings',
        ${SavingsGoalFields.account} TEXT NOT NULL DEFAULT 'savings',
        ${SavingsGoalFields.colorValue} INTEGER NOT NULL DEFAULT 0xFF00796B,
        ${SavingsGoalFields.iconCodePoint} INTEGER NOT NULL DEFAULT 0xe57f,
        ${SavingsGoalFields.isCompleted} INTEGER NOT NULL DEFAULT 0,
        ${SavingsGoalFields.createdAt} TEXT NOT NULL,
        ${SavingsGoalFields.completedAt} TEXT,
        ${SavingsGoalFields.deletedAt} TEXT
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE ${TableNames.notes} ADD COLUMN ${NoteFields.isArchived} INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE ${TableNames.notes} ADD COLUMN ${NoteFields.deletedAt} TEXT');
    }
    if (oldVersion < 3) await db.execute('ALTER TABLE ${TableNames.notes} ADD COLUMN ${NoteFields.tags} TEXT');
    if (oldVersion < 4) await db.execute('CREATE TABLE IF NOT EXISTS ${TableNames.tags} (${TagFields.name} TEXT PRIMARY KEY, ${TagFields.color} INTEGER NOT NULL)');
    if (oldVersion < 5) await db.execute('CREATE TABLE IF NOT EXISTS ${TableNames.transactions} (_id INTEGER PRIMARY KEY AUTOINCREMENT, amount REAL NOT NULL, description TEXT NOT NULL, date TEXT NOT NULL, isExpense INTEGER NOT NULL)');
    if (oldVersion < 6) {
      await db.execute("ALTER TABLE ${TableNames.transactions} ADD COLUMN category TEXT NOT NULL DEFAULT 'Other'");
      await db.execute('ALTER TABLE ${TableNames.transactions} ADD COLUMN smsId TEXT');
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_transactions_smsId ON ${TableNames.transactions}(smsId) WHERE smsId IS NOT NULL');
    }
    if (oldVersion < 7) {
      await db.execute("CREATE TABLE IF NOT EXISTS ${TableNames.categoryDefinitions} (${CategoryFields.name} TEXT PRIMARY KEY, ${CategoryFields.color} INTEGER NOT NULL, ${CategoryFields.keywords} TEXT NOT NULL DEFAULT '[]', ${CategoryFields.isBuiltIn} INTEGER NOT NULL DEFAULT 0)");
      await DatabaseSeed.seedBuiltInCategories(db);
    }
    if (oldVersion < 8) {
      await db.execute("INSERT OR IGNORE INTO ${TableNames.categoryDefinitions} (${CategoryFields.name}, ${CategoryFields.color}, ${CategoryFields.keywords}, ${CategoryFields.isBuiltIn}) VALUES ('Payments', 0xFF795548, '[\"koko instalment\", \"koko installment\", \"instalment\", \"installment\", \"emi\", \"koko\", \"loan\", \"repayment\", \"credit card\", \"card payment\", \"hire purchase\"]', 1)");
      await db.execute("INSERT OR IGNORE INTO ${TableNames.categoryDefinitions} (${CategoryFields.name}, ${CategoryFields.color}, ${CategoryFields.keywords}, ${CategoryFields.isBuiltIn}) VALUES ('Deposit', 0xFF00897B, '[\"crm deposit\", \"cash deposit\", \"deposit\", \"credited\", \"salary\", \"income\"]', 1)");
    }
    if (oldVersion < 9) await db.execute('CREATE TABLE IF NOT EXISTS sms_whitelist (sender TEXT PRIMARY KEY)');
    if (oldVersion < 10) {
      await db.execute("CREATE TABLE IF NOT EXISTS ${TableNames.smsContacts} (${SmsContactFields.id} TEXT PRIMARY KEY, ${SmsContactFields.senderIds} TEXT NOT NULL DEFAULT '[]', ${SmsContactFields.label} TEXT, ${SmsContactFields.isBuiltIn} INTEGER NOT NULL DEFAULT 0, ${SmsContactFields.isBlocked} INTEGER NOT NULL DEFAULT 0)");
      await DatabaseSeed.seedBuiltInSmsContacts(db);
      final hasOld = (await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='sms_whitelist'")).isNotEmpty;
      if (hasOld) {
        final oldRows = await db.query('sms_whitelist');
        for (final row in oldRows) {
          final sender = row['sender'] as String;
          await db.insert(TableNames.smsContacts, {SmsContactFields.id: sender, SmsContactFields.senderIds: '["$sender"]', SmsContactFields.label: null, SmsContactFields.isBuiltIn: 0, SmsContactFields.isBlocked: 0}, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        await db.execute('DROP TABLE sms_whitelist');
      }
    }
    if (oldVersion < 11) await db.execute("CREATE TABLE IF NOT EXISTS ${TableNames.periodLogs} (${PeriodLogFields.id} TEXT PRIMARY KEY, ${PeriodLogFields.startDate} TEXT NOT NULL, ${PeriodLogFields.endDate} TEXT, ${PeriodLogFields.intensity} TEXT NOT NULL, ${PeriodLogFields.notes} TEXT NOT NULL DEFAULT '')");
    if (oldVersion < 12) {
      await db.execute('ALTER TABLE ${TableNames.periodLogs} RENAME TO period_logs_old');
      await db.execute("CREATE TABLE ${TableNames.periodLogs} (${PeriodLogFields.id} TEXT PRIMARY KEY, ${PeriodLogFields.startDate} TEXT NOT NULL, ${PeriodLogFields.endDate} TEXT, ${PeriodLogFields.intensity} TEXT NOT NULL, ${PeriodLogFields.notes} TEXT NOT NULL DEFAULT '')");
      await db.execute("INSERT INTO ${TableNames.periodLogs} (${PeriodLogFields.id}, ${PeriodLogFields.startDate}, ${PeriodLogFields.endDate}, ${PeriodLogFields.intensity}, ${PeriodLogFields.notes}) SELECT ${PeriodLogFields.id}, ${PeriodLogFields.startDate}, NULLIF(${PeriodLogFields.endDate}, ''), ${PeriodLogFields.intensity}, ${PeriodLogFields.notes} FROM period_logs_old");
      await db.execute('DROP TABLE period_logs_old');
    }
    if (oldVersion < 13) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS note_tags (
          note_id TEXT NOT NULL,
          tag_name TEXT NOT NULL,
          PRIMARY KEY (note_id, tag_name),
          FOREIGN KEY (note_id) REFERENCES ${TableNames.notes} (${NoteFields.id}) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 14) {
      await db.execute('ALTER TABLE ${TableNames.notes} ADD COLUMN ${NoteFields.previewText} TEXT');
      // Populate previews for existing notes
      final notes = await db.query(TableNames.notes, columns: [NoteFields.id, NoteFields.content]);
      for (final note in notes) {
        final id = note[NoteFields.id] as String;
        final content = note[NoteFields.content] as String;
        final preview = RichTextUtils.contentToPlainText(content, maxLines: 6);
        await db.update(TableNames.notes, {NoteFields.previewText: preview}, where: '${NoteFields.id} = ?', whereArgs: [id]);
      }
    }
    if (oldVersion < 15) {
      await db.execute('ALTER TABLE ${TableNames.notes} ADD COLUMN ${NoteFields.reminderAt} TEXT');
      await db.execute('ALTER TABLE ${TableNames.notes} ADD COLUMN ${NoteFields.isLocked} INTEGER NOT NULL DEFAULT 0');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${TableNames.recurringRules} (
          ${RecurringRuleFields.id} TEXT PRIMARY KEY,
          ${RecurringRuleFields.description} TEXT NOT NULL,
          ${RecurringRuleFields.amount} REAL NOT NULL,
          ${RecurringRuleFields.category} TEXT NOT NULL,
          ${RecurringRuleFields.isExpense} INTEGER NOT NULL,
          ${RecurringRuleFields.frequency} TEXT NOT NULL,
          ${RecurringRuleFields.nextDue} TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 16) {
      await db.execute("ALTER TABLE ${TableNames.periodLogs} ADD COLUMN ${PeriodLogFields.symptoms} TEXT NOT NULL DEFAULT '[]'");
    }
    if (oldVersion < 17) {
      final cols = await db.rawQuery('PRAGMA table_info(${TableNames.categoryDefinitions})');
      final hasIconCol = cols.any((col) => col['name'] == CategoryFields.iconCodePoint);
      if (!hasIconCol) {
        await db.execute('ALTER TABLE ${TableNames.categoryDefinitions} ADD COLUMN ${CategoryFields.iconCodePoint} INTEGER');
      }
    }
    if (oldVersion < 18) {
      await db.execute('CREATE TABLE IF NOT EXISTS deleted_notes (id TEXT PRIMARY KEY, deletedAt TEXT NOT NULL)');
    }
    if (oldVersion < 19) {
      await db.execute('ALTER TABLE ${TableNames.transactions} ADD COLUMN deletedAt TEXT');
      await db.execute('CREATE TABLE IF NOT EXISTS ${TableNames.deletedTransactionSmsIds} (smsId TEXT PRIMARY KEY, deletedAt TEXT NOT NULL)');
    }
    if (oldVersion < 20) {
      final cols = await db.rawQuery('PRAGMA table_info(${TableNames.transactions})');
      final hasAccountCol = cols.any((col) => col['name'] == 'account');
      if (!hasAccountCol) {
        await db.execute("ALTER TABLE ${TableNames.transactions} ADD COLUMN account TEXT NOT NULL DEFAULT 'daily'");
      }
    }
    if (oldVersion < 21) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${TableNames.splitBills} (
          ${SplitBillFields.id} TEXT PRIMARY KEY,
          ${SplitBillFields.transactionId} INTEGER,
          ${SplitBillFields.title} TEXT NOT NULL,
          ${SplitBillFields.totalAmount} REAL NOT NULL,
          ${SplitBillFields.payerName} TEXT NOT NULL,
          ${SplitBillFields.isPayerUser} INTEGER NOT NULL DEFAULT 1,
          ${SplitBillFields.splitMode} TEXT NOT NULL DEFAULT 'equal',
          ${SplitBillFields.groupTag} TEXT,
          ${SplitBillFields.date} TEXT NOT NULL,
          ${SplitBillFields.notes} TEXT,
          ${SplitBillFields.receiptImagePath} TEXT,
          ${SplitBillFields.status} TEXT NOT NULL DEFAULT 'unsettled',
          ${SplitBillFields.deletedAt} TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${TableNames.splitParticipants} (
          ${SplitParticipantFields.id} TEXT PRIMARY KEY,
          ${SplitParticipantFields.billId} TEXT NOT NULL,
          ${SplitParticipantFields.contactName} TEXT NOT NULL,
          ${SplitParticipantFields.shareAmount} REAL NOT NULL,
          ${SplitParticipantFields.hasPaid} INTEGER NOT NULL DEFAULT 0,
          ${SplitParticipantFields.paidAt} TEXT,
          FOREIGN KEY (${SplitParticipantFields.billId}) REFERENCES ${TableNames.splitBills} (${SplitBillFields.id}) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${TableNames.splitContacts} (
          ${SplitContactFields.name} TEXT PRIMARY KEY,
          ${SplitContactFields.phoneNumber} TEXT,
          ${SplitContactFields.colorValue} INTEGER NOT NULL,
          ${SplitContactFields.lastUsed} TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 22) {
      final cols = await db.rawQuery('PRAGMA table_info(${TableNames.transactions})');
      final hasAiRefinedCol = cols.any((col) => col['name'] == 'isAiRefined');
      if (!hasAiRefinedCol) {
        await db.execute("ALTER TABLE ${TableNames.transactions} ADD COLUMN isAiRefined INTEGER NOT NULL DEFAULT 0");
      }
    }
    if (oldVersion < 23) {
      await db.execute('CREATE TABLE IF NOT EXISTS ${TableNames.deletedPeriodLogs} (id TEXT PRIMARY KEY, deletedAt TEXT NOT NULL)');
    }
    if (oldVersion < 24) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${TableNames.savingsGoals} (
          ${SavingsGoalFields.id} TEXT PRIMARY KEY,
          ${SavingsGoalFields.title} TEXT NOT NULL,
          ${SavingsGoalFields.targetAmount} REAL NOT NULL,
          ${SavingsGoalFields.currentAmount} REAL NOT NULL DEFAULT 0.0,
          ${SavingsGoalFields.targetDate} TEXT,
          ${SavingsGoalFields.targetMonths} INTEGER NOT NULL DEFAULT 6,
          ${SavingsGoalFields.monthlyContribution} REAL NOT NULL DEFAULT 0.0,
          ${SavingsGoalFields.category} TEXT NOT NULL DEFAULT 'Savings',
          ${SavingsGoalFields.account} TEXT NOT NULL DEFAULT 'savings',
          ${SavingsGoalFields.colorValue} INTEGER NOT NULL DEFAULT 0xFF00796B,
          ${SavingsGoalFields.iconCodePoint} INTEGER NOT NULL DEFAULT 0xe57f,
          ${SavingsGoalFields.isCompleted} INTEGER NOT NULL DEFAULT 0,
          ${SavingsGoalFields.createdAt} TEXT NOT NULL,
          ${SavingsGoalFields.completedAt} TEXT,
          ${SavingsGoalFields.deletedAt} TEXT
        )
      ''');
    }
    if (oldVersion < 25) {
      final cols = await db.rawQuery('PRAGMA table_info(${TableNames.splitParticipants})');
      final hasCol = cols.any((col) => col['name'] == SplitParticipantFields.settlementTransactionId);
      if (!hasCol) {
        await db.execute('ALTER TABLE ${TableNames.splitParticipants} ADD COLUMN ${SplitParticipantFields.settlementTransactionId} INTEGER');
      }
    }
    if (oldVersion < 26) {
      final cols = await db.rawQuery('PRAGMA table_info(${TableNames.transactions})');
      if (cols.isNotEmpty) {
        final hasDateModified = cols.any((col) => col['name'] == 'dateModified');
        if (!hasDateModified) {
          await db.execute('ALTER TABLE ${TableNames.transactions} ADD COLUMN dateModified TEXT');
          await db.execute('UPDATE ${TableNames.transactions} SET dateModified = date WHERE dateModified IS NULL');
        }
        final hasUuid = cols.any((col) => col['name'] == 'uuid');
        if (!hasUuid) {
          await db.execute('ALTER TABLE ${TableNames.transactions} ADD COLUMN uuid TEXT');
        }
      }
    }
    await ensureRecurringRulesColumns(db);
  }

  static Future<void> ensureRecurringRulesColumns(Database db) async {
    try {
      final cols = await db.rawQuery('PRAGMA table_info(${TableNames.recurringRules})');
      if (cols.isEmpty) return;
      final hasAccountCol = cols.any((col) => col['name'] == RecurringRuleFields.account);
      if (!hasAccountCol) {
        await db.execute("ALTER TABLE ${TableNames.recurringRules} ADD COLUMN ${RecurringRuleFields.account} TEXT NOT NULL DEFAULT 'daily'");
      }
      final hasAnchorDayCol = cols.any((col) => col['name'] == RecurringRuleFields.anchorDay);
      if (!hasAnchorDayCol) {
        await db.execute("ALTER TABLE ${TableNames.recurringRules} ADD COLUMN ${RecurringRuleFields.anchorDay} INTEGER");
      }
    } catch (_) {}
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
      _databaseFuture = null;
    }
  }

  /// Creates a local rolling snapshot before P2P sync remote merge runs.
  Future<String?> createPreSyncSnapshot() async {
    try {
      final db = await database;
      final dbPath = await getDatabasesPath();
      final snapshotsDir = Directory(join(dbPath, 'snapshots'));
      if (!await snapshotsDir.exists()) {
        await snapshotsDir.create(recursive: true);
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final snapshotPath = join(snapshotsDir.path, 'snapshot_pre_sync_$timestamp.db');
      final password = await _getOrCreateEncryptionKey(databaseFileExists: true);

      try {
        await db.rawQuery('PRAGMA wal_checkpoint(PASSIVE);');
      } catch (_) {}

      final alias = 'pre_sync_${DateTime.now().microsecondsSinceEpoch}';
      await db.execute("ATTACH DATABASE '$snapshotPath' AS $alias KEY '$password'");
      try {
        await db.rawQuery("SELECT sqlcipher_export('$alias')");
      } finally {
        await db.execute("DETACH DATABASE $alias");
      }
      debugPrint('[DatabaseHelper] Created pre-sync snapshot: $snapshotPath');
      await _rotateSnapshots(snapshotsDir);
      return snapshotPath;
    } catch (e) {
      debugPrint('[DatabaseHelper] Pre-sync snapshot failed: $e');
      return null;
    }
  }

  /// Creates a user-initiated manual database snapshot.
  Future<String?> createManualSnapshot() async {
    try {
      final db = await database;
      final dbPath = await getDatabasesPath();
      final snapshotsDir = Directory(join(dbPath, 'snapshots'));
      if (!await snapshotsDir.exists()) {
        await snapshotsDir.create(recursive: true);
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final snapshotPath = join(snapshotsDir.path, 'snapshot_manual_$timestamp.db');
      final password = await _getOrCreateEncryptionKey(databaseFileExists: true);

      try {
        await db.rawQuery('PRAGMA wal_checkpoint(PASSIVE);');
      } catch (_) {}

      final alias = 'manual_snap_${DateTime.now().microsecondsSinceEpoch}';
      await db.execute("ATTACH DATABASE '$snapshotPath' AS $alias KEY '$password'");
      try {
        await db.rawQuery("SELECT sqlcipher_export('$alias')");
      } finally {
        await db.execute("DETACH DATABASE $alias");
      }
      debugPrint('[DatabaseHelper] Created manual snapshot: $snapshotPath');
      await _rotateSnapshots(snapshotsDir);
      return snapshotPath;
    } catch (e) {
      debugPrint('[DatabaseHelper] Manual snapshot failed: $e');
      return null;
    }
  }

  @visibleForTesting
  static Future<void> rotateSnapshotsForTest(Directory snapshotsDir) => _rotateSnapshots(snapshotsDir);

  static Future<void> _rotateSnapshots(Directory snapshotsDir) async {
    try {
      if (!await snapshotsDir.exists()) return;
      final files = <File>[];
      await for (final entity in snapshotsDir.list()) {
        if (entity is File && entity.path.endsWith('.db')) {
          files.add(entity);
        }
      }
      if (files.length > 5) {
        files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
        for (final old in files.skip(5)) {
          try {
            await old.delete();
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[DatabaseHelper] Snapshot rotation error: $e');
    }
  }

  /// Lists all available rolling and manual snapshots.
  Future<List<DatabaseSnapshotInfo>> getAvailableSnapshots() async {
    final list = <DatabaseSnapshotInfo>[];
    try {
      final dbPath = await getDatabasesPath();
      final snapshotsDir = Directory(join(dbPath, 'snapshots'));
      if (!await snapshotsDir.exists()) return list;

      await for (final entity in snapshotsDir.list()) {
        if (entity is File && entity.path.endsWith('.db')) {
          final fileName = basename(entity.path);
          String type = 'manual';
          if (fileName.contains('pre_migration')) {
            type = 'pre-migration';
          } else if (fileName.contains('pre_sync')) {
            type = 'pre-sync';
          }
          final stat = await entity.stat();
          list.add(DatabaseSnapshotInfo(
            path: entity.path,
            fileName: fileName,
            type: type,
            timestamp: stat.modified,
            sizeBytes: stat.size,
          ));
        }
      }
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      debugPrint('[DatabaseHelper] getAvailableSnapshots error: $e');
    }
    return list;
  }

  /// Safely restores the database from a snapshot file.
  Future<bool> restoreSnapshot(String snapshotPath) async {
    try {
      final snapshotFile = File(snapshotPath);
      if (!await snapshotFile.exists()) return false;

      final dbPath = await getDatabasesPath();
      final mainDbPath = join(dbPath, _dbName);
      final backupPath = join(dbPath, '${_dbName}_safety_backup');

      // 1. Close current db connection
      await close();

      // 2. Safety copy of current db
      final currentDbFile = File(mainDbPath);
      if (await currentDbFile.exists()) {
        await currentDbFile.copy(backupPath);
      }

      // 3. Delete stale WAL/SHM
      final walFile = File('$mainDbPath-wal');
      final shmFile = File('$mainDbPath-shm');
      if (await walFile.exists()) await walFile.delete();
      if (await shmFile.exists()) await shmFile.delete();

      // 4. Copy snapshot over main DB
      await snapshotFile.copy(mainDbPath);

      // 5. Test opening the restored DB
      try {
        final restoredDb = await database;
        await restoredDb.rawQuery('SELECT count(*) FROM sqlite_master;');
        final safetyFile = File(backupPath);
        if (await safetyFile.exists()) await safetyFile.delete();
        return true;
      } catch (openErr) {
        debugPrint('[DatabaseHelper] Restored snapshot could not be opened: $openErr. Reverting...');
        await close();
        final safetyFile = File(backupPath);
        if (await safetyFile.exists()) {
          await safetyFile.copy(mainDbPath);
          await safetyFile.delete();
        }
        await database;
        return false;
      }
    } catch (e) {
      debugPrint('[DatabaseHelper] restoreSnapshot failed: $e');
      return false;
    }
  }
}

class DatabaseSnapshotInfo {
  final String path;
  final String fileName;
  final String type; // 'pre-migration', 'pre-sync', 'manual'
  final DateTime timestamp;
  final int sizeBytes;

  const DatabaseSnapshotInfo({
    required this.path,
    required this.fileName,
    required this.type,
    required this.timestamp,
    required this.sizeBytes,
  });
}

/// Thrown when the database file exists on disk, but the encryption key
/// cannot be retrieved from secure storage (e.g., Keystore is locked or unavailable).
class SecureStorageKeyMissingException implements Exception {
  final String message;
  const SecureStorageKeyMissingException([
    this.message = 'Database file exists on disk but encryption key cannot be retrieved from secure storage. Device Keystore may be locked or temporarily unavailable.',
  ]);

  @override
  String toString() => 'SecureStorageKeyMissingException: $message';
}

/// Thrown when a database exists with data but cannot be decrypted or opened.
/// Halts execution to prevent destructive overwriting or wiping of user data.
class DatabaseAuthException implements Exception {
  final String message;
  const DatabaseAuthException([
    this.message = 'Database authentication failed or database could not be opened.',
  ]);

  @override
  String toString() => 'DatabaseAuthException: $message';
}


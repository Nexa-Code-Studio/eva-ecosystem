import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'database_key_service.dart';
import 'local_database_migrations.dart';

/// Database coordinator providing encrypted at-rest SQLite storage via SQLCipher.
class EncryptedLocalDatabase {
  static const String dbName = 'eva_local_encrypted.db';

  final DatabaseKeyService _keyService;
  final DatabaseFactory? _databaseFactory;
  Database? _db;
  String? _activeAccountKey;

  EncryptedLocalDatabase({
    DatabaseKeyService? keyService,
    DatabaseFactory? databaseFactory,
  })  : _keyService = keyService ?? DatabaseKeyService(),
        _databaseFactory = databaseFactory;

  Database? get database => _db;
  String? get activeAccountKey => _activeAccountKey;
  bool get isOpen => _db != null && _db!.isOpen;

  DatabaseFactory get _factory => _databaseFactory ?? databaseFactory;

  /// Opens or retrieves an open encrypted database connection for the given [localAccountKey].
  Future<Database> open({required String localAccountKey, String? customPath}) async {
    if (_db != null && _db!.isOpen && _activeAccountKey == localAccountKey) {
      return _db!;
    }

    if (_db != null && _db!.isOpen) {
      await close();
    }

    final key = await _keyService.getOrCreateKey(localAccountKey);
    final String dbPath;
    if (customPath != null) {
      dbPath = customPath;
    } else {
      final databasesDir = await _factory.getDatabasesPath();
      dbPath = p.join(databasesDir, dbName);
    }

    if (_databaseFactory != null) {
      _db = await _databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: LocalDatabaseMigrations.currentVersion,
          onCreate: LocalDatabaseMigrations.onCreate,
          onUpgrade: LocalDatabaseMigrations.onUpgrade,
          onConfigure: (db) async {
            try {
              await db.rawQuery("PRAGMA key = '$key';");
            } catch (_) {}
          },
          onOpen: (db) async {
            await db.execute('PRAGMA secure_delete = ON;');
            await db.execute('PRAGMA foreign_keys = ON;');
          },
        ),
      );
    } else {
      _db = await openDatabase(
        dbPath,
        version: LocalDatabaseMigrations.currentVersion,
        password: key,
        onCreate: LocalDatabaseMigrations.onCreate,
        onUpgrade: LocalDatabaseMigrations.onUpgrade,
        onOpen: (db) async {
          await db.execute('PRAGMA secure_delete = ON;');
          await db.execute('PRAGMA foreign_keys = ON;');
        },
      );
    }

    _activeAccountKey = localAccountKey;
    return _db!;
  }

  /// Closes the current database connection and clears cached keys in memory.
  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
    }
    _db = null;
    _activeAccountKey = null;
  }

  /// Permanently deletes the local database file and wipes the encryption key.
  Future<void> deleteDatabaseFile({String? customPath}) async {
    final accountKey = _activeAccountKey;
    await close();

    final String dbPath;
    if (customPath != null) {
      dbPath = customPath;
    } else {
      final databasesDir = await _factory.getDatabasesPath();
      dbPath = p.join(databasesDir, dbName);
    }

    await _factory.deleteDatabase(dbPath);
    if (accountKey != null) {
      await _keyService.deleteKey(accountKey);
    }
  }
}

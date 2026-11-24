import 'dart:io';
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

    Future<Database> doOpen() async {
      if (_databaseFactory != null) {
        return _databaseFactory.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(
            version: LocalDatabaseMigrations.currentVersion,
            onCreate: LocalDatabaseMigrations.onCreate,
            onUpgrade: LocalDatabaseMigrations.onUpgrade,
            onConfigure: (db) async {
              try {
                await db.rawQuery("PRAGMA key = '$key';");
                await db.rawQuery('PRAGMA foreign_keys = ON;');
                await db.rawQuery('PRAGMA secure_delete = ON;');
              } catch (_) {}
            },
          ),
        );
      } else {
        return openDatabase(
          dbPath,
          version: LocalDatabaseMigrations.currentVersion,
          password: key,
          onCreate: LocalDatabaseMigrations.onCreate,
          onUpgrade: LocalDatabaseMigrations.onUpgrade,
          onConfigure: (db) async {
            try {
              await db.rawQuery('PRAGMA foreign_keys = ON;');
              await db.rawQuery('PRAGMA secure_delete = ON;');
            } catch (_) {}
          },
        );
      }
    }

    try {
      _db = await doOpen();
    } catch (e) {
      // Auto-recovery: If local database file has key mismatch (e.g. app reinstalled/keystore reset)
      // or corrupted header (SQLCipher code 26 / SQLiteNotADatabaseException / open_failed),
      // wipe the unreadable file and recreate clean database with the active key.
      final err = e.toString().toLowerCase();
      if (err.contains('file is not a database') ||
          err.contains('code 26') ||
          err.contains('sqlitenotadatabaseexception') ||
          err.contains('open_failed') ||
          err.contains('malformed')) {
        try {
          final file = File(dbPath);
          if (await file.exists()) {
            await file.delete();
          }
          for (final ext in ['-wal', '-shm', '-journal']) {
            final aux = File('$dbPath$ext');
            if (await aux.exists()) {
              await aux.delete();
            }
          }
          if (_databaseFactory != null) {
            await _databaseFactory.deleteDatabase(dbPath);
          } else {
            await deleteDatabase(dbPath);
          }
        } catch (_) {}
        _db = await doOpen();
      } else {
        rethrow;
      }
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

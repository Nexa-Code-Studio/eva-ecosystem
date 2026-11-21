import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../../core/storage/encrypted_local_database.dart';
import '../models/memory_item_model.dart';

abstract class LocalMemoryDataSource {
  Future<void> insertMemory(MemoryItemModel model);
  Future<void> updateMemory(MemoryItemModel model);
  Future<void> deleteMemory(String id, {bool hardDelete = true});
  Future<List<MemoryItemModel>> getMemories({
    required String accountKey,
    String? status,
    String? category,
    bool includeDeleted = false,
  });
  Future<MemoryItemModel?> getMemoryById(String id);
  Future<void> clearAll(String accountKey);
}

class LocalMemoryDataSourceImpl implements LocalMemoryDataSource {
  final EncryptedLocalDatabase _localDb;

  LocalMemoryDataSourceImpl(this._localDb);

  Future<Database> _getDb(String accountKey) async {
    return _localDb.open(localAccountKey: accountKey);
  }

  @override
  Future<void> insertMemory(MemoryItemModel model) async {
    final db = await _getDb(model.localAccountKey);
    await db.insert(
      'memory_items',
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateMemory(MemoryItemModel model) async {
    final db = await _getDb(model.localAccountKey);
    await db.update(
      'memory_items',
      model.toMap(),
      where: 'id = ? AND local_account_key = ?',
      whereArgs: [model.id, model.localAccountKey],
    );
  }

  @override
  Future<void> deleteMemory(String id, {bool hardDelete = true}) async {
    final accountKey = _localDb.activeAccountKey ?? '';
    final db = await _getDb(accountKey);
    if (hardDelete) {
      await db.delete(
        'memory_items',
        where: 'id = ? AND local_account_key = ?',
        whereArgs: [id, accountKey],
      );
    } else {
      await db.update(
        'memory_items',
        {
          'status': 'historical',
          'deleted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ? AND local_account_key = ?',
        whereArgs: [id, accountKey],
      );
    }
  }

  @override
  Future<List<MemoryItemModel>> getMemories({
    required String accountKey,
    String? status,
    String? category,
    bool includeDeleted = false,
  }) async {
    final db = await _getDb(accountKey);
    final whereClauses = <String>['local_account_key = ?'];
    final whereArgs = <dynamic>[accountKey];

    if (!includeDeleted) {
      whereClauses.add('deleted_at IS NULL');
    }
    if (status != null && status.isNotEmpty) {
      whereClauses.add('status = ?');
      whereArgs.add(status);
    }
    if (category != null && category.isNotEmpty) {
      whereClauses.add('category = ?');
      whereArgs.add(category);
    }

    final maps = await db.query(
      'memory_items',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'updated_at DESC',
    );

    return maps.map((m) => MemoryItemModel.fromMap(m)).toList();
  }

  @override
  Future<MemoryItemModel?> getMemoryById(String id) async {
    final accountKey = _localDb.activeAccountKey ?? '';
    final db = await _getDb(accountKey);
    final maps = await db.query(
      'memory_items',
      where: 'id = ? AND local_account_key = ? AND deleted_at IS NULL',
      whereArgs: [id, accountKey],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return MemoryItemModel.fromMap(maps.first);
  }

  @override
  Future<void> clearAll(String accountKey) async {
    final db = await _getDb(accountKey);
    await db.delete(
      'memory_items',
      where: 'local_account_key = ?',
      whereArgs: [accountKey],
    );
  }
}

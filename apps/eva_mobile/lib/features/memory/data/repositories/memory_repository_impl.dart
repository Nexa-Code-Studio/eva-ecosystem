import '../../domain/entities/memory_item_entity.dart';
import '../../domain/repositories/memory_repository.dart';
import '../datasources/local_memory_datasource.dart';
import '../models/memory_item_model.dart';
import '../services/memory_context_selector.dart';

class MemoryRepositoryImpl implements MemoryRepository {
  final LocalMemoryDataSource _dataSource;
  final MemoryContextSelector _contextSelector;

  MemoryRepositoryImpl(
    this._dataSource, {
    MemoryContextSelector? contextSelector,
  }) : _contextSelector = contextSelector ?? MemoryContextSelector();

  @override
  Future<List<MemoryItemEntity>> getMemories({
    required String accountKey,
    MemoryStatus? status,
    MemoryCategory? category,
    bool includeDeleted = false,
  }) async {
    final models = await _dataSource.getMemories(
      accountKey: accountKey,
      status: status?.value,
      category: category?.value,
      includeDeleted: includeDeleted,
    );
    return models;
  }

  @override
  Future<MemoryItemEntity?> getMemoryById(String id) async {
    return _dataSource.getMemoryById(id);
  }

  @override
  Future<void> saveMemory(MemoryItemEntity item) async {
    final model = MemoryItemModel.fromEntity(item);
    await _dataSource.insertMemory(model);
  }

  @override
  Future<void> updateMemory(MemoryItemEntity item) async {
    final model = MemoryItemModel.fromEntity(item);
    await _dataSource.updateMemory(model);
  }

  @override
  Future<void> deleteMemory(String id, {bool hardDelete = true}) async {
    await _dataSource.deleteMemory(id, hardDelete: hardDelete);
  }

  @override
  Future<void> clearAllMemories(String accountKey) async {
    await _dataSource.clearAll(accountKey);
  }

  @override
  Future<List<MemoryItemEntity>> selectRelevantContext({
    required String accountKey,
    int maxItems = 5,
    String? currentInput,
  }) async {
    final allActive = await getMemories(
      accountKey: accountKey,
      status: MemoryStatus.active,
      includeDeleted: false,
    );
    return _contextSelector.selectContext(
      allActive,
      maxItems: maxItems,
      currentInput: currentInput,
    );
  }
}

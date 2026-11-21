import '../entities/memory_item_entity.dart';

abstract class MemoryRepository {
  Future<List<MemoryItemEntity>> getMemories({
    required String accountKey,
    MemoryStatus? status,
    MemoryCategory? category,
    bool includeDeleted = false,
  });

  Future<MemoryItemEntity?> getMemoryById(String id);

  Future<void> saveMemory(MemoryItemEntity item);

  Future<void> updateMemory(MemoryItemEntity item);

  Future<void> deleteMemory(String id, {bool hardDelete = true});

  Future<void> clearAllMemories(String accountKey);

  Future<List<MemoryItemEntity>> selectRelevantContext({
    required String accountKey,
    int maxItems = 5,
    String? currentInput,
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/encrypted_local_database.dart';
import '../../data/datasources/local_memory_datasource.dart';
import '../../data/repositories/memory_repository_impl.dart';
import '../../domain/entities/memory_item_entity.dart';
import '../../domain/repositories/memory_repository.dart';

final encryptedLocalDatabaseProvider = Provider<EncryptedLocalDatabase>((ref) {
  final db = EncryptedLocalDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final memoryDataSourceProvider = Provider<LocalMemoryDataSource>((ref) {
  final db = ref.watch(encryptedLocalDatabaseProvider);
  return LocalMemoryDataSourceImpl(db);
});

final memoryRepositoryProvider = Provider<MemoryRepository>((ref) {
  final ds = ref.watch(memoryDataSourceProvider);
  return MemoryRepositoryImpl(ds);
});

/// Holds the current active user ID / account key for database isolation.
final activeAccountKeyProvider = StateProvider<String>((ref) => 'current_user_local');

/// Filter providers for Memory Management Screen
final selectedMemoryCategoryFilterProvider = StateProvider<MemoryCategory?>((ref) => null);
final selectedMemoryStatusFilterProvider = StateProvider<MemoryStatus?>((ref) => null);

/// State notifier managing memory items with reactive state updates
class MemoryNotifier extends StateNotifier<AsyncValue<List<MemoryItemEntity>>> {
  final MemoryRepository _repository;
  final Ref _ref;

  MemoryNotifier(this._repository, this._ref) : super(const AsyncValue.loading()) {
    loadMemories();
  }

  Future<void> loadMemories() async {
    state = const AsyncValue.loading();
    try {
      final accountKey = _ref.read(activeAccountKeyProvider);
      final category = _ref.read(selectedMemoryCategoryFilterProvider);
      final status = _ref.read(selectedMemoryStatusFilterProvider);

      final items = await _repository.getMemories(
        accountKey: accountKey,
        category: category,
        status: status,
      );
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addMemory(MemoryItemEntity item) async {
    await _repository.saveMemory(item);
    await loadMemories();
  }

  Future<void> updateMemory(MemoryItemEntity item) async {
    await _repository.updateMemory(item);
    await loadMemories();
  }

  Future<void> deleteMemory(String id) async {
    await _repository.deleteMemory(id, hardDelete: true);
    await loadMemories();
  }

  Future<void> clearAll() async {
    final accountKey = _ref.read(activeAccountKeyProvider);
    await _repository.clearAllMemories(accountKey);
    await loadMemories();
  }

  Future<void> toggleStatus(MemoryItemEntity item) async {
    final nextStatus = item.status == MemoryStatus.active
        ? MemoryStatus.historical
        : MemoryStatus.active;
    final updated = item.copyWith(
      status: nextStatus,
      updatedAt: DateTime.now(),
    );
    await updateMemory(updated);
  }
}

final memoryNotifierProvider =
    StateNotifierProvider<MemoryNotifier, AsyncValue<List<MemoryItemEntity>>>((ref) {
  final repo = ref.watch(memoryRepositoryProvider);
  return MemoryNotifier(repo, ref);
});

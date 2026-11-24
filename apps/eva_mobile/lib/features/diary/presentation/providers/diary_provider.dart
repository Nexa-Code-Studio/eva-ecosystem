import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eva_mobile/config/app_config.dart';
import '../../../../features/memory/presentation/providers/memory_provider.dart';
import '../../domain/repositories/diary_repository.dart';
import '../../domain/entities/diary_entry_entity.dart';
import '../../data/datasources/mock_diary_datasource.dart';
import '../../data/datasources/local_diary_datasource.dart';
import '../../data/repositories/diary_repository_impl.dart';

final localDiaryDataSourceProvider = Provider<LocalDiaryDataSource>((ref) {
  final localDb = ref.watch(encryptedLocalDatabaseProvider);
  return LocalDiaryDataSource(localDb);
});

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  final mockRepo = DiaryRepositoryImpl(MockDiaryDataSource());
  final localSource = ref.watch(localDiaryDataSourceProvider);
  final localRepo = DiaryRepositoryImpl(localSource);

  if (AppConfig.useMockData) {
    return mockRepo;
  } else {
    // Local encrypted database (SQLCipher) is the single source of truth for private journal data
    return localRepo;
  }
});

final selectedMoodFilterProvider = StateProvider<String>((ref) => 'Semua');
final searchQueryProvider = StateProvider<String>((ref) => '');

final diaryEntriesProvider = FutureProvider<List<DiaryEntryEntity>>((ref) async {
  final repo = ref.watch(diaryRepositoryProvider);
  final filter = ref.watch(selectedMoodFilterProvider);
  final search = ref.watch(searchQueryProvider);
  return repo.getDiaryEntries(moodFilter: filter, searchQuery: search);
});

final diaryDetailProvider = FutureProvider.family<DiaryEntryEntity?, String>((ref, id) async {
  final repo = ref.watch(diaryRepositoryProvider);
  return repo.getDiaryEntryById(id);
});

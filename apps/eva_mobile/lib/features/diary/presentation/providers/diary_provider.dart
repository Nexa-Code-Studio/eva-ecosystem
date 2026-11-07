import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eva_mobile/config/app_config.dart';
import '../../domain/repositories/diary_repository.dart';
import '../../domain/entities/diary_entry_entity.dart';
import '../../data/datasources/mock_diary_datasource.dart';
import '../../data/datasources/remote_diary_datasource.dart';
import '../../data/repositories/diary_repository_impl.dart';
import '../../data/repositories/fallback_diary_repository.dart';

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  final mockRepo = DiaryRepositoryImpl(MockDiaryDataSource());
  final remoteRepo = DiaryRepositoryImpl(RemoteDiaryDataSource());

  if (AppConfig.useMockData) {
    return mockRepo;
  } else if (AppConfig.useHybridFallback) {
    return FallbackDiaryRepository(remote: remoteRepo, mock: mockRepo);
  } else {
    return remoteRepo;
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

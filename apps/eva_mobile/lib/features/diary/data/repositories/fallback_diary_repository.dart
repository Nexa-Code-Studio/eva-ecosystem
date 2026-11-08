import '../../domain/repositories/diary_repository.dart';
import '../../domain/entities/diary_entry_entity.dart';
import '../../../../core/network/fallback_policy.dart';

class FallbackDiaryRepository implements DiaryRepository {
  final DiaryRepository _remote;
  final DiaryRepository _mock;

  FallbackDiaryRepository({
    required DiaryRepository remote,
    required DiaryRepository mock,
  })  : _remote = remote,
        _mock = mock;

  @override
  Future<List<DiaryEntryEntity>> getDiaryEntries({String? moodFilter, String? searchQuery}) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.getDiaryEntries(moodFilter: moodFilter, searchQuery: searchQuery),
      mockCall: () => _mock.getDiaryEntries(moodFilter: moodFilter, searchQuery: searchQuery),
      operationName: 'getDiaryEntries',
    );
  }

  @override
  Future<DiaryEntryEntity?> getDiaryEntryById(String id) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.getDiaryEntryById(id),
      mockCall: () => _mock.getDiaryEntryById(id),
      operationName: 'getDiaryEntryById($id)',
    );
  }

  @override
  Future<DiaryEntryEntity?> getTodayDiary() {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.getTodayDiary(),
      mockCall: () => _mock.getTodayDiary(),
      operationName: 'getTodayDiary',
    );
  }

  @override
  Future<DiaryEntryEntity?> generateTodayDiary() {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.generateTodayDiary(),
      mockCall: () => _mock.generateTodayDiary(),
      operationName: 'generateTodayDiary',
    );
  }

  @override
  Future<DiaryEntryEntity> createDiaryEntry(String content, String moodTag) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.createDiaryEntry(content, moodTag),
      mockCall: () => _mock.createDiaryEntry(content, moodTag),
      operationName: 'createDiaryEntry',
    );
  }

  @override
  Future<void> deleteDiaryEntry(String id) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.deleteDiaryEntry(id),
      mockCall: () => _mock.deleteDiaryEntry(id),
      operationName: 'deleteDiaryEntry($id)',
    );
  }
}

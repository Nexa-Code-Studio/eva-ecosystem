import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eva_mobile/core/storage/database_key_service.dart';
import 'package:eva_mobile/core/storage/encrypted_local_database.dart';
import 'package:eva_mobile/features/diary/data/datasources/local_diary_datasource.dart';

class MockKeyStorage implements ISecureKeyStorage {
  final Map<String, String> _storage = {};

  @override
  Future<String?> read(String key) async => _storage[key];

  @override
  Future<void> write(String key, String value) async => _storage[key] = value;

  @override
  Future<void> delete(String key) async => _storage.remove(key);
}

void main() {
  sqfliteFfiInit();
  final testFactory = databaseFactoryFfi;

  late Directory tempDir;
  late EncryptedLocalDatabase localDb;
  late LocalDiaryDataSource diaryDataSource;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('eva_diary_test_');
    final keyService = DatabaseKeyService(secureStorage: MockKeyStorage());
    localDb = EncryptedLocalDatabase(
      keyService: keyService,
      databaseFactory: testFactory,
    );
    diaryDataSource = LocalDiaryDataSource(localDb, defaultAccountKey: 'test_user');
  });

  tearDown(() async {
    await localDb.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LocalDiaryDataSource Tests', () {
    test('Creates and retrieves today diary entry locally', () async {
      final testDbPath = '${tempDir.path}/diary_test.db';
      await localDb.open(localAccountKey: 'test_user', customPath: testDbPath);

      final created = await diaryDataSource.createDiaryEntry(
        'Hari ini merasa cukup lega setelah berjalan santai.',
        'Netral & Tenang 😌',
      );

      expect(created.id, isNotEmpty);
      expect(created.moodEmoji, equals('😌'));
      expect(created.summary, contains('lega setelah'));

      final today = await diaryDataSource.getTodayDiary();
      expect(today, isNotNull);
      expect(today!.id, equals(created.id));

      final all = await diaryDataSource.getDiaryEntries();
      expect(all.length, equals(1));
    });

    test('Filters diary entries by mood and search text', () async {
      final testDbPath = '${tempDir.path}/diary_search.db';
      await localDb.open(localAccountKey: 'test_user', customPath: testDbPath);

      await diaryDataSource.createDiaryEntry('Ujian sangat menegangkan', 'Cemas & Takut 😰');
      
      final cemasList = await diaryDataSource.getDiaryEntries(moodFilter: 'Cemas');
      expect(cemasList.length, equals(1));

      final searchResult = await diaryDataSource.getDiaryEntries(searchQuery: 'menegangkan');
      expect(searchResult.length, equals(1));

      final noMatch = await diaryDataSource.getDiaryEntries(searchQuery: 'liburan');
      expect(noMatch, isEmpty);
    });

    test('Deletes diary entry successfully', () async {
      final testDbPath = '${tempDir.path}/diary_delete.db';
      await localDb.open(localAccountKey: 'test_user', customPath: testDbPath);

      final entry = await diaryDataSource.createDiaryEntry('Catatan dihapus', 'Sedih 😢');
      var list = await diaryDataSource.getDiaryEntries();
      expect(list.length, equals(1));

      await diaryDataSource.deleteDiaryEntry(entry.id);
      list = await diaryDataSource.getDiaryEntries();
      expect(list, isEmpty);
    });

    test('Parses transcripts from content and populates session transcripts', () async {
      final testDbPath = '${tempDir.path}/diary_transcripts.db';
      await localDb.open(localAccountKey: 'test_user', customPath: testDbPath);

      await diaryDataSource.saveSessionArtifacts(
        sessionId: 'call_trans_101',
        sessionSummary: 'Percakapan tentang bangun pagi',
        journalDelta: {
          'title': 'Sesi Suara',
          'content': 'User: harus bangun pagi\nEVA: Bangun pagi memang berat ya.',
          'mood_tag': 'Netral & Tenang 😌',
        },
      );

      final entries = await diaryDataSource.getDiaryEntries();
      expect(entries.length, 1);
      expect(entries.first.sessions.length, 1);
      final transcripts = entries.first.sessions.first.transcripts;
      expect(transcripts.length, 2);
      expect(transcripts[0]['isUser'], true);
      expect(transcripts[0]['text'], 'harus bangun pagi');
      expect(transcripts[1]['isUser'], false);
      expect(transcripts[1]['text'], 'Bangun pagi memang berat ya.');
      expect(entries.first.importantEvents.isNotEmpty, true);
    });
  });
}

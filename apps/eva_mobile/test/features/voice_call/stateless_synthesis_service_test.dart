import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eva_mobile/core/storage/database_key_service.dart';
import 'package:eva_mobile/core/storage/encrypted_local_database.dart';
import 'package:eva_mobile/features/dass/data/datasources/local_dass_datasource.dart';
import 'package:eva_mobile/features/diary/data/datasources/local_diary_datasource.dart';
import 'package:eva_mobile/features/voice_call/data/services/stateless_synthesis_service.dart';

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
  late LocalDASSDataSource dassDataSource;
  late StatelessSynthesisService synthesisService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('eva_synthesis_test_');
    final keyService = DatabaseKeyService(secureStorage: MockKeyStorage());
    localDb = EncryptedLocalDatabase(
      keyService: keyService,
      databaseFactory: testFactory,
    );
    diaryDataSource = LocalDiaryDataSource(localDb, defaultAccountKey: 'test_user');
    dassDataSource = LocalDASSDataSource(localDb, defaultAccountKey: 'test_user');
    synthesisService = StatelessSynthesisService(
      localDb: localDb,
      diaryDataSource: diaryDataSource,
      dassDataSource: dassDataSource,
      defaultAccountKey: 'test_user',
    );
  });

  tearDown(() async {
    await localDb.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('StatelessSynthesisService Tests', () {
    test('Records incremental turns into conversation_turns table', () async {
      final testDbPath = '${tempDir.path}/turns_test.db';
      await localDb.open(localAccountKey: 'test_user', customPath: testDbPath);

      await synthesisService.recordTurn(
        sessionId: 'call_999',
        turnId: 1,
        role: 'user',
        transcript: 'Halo Eva, selamat pagi.',
      );

      await synthesisService.recordTurn(
        sessionId: 'call_999',
        turnId: 1,
        role: 'assistant',
        transcript: 'Pagi! Bagaimana kabarmu hari ini?',
      );

      final turns = await synthesisService.getSessionTurns('call_999');
      expect(turns.length, equals(2));
      expect(turns[0]['role'], equals('user'));
      expect(turns[0]['transcript'], equals('Halo Eva, selamat pagi.'));
      expect(turns[1]['role'], equals('assistant'));
      expect(turns[1]['transcript'], equals('Pagi! Bagaimana kabarmu hari ini?'));
    });

    test('Marks session pending and commits artifacts locally', () async {
      final testDbPath = '${tempDir.path}/turns_test.db';
      await localDb.open(localAccountKey: 'test_user', customPath: testDbPath);

      await synthesisService.markSessionPending(
        sessionId: 'call_pending_1',
        initialSummary: 'Percakapan berlangsung singkat.',
      );

      final isDoneBefore = await synthesisService.isSessionSynthesized('call_pending_1');
      expect(isDoneBefore, isFalse);

      await synthesisService.commitArtifactsLocally(
        sessionId: 'call_pending_1',
        sessionSummary: 'Ringkasan komprehensif percakapan.',
        journalDelta: {
          'title': 'Refleksi Sesi Pagi',
          'summary': 'Ringkasan komprehensif percakapan.',
          'content': 'Isi jurnal percakapan.',
          'mood_tag': 'Netral & Tenang 😌',
          'mood_emoji': '😌',
          'emotional_level': 3,
          'ai_insight': 'Wawasan AI yang menenangkan.',
          'important_events': ['Diskusi Pagi'],
        },
        dassAssessment: {
          'stress_score': 6,
          'anxiety_score': 4,
          'depression_score': 2,
          'stress_category': 'Normal',
          'anxiety_category': 'Normal',
          'depression_category': 'Normal',
          'items': [],
        },
      );

      final isDoneAfter = await synthesisService.isSessionSynthesized('call_pending_1');
      expect(isDoneAfter, isTrue);

      final dassToday = await dassDataSource.getTodayAssessment();
      expect(dassToday.stressScore, equals(6));
    });
  });
}

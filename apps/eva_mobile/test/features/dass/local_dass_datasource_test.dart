import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eva_mobile/core/storage/database_key_service.dart';
import 'package:eva_mobile/core/storage/encrypted_local_database.dart';
import 'package:eva_mobile/features/dass/data/datasources/local_dass_datasource.dart';

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
  late LocalDASSDataSource dassDataSource;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('eva_dass_test_');
    final keyService = DatabaseKeyService(secureStorage: MockKeyStorage());
    localDb = EncryptedLocalDatabase(
      keyService: keyService,
      databaseFactory: testFactory,
    );
    dassDataSource = LocalDASSDataSource(localDb, defaultAccountKey: 'test_user');
  });

  tearDown(() async {
    await localDb.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LocalDASSDataSource Tests', () {
    test('Returns default empty 21-item assessment when no data exists', () async {
      final testDbPath = '${tempDir.path}/dass_test.db';
      await localDb.open(localAccountKey: 'test_user', customPath: testDbPath);

      final today = await dassDataSource.getTodayAssessment();

      expect(today.status, equals('empty'));
      expect(today.items.length, equals(21));
      expect(today.stressScore, equals(0));
      expect(today.anxietyScore, equals(0));
      expect(today.depressionScore, equals(0));
      expect(today.stressSeverity, equals('Normal'));
    });

    test('Saves and retrieves AI-extracted DASS assessment', () async {
      final testDbPath = '${tempDir.path}/dass_test.db';
      await localDb.open(localAccountKey: 'test_user', customPath: testDbPath);

      final dummyItems = List.generate(21, (i) {
        final scale = i % 3 == 0 ? 'stress' : (i % 3 == 1 ? 'anxiety' : 'depression');
        return {
          'item_id': i + 1,
          'scale': scale,
          'question_text': 'Pertanyaan ${i + 1}',
          'score': 1,
          'evidence': 'User: "Contoh ucapan bukti"',
          'reason': 'Alasan AI',
          'confidence': 0.85,
          'is_user_edited': false,
        };
      });

      await dassDataSource.saveExtractedAssessment(
        sessionId: 'session_call_101',
        dassAssessmentPayload: {
          'stress_score': 14,
          'anxiety_score': 14,
          'depression_score': 14,
          'stress_category': 'Mild',
          'anxiety_category': 'Moderate',
          'depression_category': 'Moderate',
          'items': dummyItems,
        },
      );

      final retrieved = await dassDataSource.getTodayAssessment();
      expect(retrieved.status, equals('auto_extracted'));
      expect(retrieved.items.length, equals(21));
      expect(retrieved.stressScore, equals(14));
      expect(retrieved.anxietyScore, equals(14));
      expect(retrieved.depressionScore, equals(14));
      expect(retrieved.verifiedByUser, isFalse);
    });

    test('Updates assessment with user correction and marks verified', () async {
      final testDbPath = '${tempDir.path}/dass_test.db';
      await localDb.open(localAccountKey: 'test_user', customPath: testDbPath);

      final userItems = List.generate(21, (i) {
        final scale = i % 3 == 0 ? 'stress' : (i % 3 == 1 ? 'anxiety' : 'depression');
        return {
          'item_id': i + 1,
          'scale': scale,
          'question_text': 'Pertanyaan ${i + 1}',
          'score': 2,
          'evidence': null,
          'reason': null,
          'confidence': 1.0,
          'is_user_edited': true,
        };
      });

      final updated = await dassDataSource.updateAssessment(userItems);
      expect(updated.verifiedByUser, isTrue);
      expect(updated.status, equals('verified'));
      // 7 items per scale with score 2 = 14 raw score * 2 = 28
      expect(updated.stressScore, equals(28));
      expect(updated.stressSeverity, equals('Severe'));
    });

    test('Score-only updateAssessment preserves all 21 official questions, scales, and AI citations', () async {
      final testDbPath = '${tempDir.path}/dass_test.db';
      await localDb.open(localAccountKey: 'test_user', customPath: testDbPath);

      await dassDataSource.saveExtractedAssessment(
        sessionId: 'session_call_202',
        dassAssessmentPayload: {
          'stress_score': 4,
          'anxiety_score': 2,
          'depression_score': 0,
          'items': [
            {
              'item_id': 1,
              'scale': 'stress',
              'question_text': 'Old text ignored',
              'score': 2,
              'evidence': 'User: "Saya gampang marah hal sepele"',
              'reason': 'Indikasi stres ringan-sedang.',
              'confidence': 0.88,
              'is_user_edited': false,
            },
            {
              'item_id': 2,
              'scale': 'anxiety',
              'question_text': 'Old text 2',
              'score': 1,
              'evidence': 'User: "Bibir kering terus"',
              'reason': 'Gejala otonomik kecemasan.',
              'confidence': 0.75,
              'is_user_edited': false,
            },
          ],
        },
      );

      // Simulate DASSAssessmentNotifier.saveAssessment() payload (only item_id and score)
      final scoreOnlyPayload = List.generate(
        21,
        (i) => {'item_id': i + 1, 'score': i == 0 ? 3 : (i == 1 ? 1 : 0)},
      );

      final updated = await dassDataSource.updateAssessment(scoreOnlyPayload);
      expect(updated.items.length, equals(21));

      final item1 = updated.items.firstWhere((it) => it.itemId == 1);
      expect(
        item1.questionText,
        equals('Saya merasa bahwa diri saya menjadi marah karena hal-hal sepele.'),
      );
      expect(item1.scale, equals('stress'));
      expect(item1.score, equals(3));
      expect(item1.evidence, equals('User: "Saya gampang marah hal sepele"'));
      expect(item1.reason, equals('Indikasi stres ringan-sedang.'));
      expect(item1.confidence, equals(0.88));
      expect(item1.isUserEdited, isTrue);

      final item2 = updated.items.firstWhere((it) => it.itemId == 2);
      expect(item2.questionText, equals('Saya merasa bibir saya sering kering.'));
      expect(item2.scale, equals('anxiety'));
      expect(item2.score, equals(1));
      expect(item2.evidence, equals('User: "Bibir kering terus"'));
      expect(item2.reason, equals('Gejala otonomik kecemasan.'));
      expect(item2.confidence, equals(0.75));
      expect(item2.isUserEdited, isFalse);

      // Re-reading from SQLite also preserves all 21 official questions and citations
      final reloaded = await dassDataSource.getTodayAssessment();
      expect(reloaded.items.length, equals(21));
      expect(reloaded.stressScore, equals(6));
      expect(reloaded.anxietyScore, equals(2));
      expect(reloaded.items.first.evidence, equals('User: "Saya gampang marah hal sepele"'));
    });

    test('Recovers official 21 questions and scales from corrupted score-only SQLite row', () async {
      final testDbPath = '${tempDir.path}/dass_test.db';
      final db = await localDb.open(localAccountKey: 'test_user', customPath: testDbPath);
      final now = DateTime.now();
      final today =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      await db.insert('local_dass_assessments', {
        'id': 'dass_test_user_$today',
        'local_account_key': 'test_user',
        'assessment_date': today,
        'stress_score': 6,
        'anxiety_score': 0,
        'depression_score': 0,
        'stress_category': 'Normal',
        'anxiety_category': 'Normal',
        'depression_category': 'Normal',
        'items_json': '[{"item_id":2,"score":2},{"item_id":3,"score":1}]',
        'is_user_verified': 1,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      final recovered = await dassDataSource.getTodayAssessment();
      expect(recovered.items.length, equals(21));
      expect(recovered.anxietyScore, equals(4));
      expect(recovered.depressionScore, equals(2));
      expect(
        recovered.items.firstWhere((it) => it.itemId == 2).questionText,
        equals('Saya merasa bibir saya sering kering.'),
      );
      expect(
        recovered.items.firstWhere((it) => it.itemId == 21).questionText,
        equals('Saya merasa bahwa hidup tidak bermanfaat.'),
      );
    });
  });
}

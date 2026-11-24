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
  });
}

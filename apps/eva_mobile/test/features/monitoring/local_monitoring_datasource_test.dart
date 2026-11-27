import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eva_mobile/core/storage/database_key_service.dart';
import 'package:eva_mobile/core/storage/encrypted_local_database.dart';
import 'package:eva_mobile/features/diary/data/datasources/local_diary_datasource.dart';
import 'package:eva_mobile/features/monitoring/data/datasources/local_monitoring_datasource.dart';

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
  late LocalMonitoringDataSource monitoringDataSource;
  late LocalDiaryDataSource diaryDataSource;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('eva_mon_test_');
    final keyService = DatabaseKeyService(secureStorage: MockKeyStorage());
    localDb = EncryptedLocalDatabase(
      keyService: keyService,
      databaseFactory: testFactory,
    );
    monitoringDataSource = LocalMonitoringDataSource(localDb, defaultAccountKey: 'test_mon_user');
    diaryDataSource = LocalDiaryDataSource(localDb, defaultAccountKey: 'test_mon_user');
  });

  tearDown(() async {
    await localDb.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LocalMonitoringDataSource Tests', () {
    test('Returns clean empty model when no entries exist', () async {
      final testDbPath = '${tempDir.path}/mon_test.db';
      await localDb.open(localAccountKey: 'test_mon_user', customPath: testDbPath);

      final data = await monitoringDataSource.getMonitoringData('today');
      expect(data.periodKey, 'today');
      expect(data.periodLabel, 'Hari Ini');
      expect(data.isEmpty, isTrue);
      expect(data.chartData.isEmpty, isTrue);
      expect(data.risks.isEmpty, isTrue);
    });

    test('Aggregates mood and emotion distribution from local journal entries', () async {
      final testDbPath = '${tempDir.path}/mon_test.db';
      await localDb.open(localAccountKey: 'test_mon_user', customPath: testDbPath);

      // Create entries with different emotions
      await diaryDataSource.createDiaryEntry('Hari ini merasa sangat bahagia dan lega', 'Bahagia & Senang');
      await diaryDataSource.saveSessionArtifacts(
        sessionId: 'sess_mon_1',
        sessionSummary: 'Diskusi tentang ketenangan',
        journalDelta: {
          'title': 'Sesi Pagi',
          'mood_tag': 'Netral & Tenang',
        },
      );

      final weekData = await monitoringDataSource.getMonitoringData('week');
      expect(weekData.periodKey, 'week');
      expect(weekData.periodLabel, 'Minggu Ini');
      expect(weekData.emotionalCenter.level, greaterThanOrEqualTo(4));
      expect(weekData.emotionalCenter.status, contains('Baik'));
      expect(weekData.chartData.isNotEmpty, isTrue);
      // Since entries were Bahagia and Netral with 0 fear/sadness/anger, stress/fear/depression should be 0%
      expect(weekData.risks.firstWhere((r) => r.type == 'stress').percent, 0.0);
      expect(weekData.risks.firstWhere((r) => r.type == 'stress').levelLabel, 'Rendah (0%)');
      expect(weekData.risks.firstWhere((r) => r.type == 'anxiety').percent, 0.0);
      expect(weekData.risks.firstWhere((r) => r.type == 'anxiety').levelLabel, 'Rendah (0%)');
      expect(weekData.risks.firstWhere((r) => r.type == 'depresi').percent, 0.0);
      expect(weekData.risks.firstWhere((r) => r.type == 'depresi').levelLabel, 'Rendah (0%)');
    });

    test('Aggregates 7-emotion vector from stored emotions_breakdown_json', () async {
      final testDbPath = '${tempDir.path}/mon_breakdown_test.db';
      await localDb.open(localAccountKey: 'test_mon_user', customPath: testDbPath);

      await diaryDataSource.saveSessionArtifacts(
        sessionId: 'sess_mon_7emo',
        sessionSummary: 'Sesi dengan data 7 emosi lengkap.',
        journalDelta: {
          'title': 'Pemantauan 7 Emosi',
          'mood_tag': 'Bahagia',
          'emotions_breakdown': [
            {'label': 'Bahagia', 'percent': 0.25},
            {'label': 'Netral', 'percent': 0.20},
            {'label': 'Cemas & Takut', 'percent': 0.15},
            {'label': 'Sedih', 'percent': 0.10},
            {'label': 'Terkejut', 'percent': 0.12},
            {'label': 'Marah', 'percent': 0.10},
            {'label': 'Jijik', 'percent': 0.08},
          ],
        },
      );

      final todayData = await monitoringDataSource.getMonitoringData('today');
      expect(todayData.chartData, isNotEmpty);
      final vector = todayData.chartData.first;
      expect(vector.length, 7);
      // Verify indices 4 (surprise), 5 (anger), 6 (disgusted) reflect persisted values rather than 0.0
      expect(vector[4], closeTo(0.12, 0.01));
      expect(vector[5], closeTo(0.10, 0.01));
      expect(vector[6], closeTo(0.08, 0.01));
    });
  });
}

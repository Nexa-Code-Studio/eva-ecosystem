import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:eva_mobile/core/storage/database_key_service.dart';
import 'package:eva_mobile/core/storage/encrypted_local_database.dart';
import 'package:eva_mobile/features/chat/data/datasources/local_chat_datasource.dart';
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
  late LocalChatDataSource chatDataSource;
  late LocalDiaryDataSource diaryDataSource;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('eva_chat_test_');
    final keyService = DatabaseKeyService(secureStorage: MockKeyStorage());
    localDb = EncryptedLocalDatabase(
      keyService: keyService,
      databaseFactory: testFactory,
    );
    chatDataSource = LocalChatDataSource(localDb, defaultAccountKey: 'test_chat_user');
    diaryDataSource = LocalDiaryDataSource(localDb, defaultAccountKey: 'test_chat_user');
  });

  tearDown(() async {
    await localDb.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('LocalChatDataSource Tests', () {
    test('Returns empty conversation list when database has no sessions', () async {
      final testDbPath = '${tempDir.path}/chat_test.db';
      await localDb.open(localAccountKey: 'test_chat_user', customPath: testDbPath);

      final conversations = await chatDataSource.getConversations();
      expect(conversations, isEmpty);
    });

    test('Maps session_summaries and journal_entries into ConversationModel', () async {
      final testDbPath = '${tempDir.path}/chat_test.db';
      await localDb.open(localAccountKey: 'test_chat_user', customPath: testDbPath);

      // Save a session artifact via diaryDataSource (simulating voice call completion)
      await diaryDataSource.saveSessionArtifacts(
        sessionId: 'sess_12345',
        sessionSummary: 'Pengguna mendiskusikan kecemasan saat wawancara kerja.',
        journalDelta: {
          'title': 'Refleksi Sesi Panggilan (Wawancara Kerja)',
          'mood_tag': 'Cemas & Takut',
          'mood_emoji': '😰',
        },
      );

      final conversations = await chatDataSource.getConversations();
      expect(conversations.length, 1);
      final first = conversations.first;
      expect(first.id, 'sess_12345');
      expect(first.title, contains('Wawancara Kerja'));
      expect(first.moodTag, 'Cemas & Takut');
      expect(first.moodEmoji, '😰');
      expect(first.summary, contains('Pengguna mendiskusikan'));
      expect(first.messages.length, 1);
      expect(first.messages.first.text, contains('Pengguna mendiskusikan'));

      // Test getConversationById
      final single = await chatDataSource.getConversationById('sess_12345');
      expect(single, isNotNull);
      expect(single!.id, 'sess_12345');
    });

    test('Stream summary yields locally stored summary immediately', () async {
      final testDbPath = '${tempDir.path}/chat_test.db';
      await localDb.open(localAccountKey: 'test_chat_user', customPath: testDbPath);

      await diaryDataSource.saveSessionArtifacts(
        sessionId: 'sess_stream_99',
        sessionSummary: 'Ringkasan refleksi cepat sesi suara.',
        journalDelta: {'title': 'Refleksi Sesi Cepat'},
      );

      final tokens = await chatDataSource.streamConversationSummary('sess_stream_99').toList();
      expect(tokens.length, 1);
      expect(tokens.first, 'Ringkasan refleksi cepat sesi suara.');
    });

    test('Maps multi-turn conversation_turns and emotions_breakdown_json', () async {
      final testDbPath = '${tempDir.path}/chat_turns_test.db';
      final db = await localDb.open(
        localAccountKey: 'test_chat_user',
        customPath: testDbPath,
      );

      await diaryDataSource.saveSessionArtifacts(
        sessionId: 'sess_turns_1',
        sessionSummary: 'Diskusi terstruktur mengenai manajemen stres kerja.',
        journalDelta: {
          'title': 'Manajemen Stres Kerja',
          'mood_tag': 'Tenang',
          'mood_emoji': '😌',
          'emotions_breakdown': [
            {'label': 'Tenang', 'emoji': '😌', 'percent': 0.65, 'color': '#4ECDC4'},
            {'label': 'Cemas', 'emoji': '😰', 'percent': 0.35, 'color': '#6C63FF'},
          ],
        },
      );

      final nowIso = DateTime.now().toIso8601String();
      await db.insert('conversation_turns', {
        'id': 'turn_1_user',
        'session_id': 'sess_turns_1',
        'turn_id': 1,
        'role': 'user',
        'local_account_key': 'test_chat_user',
        'transcript': 'Halo EVA, kerjaan hari ini padat banget.',
        'created_at': nowIso,
      });
      await db.insert('conversation_turns', {
        'id': 'turn_1_assistant',
        'session_id': 'sess_turns_1',
        'turn_id': 1,
        'role': 'assistant',
        'local_account_key': 'test_chat_user',
        'transcript': 'Kedengarannya cukup melelahkan ya. Bagian mana yang paling terasa berat?',
        'created_at': nowIso,
      });
      await db.insert('conversation_turns', {
        'id': 'turn_2_user',
        'session_id': 'sess_turns_1',
        'turn_id': 2,
        'role': 'user',
        'local_account_key': 'test_chat_user',
        'transcript': 'Deadline presentasi besok pagi.',
        'created_at': nowIso,
      });
      await db.insert('conversation_turns', {
        'id': 'turn_2_assistant',
        'session_id': 'sess_turns_1',
        'turn_id': 2,
        'role': 'assistant',
        'local_account_key': 'test_chat_user',
        'transcript': 'Mari kita pecah langkah persiapannya pelan-pelan.',
        'created_at': nowIso,
      });

      final conv = await chatDataSource.getConversationById('sess_turns_1');
      expect(conv, isNotNull);
      expect(conv!.messages.length, 4);
      expect(conv.messages[0].isUser, isTrue);
      expect(conv.messages[0].text, 'Halo EVA, kerjaan hari ini padat banget.');
      expect(conv.messages[1].isUser, isFalse);
      expect(conv.messages[3].isUser, isFalse);
      expect(conv.emotionsBreakdown.length, 2);
      expect(conv.emotionsBreakdown.first['label'], 'Tenang');
    });
  });
}

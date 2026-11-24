import 'dart:async';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../../core/storage/encrypted_local_database.dart';
import '../models/chat_message_model.dart';
import '../models/conversation_model.dart';
import 'chat_datasource.dart';

/// Local encrypted data source for conversation sessions backed by SQLCipher.
/// Reads voice call session summaries and journal associations from on-device storage.
class LocalChatDataSource implements ChatDataSource {
  final EncryptedLocalDatabase _localDb;
  final String _defaultAccountKey;

  LocalChatDataSource(this._localDb, {String defaultAccountKey = 'current_user_local'})
      : _defaultAccountKey = defaultAccountKey;

  String get _accountKey => _localDb.activeAccountKey ?? _defaultAccountKey;

  Future<Database> _getDb() async {
    return _localDb.open(localAccountKey: _accountKey);
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return 'Hari ini';
    }
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    } catch (_) {
      return '';
    }
  }

  @override
  Future<List<ConversationModel>> getConversations() async {
    final db = await _getDb();

    // Query session_summaries joined with journal_entries for emotion/title metadata
    final rows = await db.rawQuery(
      '''
      SELECT 
        s.id AS session_id,
        s.client_session_id AS client_session_id,
        s.summary AS summary,
        s.created_at AS created_at,
        j.id AS journal_id,
        j.title AS journal_title,
        j.mood_tag AS mood_tag,
        j.mood_emoji AS mood_emoji,
        j.entry_date_local AS entry_date_local
      FROM session_summaries s
      LEFT JOIN journal_entries j ON s.journal_id = j.id
      WHERE s.local_account_key = ?
        AND (
          s.client_session_id IN (SELECT DISTINCT session_id FROM conversation_turns WHERE local_account_key = ?)
          OR (s.summary IS NOT NULL AND LENGTH(TRIM(s.summary)) > 30 AND s.summary NOT LIKE 'Panggilan suara selesai%')
        )
      ORDER BY s.created_at DESC
      ''',
      [_accountKey, _accountKey],
    );

    final conversations = <ConversationModel>[];
    final seenSessionIds = <String>{};
    for (final row in rows) {
      final sessionId = (row['client_session_id'] as String?) ?? (row['session_id'] as String);
      if (seenSessionIds.contains(sessionId)) continue;
      seenSessionIds.add(sessionId);

      final createdAt = (row['created_at'] as String?) ?? '';
      final entryDate = (row['entry_date_local'] as String?) ?? _formatDate(createdAt);
      final timeStr = _formatTime(createdAt);
      final summary = (row['summary'] as String?) ?? '';
      final title = (row['journal_title'] as String?) ?? 'Sesi Panggilan Suara EVA';
      final moodTag = (row['mood_tag'] as String?) ?? 'Tenang & Nyaman';
      final moodEmoji = (row['mood_emoji'] as String?) ?? '😌';

      conversations.add(
        ConversationModel(
          id: sessionId,
          title: title,
          date: entryDate,
          lastSessionTime: timeStr,
          moodTag: moodTag,
          moodEmoji: moodEmoji,
          summary: summary,
          messages: summary.isNotEmpty
              ? [
                  ChatMessageModel(
                    id: 'msg_summary_$sessionId',
                    conversationId: sessionId,
                    isUser: false,
                    text: summary,
                    time: timeStr,
                    emotionTag: moodTag,
                    emotionEmoji: moodEmoji,
                  ),
                ]
              : const [],
        ),
      );
    }

    return conversations;
  }

  @override
  Future<ConversationModel?> getConversationById(String id) async {
    final db = await _getDb();
    final rows = await db.rawQuery(
      '''
      SELECT 
        s.id AS session_id,
        s.client_session_id AS client_session_id,
        s.summary AS summary,
        s.created_at AS created_at,
        j.id AS journal_id,
        j.title AS journal_title,
        j.mood_tag AS mood_tag,
        j.mood_emoji AS mood_emoji,
        j.entry_date_local AS entry_date_local
      FROM session_summaries s
      LEFT JOIN journal_entries j ON s.journal_id = j.id
      WHERE (s.client_session_id = ? OR s.id = ?) AND s.local_account_key = ?
      LIMIT 1
      ''',
      [id, id, _accountKey],
    );

    if (rows.isEmpty) return null;
    final row = rows.first;
    final createdAt = (row['created_at'] as String?) ?? '';
    final entryDate = (row['entry_date_local'] as String?) ?? _formatDate(createdAt);
    final timeStr = _formatTime(createdAt);
    final summary = (row['summary'] as String?) ?? '';
    final title = (row['journal_title'] as String?) ?? 'Sesi Panggilan Suara EVA';
    final moodTag = (row['mood_tag'] as String?) ?? 'Tenang & Nyaman';
    final moodEmoji = (row['mood_emoji'] as String?) ?? '😌';
    final sessionId = (row['client_session_id'] as String?) ?? (row['session_id'] as String);

    return ConversationModel(
      id: sessionId,
      title: title,
      date: entryDate,
      lastSessionTime: timeStr,
      moodTag: moodTag,
      moodEmoji: moodEmoji,
      summary: summary,
      messages: summary.isNotEmpty
          ? [
              ChatMessageModel(
                id: 'msg_summary_$sessionId',
                conversationId: sessionId,
                isUser: false,
                text: summary,
                time: timeStr,
                emotionTag: moodTag,
                emotionEmoji: moodEmoji,
              ),
            ]
          : const [],
    );
  }

  @override
  Future<ChatMessageModel> sendMessage(String conversationId, String text) async {
    // In zero-persistence local architecture, dialogue occurs via real-time speech/WebSocket
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return ChatMessageModel(
      id: 'local_msg_${now.millisecondsSinceEpoch}',
      conversationId: conversationId,
      isUser: true,
      text: text,
      time: timeStr,
    );
  }

  @override
  Stream<String> streamConversationSummary(String conversationId) async* {
    final conv = await getConversationById(conversationId);
    if (conv != null && conv.summary.isNotEmpty) {
      yield conv.summary;
    }
  }
}

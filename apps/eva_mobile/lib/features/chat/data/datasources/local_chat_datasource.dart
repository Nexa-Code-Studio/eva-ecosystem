import 'dart:async';
import 'dart:convert';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../../core/storage/encrypted_local_database.dart';
import '../models/chat_message_model.dart';
import '../models/conversation_model.dart';
import 'chat_datasource.dart';

/// Local encrypted data source for conversation sessions backed by SQLCipher.
/// Reads voice call session summaries, conversation_turns, and emotions_breakdown from on-device storage.
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

  List<Map<String, dynamic>> _parseEmotionsBreakdown(dynamic rawJson) {
    if (rawJson is! String || rawJson.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  String _computeDuration(List<Map<String, dynamic>> turnRows) {
    if (turnRows.length < 2) return '00:00';
    try {
      final start = DateTime.parse(turnRows.first['created_at'].toString());
      final end = DateTime.parse(turnRows.last['created_at'].toString());
      final secs = end.difference(start).inSeconds.clamp(0, 86400);
      final mm = (secs ~/ 60).toString().padLeft(2, '0');
      final ss = (secs % 60).toString().padLeft(2, '0');
      return '$mm:$ss';
    } catch (_) {
      return '00:00';
    }
  }

  Future<ConversationModel> _mapRowToConversation(
    Database db,
    Map<String, dynamic> row,
  ) async {
    final sessionId = (row['client_session_id'] as String?) ?? (row['session_id'] as String);
    final createdAt = (row['created_at'] as String?) ?? '';
    final entryDate = (row['entry_date_local'] as String?) ?? _formatDate(createdAt);
    final timeStr = _formatTime(createdAt);
    final rawSummary = (row['summary'] as String?) ?? '';
    final synthesisStatus = (row['synthesis_status'] as String?) ?? 'completed';
    final isRawTranscript = rawSummary.trim().startsWith('User:') || rawSummary.trim().startsWith('EVA:');
    final summary = (synthesisStatus == 'completed' && !isRawTranscript) ? rawSummary : '';

    final title = (row['journal_title'] as String?) ?? 'Sesi Panggilan Suara EVA';
    final moodTag = (row['mood_tag'] as String?) ?? 'Tenang & Nyaman';
    final moodEmoji = (row['mood_emoji'] as String?) ?? '😌';

    var emotionsBreakdown = _parseEmotionsBreakdown(row['session_emotions_json']);
    if (emotionsBreakdown.isEmpty) {
      emotionsBreakdown = _parseEmotionsBreakdown(row['journal_emotions_json']);
    }

    final turnRows = await db.query(
      'conversation_turns',
      where: 'session_id = ? AND local_account_key = ?',
      whereArgs: [sessionId, _accountKey],
      orderBy: 'turn_id ASC, created_at ASC',
    );

    final List<ChatMessageModel> messages;
    if (turnRows.isNotEmpty) {
      messages = turnRows.map((t) {
        final role = (t['role'] as String?) ?? 'user';
        final isUser = role == 'user';
        return ChatMessageModel(
          id: (t['id'] as String?) ?? 'turn_${t['turn_id']}_$role',
          conversationId: sessionId,
          isUser: isUser,
          text: (t['transcript'] as String?) ?? '',
          time: _formatTime((t['created_at'] as String?) ?? createdAt),
        );
      }).toList();
    } else if (summary.isNotEmpty) {
      messages = [
        ChatMessageModel(
          id: 'msg_summary_$sessionId',
          conversationId: sessionId,
          isUser: false,
          text: summary,
          time: timeStr,
          emotionTag: moodTag,
          emotionEmoji: moodEmoji,
        ),
      ];
    } else {
      messages = const [];
    }

    return ConversationModel(
      id: sessionId,
      title: title,
      date: entryDate,
      lastSessionTime: timeStr,
      duration: _computeDuration(turnRows),
      moodTag: moodTag,
      moodEmoji: moodEmoji,
      summary: summary,
      messages: messages,
      emotionsBreakdown: emotionsBreakdown,
    );
  }

  @override
  Future<List<ConversationModel>> getConversations() async {
    final db = await _getDb();

    final rows = await db.rawQuery(
      '''
      SELECT 
        s.id AS session_id,
        s.client_session_id AS client_session_id,
        s.summary AS summary,
        s.synthesis_status AS synthesis_status,
        s.emotions_breakdown_json AS session_emotions_json,
        s.created_at AS created_at,
        j.id AS journal_id,
        j.title AS journal_title,
        j.mood_tag AS mood_tag,
        j.mood_emoji AS mood_emoji,
        j.entry_date_local AS entry_date_local,
        j.emotions_breakdown_json AS journal_emotions_json
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

      conversations.add(await _mapRowToConversation(db, row));
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
        s.synthesis_status AS synthesis_status,
        s.emotions_breakdown_json AS session_emotions_json,
        s.created_at AS created_at,
        j.id AS journal_id,
        j.title AS journal_title,
        j.mood_tag AS mood_tag,
        j.mood_emoji AS mood_emoji,
        j.entry_date_local AS entry_date_local,
        j.emotions_breakdown_json AS journal_emotions_json
      FROM session_summaries s
      LEFT JOIN journal_entries j ON s.journal_id = j.id
      WHERE (s.client_session_id = ? OR s.id = ?) AND s.local_account_key = ?
      LIMIT 1
      ''',
      [id, id, _accountKey],
    );

    if (rows.isEmpty) return null;
    return _mapRowToConversation(db, rows.first);
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

import 'dart:convert';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../../core/storage/encrypted_local_database.dart';
import '../models/diary_entry_model.dart';
import 'diary_datasource.dart';

class LocalDiaryDataSource implements DiaryDataSource {
  final EncryptedLocalDatabase _localDb;
  final String _defaultAccountKey;

  LocalDiaryDataSource(this._localDb, {String defaultAccountKey = 'current_user_local'})
      : _defaultAccountKey = defaultAccountKey;

  String get _accountKey => _localDb.activeAccountKey ?? _defaultAccountKey;

  Future<Database> _getDb() async {
    return _localDb.open(localAccountKey: _accountKey);
  }

  String _formatWibDate(DateTime dt) {
    // Standard YYYY-MM-DD
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return 'Hari Ini';
    }
  }

  List<Map<String, dynamic>> _parseTranscripts(String content) {
    if (content.isEmpty) return const [];
    final lines = content.split('\n');
    final result = <Map<String, dynamic>>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final lower = trimmed.toLowerCase();
      final bool isUser = lower.startsWith('user:');
      final bool isAssistant = lower.startsWith('eva:') || lower.startsWith('assistant:');
      String text = trimmed;
      if (isUser) {
        text = trimmed.substring(5).trim();
      } else if (isAssistant) {
        text = trimmed.substring(trimmed.indexOf(':') + 1).trim();
      }
      result.add({
        'isUser': isUser,
        'sender': isUser ? 'user' : 'assistant',
        'role': isUser ? 'user' : 'assistant',
        'text': text,
        'time': 'Hari Ini',
      });
    }
    return result;
  }

  @override
  Future<List<DiaryEntryModel>> getDiaryEntries({String? moodFilter, String? searchQuery}) async {
    final db = await _getDb();

    // Safely prune abandoned empty test sessions that have 0 turns in conversation_turns
    try {
      await db.rawDelete('''
        DELETE FROM session_summaries 
        WHERE local_account_key = ? 
          AND client_session_id NOT IN (SELECT DISTINCT session_id FROM conversation_turns WHERE local_account_key = ?)
          AND (summary IS NULL OR summary = '' OR summary LIKE 'Panggilan suara selesai%')
      ''', [_accountKey, _accountKey]);
    } catch (_) {}

    final whereClauses = <String>['local_account_key = ?'];
    final whereArgs = <dynamic>[_accountKey];

    if (moodFilter != null && moodFilter.isNotEmpty && moodFilter != 'Semua') {
      whereClauses.add('mood_tag LIKE ?');
      whereArgs.add('%$moodFilter%');
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      whereClauses.add('(title LIKE ? OR summary LIKE ? OR content LIKE ?)');
      whereArgs.add('%$searchQuery%');
      whereArgs.add('%$searchQuery%');
      whereArgs.add('%$searchQuery%');
    }

    final rows = await db.query(
      'journal_entries',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'entry_date_local DESC, updated_at DESC',
    );

    final entries = <DiaryEntryModel>[];
    for (final row in rows) {
      final entryId = row['id'] as String;
      final sessionRows = await db.query(
        'session_summaries',
        where: 'journal_id = ? AND local_account_key = ?',
        whereArgs: [entryId, _accountKey],
        orderBy: 'created_at ASC',
      );

      List<Map<String, dynamic>> emotionsBreakdown = [];
      if (row['emotions_breakdown_json'] != null) {
        try {
          final decoded = jsonDecode(row['emotions_breakdown_json'] as String);
          if (decoded is List) {
            emotionsBreakdown = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        } catch (_) {}
      }

      final contentStr = (row['content'] as String?) ?? '';
      final parsedTranscripts = _parseTranscripts(contentStr);

      final sessions = <DiarySessionSummaryModel>[];
      final seenClientSessionIds = <String>{};

      for (final s in sessionRows) {
        final clientSessId = (s['client_session_id'] as String?) ?? (s['id'] as String);
        if (seenClientSessionIds.contains(clientSessId)) continue;

        // Query real dialogue turns for this specific session from conversation_turns
        final turnRows = await db.query(
          'conversation_turns',
          where: 'session_id = ? AND local_account_key = ?',
          whereArgs: [clientSessId, _accountKey],
          orderBy: 'turn_id ASC, created_at ASC',
        );

        final sSummary = (s['summary'] as String?) ?? '';
        // Skip abandoned/empty test sessions that have no turns and empty summary
        if (turnRows.isEmpty &&
            (sSummary.isEmpty ||
                sSummary.startsWith('Panggilan suara selesai (0') ||
                sSummary.startsWith('Panggilan suara selesai (1') ||
                sSummary.startsWith('Panggilan suara selesai (2'))) {
          continue;
        }

        seenClientSessionIds.add(clientSessId);

        final sessionTranscripts = turnRows.isNotEmpty
            ? turnRows.map((t) {
                final role = (t['role'] as String?) ?? 'user';
                final isUser = role == 'user';
                return {
                  'isUser': isUser,
                  'sender': isUser ? 'user' : 'assistant',
                  'role': role,
                  'text': t['transcript'] as String? ?? '',
                  'time': _formatTime(t['created_at'] as String? ?? ''),
                };
              }).toList()
            : (sSummary.isNotEmpty ? _parseTranscripts(sSummary) : parsedTranscripts);

        List<Map<String, dynamic>> sessionBreakdown = [];
        if (s['emotions_breakdown_json'] != null) {
          try {
            final decoded = jsonDecode(s['emotions_breakdown_json'] as String);
            if (decoded is List) {
              sessionBreakdown = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            }
          } catch (_) {}
        }
        if (sessionBreakdown.isEmpty) {
          sessionBreakdown = emotionsBreakdown;
        }

        sessions.add(
          DiarySessionSummaryModel(
            id: clientSessId,
            title: 'Sesi Dialog Suara ${sessions.length + 1}',
            time: _formatTime(s['created_at'] as String? ?? ''),
            moodTag: row['mood_tag'] as String? ?? 'Tenang',
            moodEmoji: row['mood_emoji'] as String? ?? '😌',
            transcripts: sessionTranscripts,
            emotionsBreakdown: sessionBreakdown,
          ),
        );
      }

      List<String> importantEvents = [];
      if (row['important_events_json'] != null) {
        try {
          final decoded = jsonDecode(row['important_events_json'] as String);
          if (decoded is List) {
            importantEvents = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }

      if (importantEvents.isEmpty ||
          (importantEvents.length == 1 && importantEvents.first == 'Sesi Panggilan EVA')) {
        final summaryStr = (row['summary'] as String?) ?? '';
        if (summaryStr.isNotEmpty) {
          importantEvents = [
            summaryStr.length > 50 ? '${summaryStr.substring(0, 50)}...' : summaryStr,
            'Sesi Dialog Suara Bersama EVA',
          ];
        }
      }

      entries.add(
        DiaryEntryModel(
          id: entryId,
          title: (row['title'] as String?) ?? 'Jurnal Harian',
          date: (row['entry_date_local'] as String?) ?? '',
          sessionCount: sessions.length,
          lastSessionTime: sessions.isNotEmpty ? sessions.last.time : '',
          moodTag: (row['mood_tag'] as String?) ?? 'Tenang',
          moodEmoji: (row['mood_emoji'] as String?) ?? '😌',
          summary: (row['summary'] as String?) ?? '',
          aiInsight: (row['ai_insight'] as String?) ?? '',
          importantEvents: importantEvents,
          emotionalReflection: (row['emotional_reflection'] as String?) ?? '',
          sessions: sessions,
          emotionsBreakdown: emotionsBreakdown,
        ),
      );
    }

    return entries;
  }

  @override
  Future<DiaryEntryModel?> getDiaryEntryById(String id) async {
    final db = await _getDb();

    // Safely prune abandoned empty test sessions that have 0 turns in conversation_turns
    try {
      await db.rawDelete('''
        DELETE FROM session_summaries 
        WHERE local_account_key = ? 
          AND client_session_id NOT IN (SELECT DISTINCT session_id FROM conversation_turns WHERE local_account_key = ?)
          AND (summary IS NULL OR summary = '' OR summary LIKE 'Panggilan suara selesai%')
      ''', [_accountKey, _accountKey]);
    } catch (_) {}

    final rows = await db.query(
      'journal_entries',
      where: 'id = ? AND local_account_key = ?',
      whereArgs: [id, _accountKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    final sessionRows = await db.query(
      'session_summaries',
      where: 'journal_id = ? AND local_account_key = ?',
      whereArgs: [id, _accountKey],
      orderBy: 'created_at ASC',
    );

    List<Map<String, dynamic>> emotionsBreakdown = [];
    if (row['emotions_breakdown_json'] != null) {
      try {
        final decoded = jsonDecode(row['emotions_breakdown_json'] as String);
        if (decoded is List) {
          emotionsBreakdown = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } catch (_) {}
    }

    final contentStr = (row['content'] as String?) ?? '';
    final parsedTranscripts = _parseTranscripts(contentStr);

    final sessions = <DiarySessionSummaryModel>[];
    final seenClientSessionIds = <String>{};

    for (final s in sessionRows) {
      final clientSessId = (s['client_session_id'] as String?) ?? (s['id'] as String);
      if (seenClientSessionIds.contains(clientSessId)) continue;

      // Query real dialogue turns for this specific session from conversation_turns
      final turnRows = await db.query(
        'conversation_turns',
        where: 'session_id = ? AND local_account_key = ?',
        whereArgs: [clientSessId, _accountKey],
        orderBy: 'turn_id ASC, created_at ASC',
      );

      final sSummary = (s['summary'] as String?) ?? '';
      // Skip abandoned/empty test sessions that have no turns and empty summary
      if (turnRows.isEmpty &&
          (sSummary.isEmpty ||
              sSummary.startsWith('Panggilan suara selesai (0') ||
              sSummary.startsWith('Panggilan suara selesai (1') ||
              sSummary.startsWith('Panggilan suara selesai (2'))) {
        continue;
      }

      seenClientSessionIds.add(clientSessId);

      final sessionTranscripts = turnRows.isNotEmpty
          ? turnRows.map((t) {
              final role = (t['role'] as String?) ?? 'user';
              final isUser = role == 'user';
              return {
                'isUser': isUser,
                'sender': isUser ? 'user' : 'assistant',
                'role': role,
                'text': t['transcript'] as String? ?? '',
                'time': _formatTime(t['created_at'] as String? ?? ''),
              };
            }).toList()
          : (sSummary.isNotEmpty ? _parseTranscripts(sSummary) : parsedTranscripts);

      List<Map<String, dynamic>> sessionBreakdown = [];
      if (s['emotions_breakdown_json'] != null) {
        try {
          final decoded = jsonDecode(s['emotions_breakdown_json'] as String);
          if (decoded is List) {
            sessionBreakdown = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        } catch (_) {}
      }
      if (sessionBreakdown.isEmpty) {
        sessionBreakdown = emotionsBreakdown;
      }

      sessions.add(
        DiarySessionSummaryModel(
          id: clientSessId,
          title: 'Sesi Dialog Suara ${sessions.length + 1}',
          time: _formatTime(s['created_at'] as String? ?? ''),
          moodTag: row['mood_tag'] as String? ?? 'Tenang',
          moodEmoji: row['mood_emoji'] as String? ?? '😌',
          transcripts: sessionTranscripts,
          emotionsBreakdown: sessionBreakdown,
        ),
      );
    }

    List<String> importantEvents = [];
    if (row['important_events_json'] != null) {
      try {
        final decoded = jsonDecode(row['important_events_json'] as String);
        if (decoded is List) {
          importantEvents = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    if (importantEvents.isEmpty ||
        (importantEvents.length == 1 && importantEvents.first == 'Sesi Panggilan EVA')) {
      final summaryStr = (row['summary'] as String?) ?? '';
      if (summaryStr.isNotEmpty) {
        importantEvents = [
          summaryStr.length > 50 ? '${summaryStr.substring(0, 50)}...' : summaryStr,
          'Sesi Dialog Suara Bersama EVA',
        ];
      }
    }

    return DiaryEntryModel(
      id: id,
      title: (row['title'] as String?) ?? 'Jurnal Harian',
      date: (row['entry_date_local'] as String?) ?? '',
      sessionCount: sessions.length,
      lastSessionTime: sessions.isNotEmpty ? sessions.last.time : '',
      moodTag: (row['mood_tag'] as String?) ?? 'Tenang',
      moodEmoji: (row['mood_emoji'] as String?) ?? '😌',
      summary: (row['summary'] as String?) ?? '',
      aiInsight: (row['ai_insight'] as String?) ?? '',
      importantEvents: importantEvents,
      emotionalReflection: (row['emotional_reflection'] as String?) ?? '',
      sessions: sessions,
      emotionsBreakdown: emotionsBreakdown,
    );
  }

  @override
  Future<DiaryEntryModel?> getTodayDiary() async {
    final today = _formatWibDate(DateTime.now());
    final db = await _getDb();
    final rows = await db.query(
      'journal_entries',
      where: 'entry_date_local = ? AND local_account_key = ?',
      whereArgs: [today, _accountKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return getDiaryEntryById(rows.first['id'] as String);
  }

  @override
  Future<DiaryEntryModel?> generateTodayDiary() async {
    // Returns current today's diary in local mode
    return getTodayDiary();
  }

  @override
  Future<DiaryEntryModel> createDiaryEntry(String content, String moodTag) async {
    final db = await _getDb();
    final now = DateTime.now();
    final todayStr = _formatWibDate(now);
    final id = 'local_journal_${now.millisecondsSinceEpoch}';

    String emoji = '😌';
    if (moodTag.contains('Bahagia') || moodTag.contains('Senang')) emoji = '😃';
    if (moodTag.contains('Cemas') || moodTag.contains('Takut')) emoji = '😰';
    if (moodTag.contains('Sedih')) emoji = '😢';
    if (moodTag.contains('Marah')) emoji = '😡';

    final entryMap = {
      'id': id,
      'local_account_key': _accountKey,
      'entry_date_local': todayStr,
      'title': 'Refleksi Harian ($todayStr)',
      'summary': content.length > 100 ? '${content.substring(0, 100)}...' : content,
      'content': content,
      'mood_tag': moodTag,
      'mood_emoji': emoji,
      'ai_insight': 'Catatan emosional tersimpan secara aman dalam enkripsi lokal perangkat Anda.',
      'emotional_reflection': 'Terima kasih telah meluangkan waktu mengekspresikan perasaan hari ini.',
      'important_events_json': jsonEncode(['Refleksi mandiri']),
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };

    await db.insert(
      'journal_entries',
      entryMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return (await getDiaryEntryById(id))!;
  }

  @override
  Future<void> deleteDiaryEntry(String id) async {
    final db = await _getDb();
    await db.delete(
      'session_summaries',
      where: 'journal_id = ? AND local_account_key = ?',
      whereArgs: [id, _accountKey],
    );
    await db.delete(
      'journal_entries',
      where: 'id = ? AND local_account_key = ?',
      whereArgs: [id, _accountKey],
    );
  }

  Future<DiaryEntryModel> saveSessionArtifacts({
    required String sessionId,
    required String sessionSummary,
    required Map<String, dynamic> journalDelta,
  }) async {
    final db = await _getDb();
    final now = DateTime.now();
    final todayStr = _formatWibDate(now);

    final existingRows = await db.query(
      'journal_entries',
      where: 'entry_date_local = ? AND local_account_key = ?',
      whereArgs: [todayStr, _accountKey],
      limit: 1,
    );

    final journalId = existingRows.isNotEmpty
        ? existingRows.first['id'] as String
        : 'journal_${now.millisecondsSinceEpoch}';

    final title = journalDelta['title'] as String? ?? 'Refleksi Sesi Panggilan ($todayStr)';
    final summary = journalDelta['summary'] as String? ?? sessionSummary;
    final content = journalDelta['content'] as String? ?? summary;

    final emotionsBreakdown = journalDelta['emotions_breakdown'] is List
        ? (journalDelta['emotions_breakdown'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : <Map<String, dynamic>>[];
    final emotionsJson = jsonEncode(emotionsBreakdown);

    String moodTag = journalDelta['mood_tag'] as String? ?? 'Netral & Tenang 😌';
    String moodEmoji = journalDelta['mood_emoji'] as String? ?? '😌';
    if (emotionsBreakdown.isNotEmpty && (moodTag == 'Netral & Tenang 😌' || moodTag == 'Tenang')) {
      final top = emotionsBreakdown.first;
      final pct = (top['percent'] as num?)?.toDouble() ?? 0.0;
      if (pct >= 0.30) {
        final label = top['label']?.toString() ?? top['name']?.toString() ?? 'Netral';
        final emoji = top['emoji']?.toString() ?? '😌';
        moodTag = '$label $emoji';
        moodEmoji = emoji;
      }
    }

    final aiInsight = journalDelta['ai_insight'] as String? ?? '';
    final emotionalReflection = journalDelta['emotional_reflection'] as String? ?? '';
    final importantEvents = journalDelta['important_events'] is List
        ? (journalDelta['important_events'] as List).map((e) => e.toString()).toList()
        : <String>[];

    final journalMap = {
      'id': journalId,
      'local_account_key': _accountKey,
      'entry_date_local': todayStr,
      'title': title,
      'summary': summary,
      'content': content,
      'mood_tag': moodTag,
      'mood_emoji': moodEmoji,
      'ai_insight': aiInsight,
      'emotional_reflection': emotionalReflection,
      'important_events_json': jsonEncode(importantEvents),
      'emotions_breakdown_json': emotionsJson,
      'created_at': existingRows.isNotEmpty ? existingRows.first['created_at'] : now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };

    await db.insert(
      'journal_entries',
      journalMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final existingSummaries = await db.query(
      'session_summaries',
      where: 'client_session_id = ? AND local_account_key = ?',
      whereArgs: [sessionId, _accountKey],
      limit: 1,
    );

    final summaryId = existingSummaries.isNotEmpty
        ? existingSummaries.first['id'] as String
        : 'sess_sum_${now.millisecondsSinceEpoch}';

    await db.insert(
      'session_summaries',
      {
        'id': summaryId,
        'local_account_key': _accountKey,
        'client_session_id': sessionId,
        'summary': sessionSummary,
        'journal_id': journalId,
        'emotions_breakdown_json': emotionsJson,
        'created_at': existingSummaries.isNotEmpty
            ? existingSummaries.first['created_at']
            : now.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Prune abandoned empty session summaries that have 0 turns in conversation_turns
    try {
      await db.rawDelete('''
        DELETE FROM session_summaries 
        WHERE local_account_key = ? 
          AND journal_id = ?
          AND client_session_id != ?
          AND client_session_id NOT IN (SELECT DISTINCT session_id FROM conversation_turns WHERE local_account_key = ?)
      ''', [_accountKey, journalId, sessionId, _accountKey]);
    } catch (_) {}

    return (await getDiaryEntryById(journalId))!;
  }
}

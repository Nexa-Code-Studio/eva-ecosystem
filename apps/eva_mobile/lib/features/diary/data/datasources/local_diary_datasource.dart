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

  @override
  Future<List<DiaryEntryModel>> getDiaryEntries({String? moodFilter, String? searchQuery}) async {
    final db = await _getDb();
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
      );

      final sessions = sessionRows.map((s) {
        return DiarySessionSummaryModel(
          id: s['id'] as String,
          title: 'Sesi Dialog Suara',
          time: 'Hari Ini',
          moodTag: row['mood_tag'] as String? ?? 'Tenang',
          moodEmoji: row['mood_emoji'] as String? ?? '😌',
          transcripts: const [],
          emotionsBreakdown: const [],
        );
      }).toList();

      List<String> importantEvents = [];
      if (row['important_events_json'] != null) {
        try {
          final decoded = jsonDecode(row['important_events_json'] as String);
          if (decoded is List) {
            importantEvents = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
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
        ),
      );
    }

    return entries;
  }

  @override
  Future<DiaryEntryModel?> getDiaryEntryById(String id) async {
    final db = await _getDb();
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
    );

    final sessions = sessionRows.map((s) {
      return DiarySessionSummaryModel(
        id: s['id'] as String,
        title: 'Sesi Dialog Suara',
        time: 'Hari Ini',
        moodTag: row['mood_tag'] as String? ?? 'Tenang',
        moodEmoji: row['mood_emoji'] as String? ?? '😌',
        transcripts: const [],
        emotionsBreakdown: const [],
      );
    }).toList();

    List<String> importantEvents = [];
    if (row['important_events_json'] != null) {
      try {
        final decoded = jsonDecode(row['important_events_json'] as String);
        if (decoded is List) {
          importantEvents = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
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
    final moodTag = journalDelta['mood_tag'] as String? ?? 'Netral & Tenang 😌';
    final moodEmoji = journalDelta['mood_emoji'] as String? ?? '😌';
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
      'created_at': existingRows.isNotEmpty ? existingRows.first['created_at'] : now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };

    await db.insert(
      'journal_entries',
      journalMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await db.insert(
      'session_summaries',
      {
        'id': 'sess_sum_${now.millisecondsSinceEpoch}',
        'local_account_key': _accountKey,
        'client_session_id': sessionId,
        'summary': sessionSummary,
        'journal_id': journalId,
        'created_at': now.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return (await getDiaryEntryById(journalId))!;
  }
}

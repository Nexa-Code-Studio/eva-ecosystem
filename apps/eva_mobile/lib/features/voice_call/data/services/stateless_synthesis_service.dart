import 'package:flutter/foundation.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/encrypted_local_database.dart';
import '../../../dass/data/datasources/local_dass_datasource.dart';
import '../../../diary/data/datasources/local_diary_datasource.dart';

/// Global application-level service orchestrating real-time incremental dialogue logging,
/// background finalization, and lazy on-demand recovery with stateless cloud synthesis.
class StatelessSynthesisService {
  final EncryptedLocalDatabase _localDb;
  final ApiClient _apiClient;
  final LocalDiaryDataSource _diaryDataSource;
  final LocalDASSDataSource _dassDataSource;
  final String _defaultAccountKey;

  StatelessSynthesisService({
    required EncryptedLocalDatabase localDb,
    ApiClient? apiClient,
    required LocalDiaryDataSource diaryDataSource,
    required LocalDASSDataSource dassDataSource,
    String defaultAccountKey = 'current_user_local',
  })  : _localDb = localDb,
        _apiClient = apiClient ?? ApiClient(),
        _diaryDataSource = diaryDataSource,
        _dassDataSource = dassDataSource,
        _defaultAccountKey = defaultAccountKey;

  String get _accountKey => _localDb.activeAccountKey ?? _defaultAccountKey;

  Future<Database> _getDb() async {
    return _localDb.open(localAccountKey: _accountKey);
  }

  /// Incremental Turn Logger: Persist user and AI dialogue turns immediately to SQLCipher
  Future<void> recordTurn({
    required String sessionId,
    required int turnId,
    required String role,
    required String transcript,
  }) async {
    if (transcript.trim().isEmpty) return;
    try {
      final db = await _getDb();
      final nowIso = DateTime.now().toIso8601String();
      final turnRecordId = '${sessionId}_${turnId}_$role';

      await db.insert(
        'conversation_turns',
        {
          'id': turnRecordId,
          'local_account_key': _accountKey,
          'session_id': sessionId,
          'turn_id': turnId,
          'role': role,
          'transcript': transcript.trim(),
          'created_at': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('💾 [INCREMENTAL TURN SAVED] Session $sessionId | Turn $turnId ($role): "${transcript.trim()}"');
    } catch (e) {
      debugPrint('⚠️ [RECORD TURN ERROR]: $e');
    }
  }

  /// Retrieve all incremental turns for a session from SQLCipher
  Future<List<Map<String, dynamic>>> getSessionTurns(String sessionId) async {
    try {
      final db = await _getDb();
      return await db.query(
        'conversation_turns',
        where: 'local_account_key = ? AND session_id = ?',
        whereArgs: [_accountKey, sessionId],
        orderBy: 'turn_id ASC, created_at ASC',
      );
    } catch (e) {
      debugPrint('⚠️ [GET SESSION TURNS ERROR]: $e');
      return const [];
    }
  }

  /// Check if a session has completed synthesis or is still pending/empty
  Future<bool> isSessionSynthesized(String sessionId) async {
    try {
      final db = await _getDb();
      final rows = await db.query(
        'session_summaries',
        columns: ['synthesis_status'],
        where: 'local_account_key = ? AND client_session_id = ?',
        whereArgs: [_accountKey, sessionId],
        limit: 1,
      );
      if (rows.isEmpty) return false;
      final status = rows.first['synthesis_status'] as String? ?? 'completed';
      return status == 'completed';
    } catch (_) {
      return false;
    }
  }

  /// Mark a session's initial pending status in SQLCipher
  Future<void> markSessionPending({
    required String sessionId,
    required String initialSummary,
  }) async {
    try {
      final db = await _getDb();
      final nowIso = DateTime.now().toIso8601String();
      await db.insert(
        'session_summaries',
        {
          'id': 'sess_$sessionId',
          'local_account_key': _accountKey,
          'client_session_id': sessionId,
          'summary': initialSummary,
          'synthesis_status': 'pending_synthesis',
          'created_at': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('⚠️ [MARK SESSION PENDING ERROR]: $e');
    }
  }

  /// Save synthesized artifacts locally (from WebSocket or REST response)
  Future<void> commitArtifactsLocally({
    required String sessionId,
    required String sessionSummary,
    required Map<String, dynamic> journalDelta,
    Map<String, dynamic>? dassAssessment,
  }) async {
    try {
      // 1. Commit diary & session summary to SQLCipher
      await _diaryDataSource.saveSessionArtifacts(
        sessionId: sessionId,
        sessionSummary: sessionSummary,
        journalDelta: journalDelta,
      );

      final db = await _getDb();
      await db.update(
        'session_summaries',
        {'synthesis_status': 'completed'},
        where: 'local_account_key = ? AND client_session_id = ?',
        whereArgs: [_accountKey, sessionId],
      );

      // 2. Commit DASS-21 evaluation if available
      if (dassAssessment != null && dassAssessment.isNotEmpty) {
        await _dassDataSource.saveExtractedAssessment(
          sessionId: sessionId,
          dassAssessmentPayload: dassAssessment,
        );
      }
      debugPrint('✅ [COMMITTED LOCALLY] Session $sessionId artifacts successfully saved to SQLCipher.');
    } catch (e) {
      debugPrint('⚠️ [COMMIT ARTIFACTS ERROR]: $e');
    }
  }

  /// On-Demand Lazy Synthesis: Triggered when user opens a journal/call detail that is missing synthesis
  Future<bool> synthesizeSessionOnDemand({required String sessionId}) async {
    final turns = await getSessionTurns(sessionId);
    if (turns.isEmpty) {
      debugPrint('ℹ️ [ON-DEMAND SYNTHESIS SKIPPED] No turns found in SQLCipher for session $sessionId');
      return false;
    }

    final turnsPayload = turns.map((t) => {
      'role': t['role'],
      'text': t['transcript'],
      'turn_id': t['turn_id'],
    }).toList();

    try {
      debugPrint('🚀 [ON-DEMAND SYNTHESIS START] Calling stateless endpoint for session $sessionId (${turns.length} turns)');
      final response = await _apiClient.post(
        '/call/synthesize',
        body: {
          'session_id': sessionId,
          'turns': turnsPayload,
          'include_dass': true,
          'include_memory_candidates': true,
        },
      );

      if (response is Map<String, dynamic>) {
        final summary = response['session_summary'] as String? ?? 'Ringkasan sesi panggilan suara.';
        final journalDelta = (response['journal_delta'] as Map<String, dynamic>?) ?? {};
        final dassMap = response['dass_assessment'] as Map<String, dynamic>?;

        await commitArtifactsLocally(
          sessionId: sessionId,
          sessionSummary: summary,
          journalDelta: journalDelta,
          dassAssessment: dassMap,
        );
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ [ON-DEMAND SYNTHESIS FAILED]: $e');
    }
    return false;
  }
}

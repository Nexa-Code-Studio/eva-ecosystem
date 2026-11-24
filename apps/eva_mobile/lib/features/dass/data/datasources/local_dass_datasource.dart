import 'dart:convert';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/encrypted_local_database.dart';
import '../models/dass_assessment_model.dart';
import 'dass_datasource.dart';

/// Local-First encrypted SQLite datasource for DASS-21 psychological self-assessments.
/// Ensures 100% of psychometric scores, evidence quotes, and reasons are stored locally in SQLCipher.
class LocalDASSDataSource implements DASSDataSource {
  final EncryptedLocalDatabase _localDb;
  final ApiClient _apiClient;
  final String _defaultAccountKey;

  LocalDASSDataSource(
    this._localDb, {
    ApiClient? apiClient,
    String defaultAccountKey = 'current_user_local',
  })  : _apiClient = apiClient ?? ApiClient(),
        _defaultAccountKey = defaultAccountKey;

  String get _accountKey => _localDb.activeAccountKey ?? _defaultAccountKey;

  Future<Database> _getDb() async {
    return _localDb.open(localAccountKey: _accountKey);
  }

  String _formatTodayWib() {
    final now = DateTime.now();
    final year = now.year.toString().padLeft(4, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static const List<Map<String, dynamic>> _officialItems = [
    {'item_id': 1, 'scale': 'stress', 'question_text': 'Saya merasa sulit untuk beristirahat atau menenangkan diri'},
    {'item_id': 2, 'scale': 'anxiety', 'question_text': 'Saya menyadari mulut saya terasa kering'},
    {'item_id': 3, 'scale': 'depression', 'question_text': 'Saya sama sekali tidak dapat merasakan perasaan positif'},
    {'item_id': 4, 'scale': 'anxiety', 'question_text': 'Saya mengalami kesulitan bernapas (misal napas cepat tanpa aktivitas fisik)'},
    {'item_id': 5, 'scale': 'depression', 'question_text': 'Saya merasa sulit berinisiatif untuk melakukan sesuatu'},
    {'item_id': 6, 'scale': 'stress', 'question_text': 'Saya cenderung bereaksi berlebihan terhadap suatu situasi'},
    {'item_id': 7, 'scale': 'anxiety', 'question_text': 'Saya mengalami gemetar (misalnya pada kedua tangan)'},
    {'item_id': 8, 'scale': 'stress', 'question_text': 'Saya merasa menghabiskan banyak energi karena terlalu cemas/gugup'},
    {'item_id': 9, 'scale': 'anxiety', 'question_text': 'Saya khawatir terhadap situasi di mana saya mungkin panik atau mempermalukan diri'},
    {'item_id': 10, 'scale': 'depression', 'question_text': 'Saya merasa tidak ada lagi hal baik yang bisa saya harapkan di masa depan'},
    {'item_id': 11, 'scale': 'stress', 'question_text': 'Saya mendapati diri saya mudah gelisah atau resah'},
    {'item_id': 12, 'scale': 'stress', 'question_text': 'Saya merasa sulit untuk rileks atau bersantai'},
    {'item_id': 13, 'scale': 'depression', 'question_text': 'Saya merasa sedih, murung, dan tertekan'},
    {'item_id': 14, 'scale': 'stress', 'question_text': 'Saya tidak sabar menghadapi hal yang menghambat apa yang sedang saya lakukan'},
    {'item_id': 15, 'scale': 'anxiety', 'question_text': 'Saya merasa hampir panik'},
    {'item_id': 16, 'scale': 'depression', 'question_text': 'Saya merasa tidak mampu antusias terhadap hal apa pun'},
    {'item_id': 17, 'scale': 'depression', 'question_text': 'Saya merasa bahwa diri saya tidak berharga'},
    {'item_id': 18, 'scale': 'stress', 'question_text': 'Saya merasa mudah tersinggung atau sensitif'},
    {'item_id': 19, 'scale': 'anxiety', 'question_text': 'Saya menyadari detak jantung saya berdegup kencang tanpa alasan fisik'},
    {'item_id': 20, 'scale': 'anxiety', 'question_text': 'Saya merasa takut tanpa alasan yang jelas'},
    {'item_id': 21, 'scale': 'depression', 'question_text': 'Saya merasa bahwa hidup ini tidak berarti'},
  ];

  static DASSAssessmentModel buildDefaultModel({String? date, String? userId}) {
    final d = date ?? DateTime.now().toIso8601String().substring(0, 10);
    final items = _officialItems.map((spec) {
      return DASSItemModel(
        itemId: spec['item_id'] as int,
        scale: spec['scale'] as String,
        questionText: spec['question_text'] as String,
        score: 0,
        evidence: null,
        reason: null,
        confidence: 0.0,
        isUserEdited: false,
      );
    }).toList();

    return DASSAssessmentModel(
      id: 'dass_default_$d',
      userId: userId ?? 'current_user_local',
      assessedDate: d,
      depressionScore: 0,
      anxietyScore: 0,
      stressScore: 0,
      depressionSeverity: 'Normal',
      anxietySeverity: 'Normal',
      stressSeverity: 'Normal',
      verifiedByUser: false,
      status: 'empty',
      items: items,
    );
  }

  static Map<String, dynamic> calculateSubscales(List<Map<String, dynamic>> items) {
    int depRaw = 0;
    int anxRaw = 0;
    int strRaw = 0;

    for (final it in items) {
      final scale = it['scale']?.toString().toLowerCase() ?? '';
      final score = (it['score'] is num) ? (it['score'] as num).toInt() : int.tryParse(it['score']?.toString() ?? '0') ?? 0;
      if (scale == 'depression') depRaw += score;
      if (scale == 'anxiety') anxRaw += score;
      if (scale == 'stress') strRaw += score;
    }

    final depFinal = depRaw * 2;
    final anxFinal = anxRaw * 2;
    final strFinal = strRaw * 2;

    String depSev = 'Normal';
    if (depFinal >= 28) {
      depSev = 'Extremely Severe';
    } else if (depFinal >= 21) {
      depSev = 'Severe';
    } else if (depFinal >= 14) {
      depSev = 'Moderate';
    } else if (depFinal >= 10) {
      depSev = 'Mild';
    }

    String anxSev = 'Normal';
    if (anxFinal >= 20) {
      anxSev = 'Extremely Severe';
    } else if (anxFinal >= 15) {
      anxSev = 'Severe';
    } else if (anxFinal >= 10) {
      anxSev = 'Moderate';
    } else if (anxFinal >= 8) {
      anxSev = 'Mild';
    }

    String strSev = 'Normal';
    if (strFinal >= 34) {
      strSev = 'Extremely Severe';
    } else if (strFinal >= 26) {
      strSev = 'Severe';
    } else if (strFinal >= 19) {
      strSev = 'Moderate';
    } else if (strFinal >= 15) {
      strSev = 'Mild';
    }

    return {
      'depression_score': depFinal,
      'anxiety_score': anxFinal,
      'stress_score': strFinal,
      'depression_severity': depSev,
      'anxiety_severity': anxSev,
      'stress_severity': strSev,
    };
  }

  @override
  Future<DASSAssessmentModel> getTodayAssessment() async {
    final db = await _getDb();
    final today = _formatTodayWib();

    final rows = await db.query(
      'local_dass_assessments',
      where: 'local_account_key = ? AND assessment_date = ?',
      whereArgs: [_accountKey, today],
      limit: 1,
    );

    if (rows.isEmpty) {
      return buildDefaultModel(date: today, userId: _accountKey);
    }

    final row = rows.first;
    final itemsRaw = row['items_json'] as String? ?? '[]';
    List<dynamic> itemsDecoded = [];
    try {
      itemsDecoded = jsonDecode(itemsRaw) as List<dynamic>;
    } catch (_) {}

    final items = itemsDecoded
        .map((it) => DASSItemModel.fromJson(it as Map<String, dynamic>))
        .toList();

    return DASSAssessmentModel(
      id: row['id'] as String?,
      userId: _accountKey,
      assessedDate: row['assessment_date'] as String? ?? today,
      depressionScore: (row['depression_score'] as int?) ?? 0,
      anxietyScore: (row['anxiety_score'] as int?) ?? 0,
      stressScore: (row['stress_score'] as int?) ?? 0,
      depressionSeverity: row['depression_category'] as String? ?? 'Normal',
      anxietySeverity: row['anxiety_category'] as String? ?? 'Normal',
      stressSeverity: row['stress_category'] as String? ?? 'Normal',
      verifiedByUser: (row['is_user_verified'] as int? ?? 0) == 1,
      status: ((row['is_user_verified'] as int? ?? 0) == 1) ? 'verified' : 'auto_extracted',
      items: items,
    );
  }

  @override
  Future<DASSAssessmentModel> updateAssessment(List<Map<String, dynamic>> items) async {
    final db = await _getDb();
    final today = _formatTodayWib();
    final subscales = calculateSubscales(items);
    final nowIso = DateTime.now().toIso8601String();
    final itemsJson = jsonEncode(items);

    final id = 'dass_${_accountKey}_$today';
    await db.insert(
      'local_dass_assessments',
      {
        'id': id,
        'local_account_key': _accountKey,
        'assessment_date': today,
        'stress_score': subscales['stress_score'],
        'anxiety_score': subscales['anxiety_score'],
        'depression_score': subscales['depression_score'],
        'stress_category': subscales['stress_severity'],
        'anxiety_category': subscales['anxiety_severity'],
        'depression_category': subscales['depression_severity'],
        'items_json': itemsJson,
        'is_user_verified': 1,
        'created_at': nowIso,
        'updated_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final parsedItems = items.map((it) => DASSItemModel.fromJson(it)).toList();
    return DASSAssessmentModel(
      id: id,
      userId: _accountKey,
      assessedDate: today,
      depressionScore: subscales['depression_score'] as int,
      anxietyScore: subscales['anxiety_score'] as int,
      stressScore: subscales['stress_score'] as int,
      depressionSeverity: subscales['depression_severity'] as String,
      anxietySeverity: subscales['anxiety_severity'] as String,
      stressSeverity: subscales['stress_severity'] as String,
      verifiedByUser: true,
      status: 'verified',
      items: parsedItems,
    );
  }

  Future<void> saveExtractedAssessment({
    required String sessionId,
    required Map<String, dynamic> dassAssessmentPayload,
  }) async {
    final db = await _getDb();
    final today = _formatTodayWib();
    final nowIso = DateTime.now().toIso8601String();

    final rawItems = dassAssessmentPayload['items'] as List<dynamic>? ?? [];
    final itemsJson = jsonEncode(rawItems);
    final stressScore = (dassAssessmentPayload['stress_score'] as num?)?.toInt() ?? 0;
    final anxietyScore = (dassAssessmentPayload['anxiety_score'] as num?)?.toInt() ?? 0;
    final depressionScore = (dassAssessmentPayload['depression_score'] as num?)?.toInt() ?? 0;
    final stressCat = dassAssessmentPayload['stress_category']?.toString() ?? 'Normal';
    final anxietyCat = dassAssessmentPayload['anxiety_category']?.toString() ?? 'Normal';
    final depCat = dassAssessmentPayload['depression_category']?.toString() ?? 'Normal';

    final id = 'dass_${_accountKey}_$today';
    await db.insert(
      'local_dass_assessments',
      {
        'id': id,
        'local_account_key': _accountKey,
        'assessment_date': today,
        'stress_score': stressScore,
        'anxiety_score': anxietyScore,
        'depression_score': depressionScore,
        'stress_category': stressCat,
        'anxiety_category': anxietyCat,
        'depression_category': depCat,
        'items_json': itemsJson,
        'source_session_id': sessionId,
        'is_user_verified': 0,
        'created_at': nowIso,
        'updated_at': nowIso,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<DASSAssessmentModel> extractTodayAssessment() async {
    final db = await _getDb();
    final today = _formatTodayWib();

    // Query today's conversation turns from local encrypted database
    final turns = await db.query(
      'conversation_turns',
      where: 'local_account_key = ?',
      whereArgs: [_accountKey],
      orderBy: 'created_at ASC',
    );

    if (turns.isEmpty) {
      return getTodayAssessment();
    }

    final turnsPayload = turns.map((t) => {
      'role': t['role'],
      'text': t['transcript'],
      'turn_id': t['turn_id'],
    }).toList();

    try {
      final resp = await _apiClient.post(
        '/call/synthesize',
        body: {
          'session_id': 'manual_extract_$today',
          'turns': turnsPayload,
          'include_dass': true,
          'include_memory_candidates': false,
        },
      );

      if (resp is Map<String, dynamic> && resp['dass_assessment'] != null) {
        final dassMap = resp['dass_assessment'] as Map<String, dynamic>;
        await saveExtractedAssessment(
          sessionId: 'manual_extract_$today',
          dassAssessmentPayload: dassMap,
        );
        return getTodayAssessment();
      }
    } catch (_) {}

    return getTodayAssessment();
  }
}

import 'dart:async';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../../../../core/storage/encrypted_local_database.dart';
import '../models/monitoring_data_model.dart';
import 'monitoring_datasource.dart';

/// On-device local analytics datasource that aggregates emotion distributions
/// and resilience metrics directly from SQLite (SQLCipher) without cloud leakage.
class LocalMonitoringDataSource implements MonitoringDataSource {
  final EncryptedLocalDatabase _localDb;
  final String _defaultAccountKey;

  LocalMonitoringDataSource(this._localDb, {String defaultAccountKey = 'current_user_local'})
      : _defaultAccountKey = defaultAccountKey;

  String get _accountKey => _localDb.activeAccountKey ?? _defaultAccountKey;

  Future<Database> _getDb() async {
    return _localDb.open(localAccountKey: _accountKey);
  }

  // 7 Emotion parameters matching design system & StackedEmotionChartPainter:
  // [happy, netral, fear, sadness, surprise, anger, disgusted]
  static const int _idxHappy = 0;
  static const int _idxNetral = 1;
  static const int _idxFear = 2;
  static const int _idxSadness = 3;
  static const int _idxSurprise = 4;
  static const int _idxAnger = 5;
  static const int _idxDisgusted = 6;

  int _mapMoodTagToEmotionIndex(String moodTag) {
    final lower = moodTag.toLowerCase();
    if (lower.contains('bahagia') || lower.contains('senang') || lower.contains('happy')) {
      return _idxHappy;
    }
    if (lower.contains('cemas') || lower.contains('takut') || lower.contains('anxiety') || lower.contains('fear')) {
      return _idxFear;
    }
    if (lower.contains('sedih') || lower.contains('sadness') || lower.contains('depresi')) {
      return _idxSadness;
    }
    if (lower.contains('terkejut') || lower.contains('kaget') || lower.contains('surprise')) {
      return _idxSurprise;
    }
    if (lower.contains('marah') || lower.contains('kesal') || lower.contains('anger')) {
      return _idxAnger;
    }
    if (lower.contains('jijik') || lower.contains('muak') || lower.contains('disgusted')) {
      return _idxDisgusted;
    }
    return _idxNetral;
  }

  @override
  Future<MonitoringDataModel> getMonitoringData(String periodKey) async {
    try {
      final db = await _getDb();

      // Query on-device journal entries
      final rows = await db.query(
        'journal_entries',
        where: 'local_account_key = ?',
        whereArgs: [_accountKey],
        orderBy: 'entry_date_local DESC',
        limit: 30,
      );

      final periodLabel = switch (periodKey) {
        'week' => 'Minggu Ini',
        'month' => 'Bulan Ini',
        _ => 'Hari Ini',
      };

      // If no entries exist on-device, return clean empty model
      if (rows.isEmpty) {
        return MonitoringDataModel.empty(periodKey);
      }

    // Tally emotions from on-device entries
    int happyCount = 0;
    int netralCount = 0;
    int fearCount = 0;
    int sadnessCount = 0;
    int angerCount = 0;

    for (final row in rows) {
      final tag = (row['mood_tag'] as String?) ?? '';
      final idx = _mapMoodTagToEmotionIndex(tag);
      if (idx == _idxHappy) {
        happyCount++;
      } else if (idx == _idxNetral) {
        netralCount++;
      } else if (idx == _idxFear) {
        fearCount++;
      } else if (idx == _idxSadness) {
        sadnessCount++;
      } else if (idx == _idxAnger) {
        angerCount++;
      }
    }

    final totalEntries = rows.length;

    // Check if local DASS assessment exists in SQLCipher to populate clinical risk meters
    final dassRows = await db.query(
      'local_dass_assessments',
      where: 'local_account_key = ?',
      whereArgs: [_accountKey],
      orderBy: 'assessment_date DESC',
      limit: 1,
    );

    double stressRatio = 0.0;
    double fearRatio = 0.0;
    double depressionRatio = 0.0;

    if (dassRows.isNotEmpty) {
      final dRow = dassRows.first;
      final dStr = (dRow['stress_score'] as int? ?? 0) / 42.0;
      final dAnx = (dRow['anxiety_score'] as int? ?? 0) / 42.0;
      final dDep = (dRow['depression_score'] as int? ?? 0) / 42.0;
      stressRatio = dStr.clamp(0.0, 1.0);
      fearRatio = dAnx.clamp(0.0, 1.0);
      depressionRatio = dDep.clamp(0.0, 1.0);
    } else {
      fearRatio = totalEntries > 0 ? (fearCount / totalEntries).clamp(0.0, 1.0) : 0.0;
      stressRatio = totalEntries > 0 ? ((fearCount + angerCount) / totalEntries).clamp(0.0, 1.0) : 0.0;
      depressionRatio = totalEntries > 0 ? (sadnessCount / totalEntries).clamp(0.0, 1.0) : 0.0;
    }

    String getRiskLabel(double ratio) {
      final pct = (ratio * 100).toInt();
      if (ratio >= 0.6) return 'Tinggi ($pct%)';
      if (ratio >= 0.3) return 'Sedang ($pct%)';
      return 'Rendah ($pct%)';
    }

    final xLabels = switch (periodKey) {
      'week' => const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'],
      'month' => const ['Mgg 1', 'Mgg 2', 'Mgg 3', 'Mgg 4'],
      _ => const ['06:00', '09:00', '12:00', '15:00', '18:00', '21:00'],
    };

    // Build chart rows with actual ratios
    final chartData = List.generate(xLabels.length, (i) {
      double h = (happyCount / totalEntries) * 0.4;
      double n = (netralCount / totalEntries) * 0.4 + 0.2;
      double f = fearRatio * 0.3;
      double s = depressionRatio * 0.1;
      final sum = h + n + f + s;
      if (sum > 0) {
        h /= sum;
        n /= sum;
        f /= sum;
        s /= sum;
      }
      return [h, n, f, s, 0.0, 0.0, 0.0];
    });

    final int emotionalLevel = (happyCount + netralCount) >= (fearCount + sadnessCount + angerCount)
        ? (happyCount > netralCount ? 5 : 4)
        : (fearCount > sadnessCount ? 2 : 1);

    final (statusLabel, statusColor) = switch (emotionalLevel) {
      5 => ('Sangat Baik & Positif', '#2E7D32'),
      4 => ('Baik & Stabil', '#2E7D32'),
      3 => ('Cukup Stabil', '#F57F17'),
      2 => ('Butuh Istirahat (Sedang)', '#FB8C00'),
      _ => ('Beban Emosional Berat', '#D32F2F'),
    };

    return MonitoringDataModel(
      periodKey: periodKey,
      periodLabel: periodLabel,
      summary: 'Berdasarkan $totalEntries sesi refleksi lokal, emosi dominan terpantau ${rows.first['mood_tag'] ?? 'stabil'}.',
      emotionalCenter: EmotionalCenterModel(
        status: statusLabel,
        level: emotionalLevel,
        description: 'Tingkat kesadaran emosional Anda terangkum aman di perangkat ini.',
        textColorHex: statusColor,
      ),
      risks: [
        RiskIndicatorModel(
          name: 'Risiko Stres',
          type: 'stress',
          percent: double.parse(stressRatio.toStringAsFixed(2)),
          levelLabel: getRiskLabel(stressRatio),
          colorHex: stressRatio >= 0.6 ? '#D32F2F' : (stressRatio >= 0.3 ? '#FB8C00' : '#4CAF50'),
          badgeBgHex: stressRatio >= 0.6 ? '#FFDCDD' : (stressRatio >= 0.3 ? '#FFF3E0' : '#E8F5E9'),
        ),
        RiskIndicatorModel(
          name: 'Risiko Anxiety',
          type: 'anxiety',
          percent: double.parse(fearRatio.toStringAsFixed(2)),
          levelLabel: getRiskLabel(fearRatio),
          colorHex: fearRatio >= 0.6 ? '#D32F2F' : (fearRatio >= 0.3 ? '#FB8C00' : '#489BB8'),
          badgeBgHex: fearRatio >= 0.6 ? '#FFDCDD' : (fearRatio >= 0.3 ? '#FFF3E0' : '#E0F4FB'),
        ),
        RiskIndicatorModel(
          name: 'Risiko Depresi',
          type: 'depresi',
          percent: double.parse(depressionRatio.toStringAsFixed(2)),
          levelLabel: getRiskLabel(depressionRatio),
          colorHex: depressionRatio >= 0.6 ? '#D32F2F' : (depressionRatio >= 0.3 ? '#FB8C00' : '#4CAF50'),
          badgeBgHex: depressionRatio >= 0.6 ? '#FFDCDD' : (depressionRatio >= 0.3 ? '#FFF3E0' : '#E8F5E9'),
        ),
      ],
      xLabels: xLabels,
      chartData: chartData,
    );
    } catch (_) {
      return MonitoringDataModel.empty(periodKey);
    }
  }
}

import '../../domain/entities/patient_entity.dart';

class PatientResponseDto {
  final String id;
  final String name;
  final int age;
  final String gender;
  final String chiefComplaint;
  final String latestMoodTag;
  final int emotionalRiskScore;
  final bool isHighRisk;
  final bool hasConsent;
  final String lastSessionDate;
  final int totalCompletedSessions;
  final String? consentRequestedAt;
  final List<DassAssessmentDto>? dassHistory;
  final List<String>? sharedDiarySummaries;
  final List<Map<String, dynamic>>? triggers;
  final List<String>? clinicalPoints;
  final PatientScheduleDto? upcomingSchedule;

  const PatientResponseDto({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.chiefComplaint,
    required this.latestMoodTag,
    required this.emotionalRiskScore,
    required this.isHighRisk,
    required this.hasConsent,
    required this.lastSessionDate,
    required this.totalCompletedSessions,
    this.consentRequestedAt,
    this.dassHistory,
    this.sharedDiarySummaries,
    this.triggers,
    this.clinicalPoints,
    this.upcomingSchedule,
  });

  factory PatientResponseDto.fromJson(Map<String, dynamic> json) {
    return PatientResponseDto(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Pasien',
      age: json['age'] as int? ?? 25,
      gender: json['gender']?.toString() ?? 'L',
      chiefComplaint: json['chief_complaint']?.toString() ?? '-',
      latestMoodTag: json['latest_mood_tag']?.toString() ?? 'Tenang & Nyaman',
      emotionalRiskScore: json['emotional_risk_score'] as int? ?? 2,
      isHighRisk: json['is_high_risk'] as bool? ?? false,
      hasConsent: json['has_consent'] as bool? ?? false,
      lastSessionDate: json['last_session_date']?.toString() ??
          DateTime.now().toIso8601String(),
      totalCompletedSessions: json['total_completed_sessions'] as int? ?? 0,
      consentRequestedAt: json['consent_requested_at']?.toString(),
      dassHistory: (json['dass_history'] as List<dynamic>?)
          ?.map((d) => DassAssessmentDto.fromJson(d as Map<String, dynamic>))
          .toList(),
      sharedDiarySummaries: (json['shared_diary_summaries'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      triggers: (json['triggers'] as List<dynamic>?)
          ?.map((t) => Map<String, dynamic>.from(t as Map))
          .toList(),
      clinicalPoints: (json['clinical_points'] as List<dynamic>?)
          ?.map((p) => p.toString())
          .toList(),
      upcomingSchedule: json['upcoming_schedule'] != null
          ? PatientScheduleDto.fromJson(json['upcoming_schedule'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age': age,
        'gender': gender,
        'chief_complaint': chiefComplaint,
        'latest_mood_tag': latestMoodTag,
        'emotional_risk_score': emotionalRiskScore,
        'is_high_risk': isHighRisk,
        'has_consent': hasConsent,
        'last_session_date': lastSessionDate,
        'total_completed_sessions': totalCompletedSessions,
        'consent_requested_at': consentRequestedAt,
        'dass_history': dassHistory?.map((e) => e.toJson()).toList(),
        'shared_diary_summaries': sharedDiarySummaries,
        'triggers': triggers,
        'clinical_points': clinicalPoints,
        'upcoming_schedule': upcomingSchedule?.toJson(),
      };

  PatientEntity toEntity() {
    return PatientEntity(
      id: id,
      name: name,
      age: age,
      gender: gender,
      chiefComplaint: chiefComplaint,
      latestMoodTag: latestMoodTag,
      emotionalRiskScore: emotionalRiskScore,
      isHighRisk: isHighRisk,
      hasConsent: hasConsent,
      lastSessionDate: DateTime.tryParse(lastSessionDate) ?? DateTime.now(),
      totalCompletedSessions: totalCompletedSessions,
      consentRequestedAt: consentRequestedAt,
      dassHistory: dassHistory?.map((e) => e.toEntity()).toList(),
      sharedDiarySummaries: sharedDiarySummaries,
      triggers: triggers,
      clinicalPoints: clinicalPoints,
      upcomingSchedule: upcomingSchedule?.toEntity(),
    );
  }
}

class PatientScheduleDto {
  final String formattedTime;
  final String dateLabel;
  final String timeRange;
  final bool isLiveNow;
  final String roomOpensAt;
  final String statusText;
  final String? sessionId;
  final bool isCompleted;

  const PatientScheduleDto({
    required this.formattedTime,
    required this.dateLabel,
    required this.timeRange,
    required this.isLiveNow,
    required this.roomOpensAt,
    required this.statusText,
    this.sessionId,
    this.isCompleted = false,
  });

  factory PatientScheduleDto.fromJson(Map<String, dynamic> json) {
    String formattedTime = json['formatted_time']?.toString() ?? '';
    String dateLabel = json['date_label']?.toString() ?? '';
    String timeRange = json['time_range']?.toString() ?? '';
    bool isLiveNow = json['is_live_now'] as bool? ?? false;
    String roomOpensAt = json['room_opens_at']?.toString() ?? '';
    String statusText = json['status_text']?.toString() ?? '';
    final sessionId = json['session_id']?.toString();

    final startTimeStr = json['scheduled_start_time']?.toString();
    if (startTimeStr != null && startTimeStr.isNotEmpty) {
      final startTime = DateTime.tryParse(startTimeStr)?.toLocal();
      if (startTime != null) {
        final durationMinutes = json['duration_minutes'] as int? ?? 30;
        final endTime = startTime.add(Duration(minutes: durationMinutes));

        final startHour = startTime.hour.toString().padLeft(2, '0');
        final startMin = startTime.minute.toString().padLeft(2, '0');
        final endHour = endTime.hour.toString().padLeft(2, '0');
        final endMin = endTime.minute.toString().padLeft(2, '0');

        if (timeRange.isEmpty) {
          timeRange = '$startHour:$startMin - $endHour:$endMin WIB';
        }
        if (formattedTime.isEmpty) {
          formattedTime = 'Hari Ini • $timeRange';
        }
        if (roomOpensAt.isEmpty) {
          final opens = startTime.subtract(const Duration(minutes: 15));
          roomOpensAt =
              '${opens.hour.toString().padLeft(2, '0')}:${opens.minute.toString().padLeft(2, '0')} WIB';
        }

        final now = DateTime.now();
        final diffStart = startTime.difference(now).inMinutes;
        final diffEnd = now.difference(endTime).inMinutes;
        if (diffStart <= 15 && diffEnd <= 15) {
          isLiveNow = true;
        }
        if (statusText.isEmpty) {
          statusText = isLiveNow ? 'Live' : 'Terjadwal';
        }
      }
    }

    return PatientScheduleDto(
      formattedTime: formattedTime,
      dateLabel: dateLabel,
      timeRange: timeRange,
      isLiveNow: isLiveNow,
      roomOpensAt: roomOpensAt,
      statusText: statusText,
      sessionId: sessionId,
      isCompleted: json['is_completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'formatted_time': formattedTime,
        'date_label': dateLabel,
        'time_range': timeRange,
        'is_live_now': isLiveNow,
        'room_opens_at': roomOpensAt,
        'status_text': statusText,
        'session_id': sessionId,
        'is_completed': isCompleted,
      };

  PatientScheduleInfo toEntity() {
    return PatientScheduleInfo(
      formattedTime: formattedTime,
      dateLabel: dateLabel,
      timeRange: timeRange,
      isLiveNow: isLiveNow,
      roomOpensAt: roomOpensAt,
      statusText: statusText,
      sessionId: sessionId,
      isCompleted: isCompleted,
    );
  }
}

class DassAssessmentDto {
  final String date;
  final int depressionScore;
  final int anxietyScore;
  final int stressScore;
  final String severityLabel;

  const DassAssessmentDto({
    required this.date,
    required this.depressionScore,
    required this.anxietyScore,
    required this.stressScore,
    required this.severityLabel,
  });

  factory DassAssessmentDto.fromJson(Map<String, dynamic> json) {
    return DassAssessmentDto(
      date: json['date']?.toString() ?? DateTime.now().toIso8601String(),
      depressionScore: json['depression_score'] as int? ?? 0,
      anxietyScore: json['anxiety_score'] as int? ?? 0,
      stressScore: json['stress_score'] as int? ?? 0,
      severityLabel: json['severity_label']?.toString() ?? 'Normal',
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'depression_score': depressionScore,
        'anxiety_score': anxietyScore,
        'stress_score': stressScore,
        'severity_label': severityLabel,
      };

  DassAssessmentRecord toEntity() {
    return DassAssessmentRecord(
      date: DateTime.tryParse(date) ?? DateTime.now(),
      depressionScore: depressionScore,
      anxietyScore: anxietyScore,
      stressScore: stressScore,
      severityLabel: severityLabel,
    );
  }
}

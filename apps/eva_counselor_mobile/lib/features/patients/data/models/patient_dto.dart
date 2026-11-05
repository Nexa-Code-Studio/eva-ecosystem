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

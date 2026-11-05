class PatientEntity {
  final String id;
  final String name; // e.g., 'Budi Santoso'
  final int age;
  final String gender;
  final String chiefComplaint; // Keluhan utama
  final String latestMoodTag; // e.g. 'Cemas Sedang', 'Tenang & Nyaman'
  final int emotionalRiskScore; // 1-10
  final bool isHighRisk; // Emergency alert trigger
  final bool hasConsent; // True if patient gave access to emotional record & DASS
  final DateTime lastSessionDate;
  final int totalCompletedSessions;
  final String? consentRequestedAt;
  final List<DassAssessmentRecord>? dassHistory;
  final List<String>? sharedDiarySummaries;

  const PatientEntity({
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
}

class DassAssessmentRecord {
  final DateTime date;
  final int depressionScore;
  final int anxietyScore;
  final int stressScore;
  final String severityLabel;

  const DassAssessmentRecord({
    required this.date,
    required this.depressionScore,
    required this.anxietyScore,
    required this.stressScore,
    required this.severityLabel,
  });
}

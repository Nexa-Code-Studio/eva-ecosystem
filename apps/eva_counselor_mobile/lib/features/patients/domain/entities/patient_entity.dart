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
  final PatientScheduleInfo? upcomingSchedule;

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
    this.upcomingSchedule,
  });
}

class PatientScheduleInfo {
  final String formattedTime; // e.g. 'Hari Ini • 10:00 - 10:50 WIB'
  final String dateLabel; // e.g. 'Selasa, 11 Nov 2026'
  final String timeRange; // e.g. '10:00 - 10:50 WIB'
  final bool isLiveNow; // true jika waktu sesi sudah masuk / toleransi 15 mnt
  final String roomOpensAt; // e.g. '09:45 WIB'
  final String statusText; // e.g. 'Mulai dalam 15 Mnt', 'Menunggu Waktu Sesi'
  final String? sessionId;

  const PatientScheduleInfo({
    required this.formattedTime,
    required this.dateLabel,
    required this.timeRange,
    required this.isLiveNow,
    required this.roomOpensAt,
    required this.statusText,
    this.sessionId,
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

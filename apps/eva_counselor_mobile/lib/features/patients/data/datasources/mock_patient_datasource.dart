import '../models/clinical_note_dto.dart';
import '../models/patient_dto.dart';
import 'patient_datasource.dart';

class MockPatientDataSource implements PatientDataSource {
  final List<PatientResponseDto> _mockPatients = [
    PatientResponseDto(
      id: 'patient-001',
      name: 'Rian Pratama',
      age: 26,
      gender: 'Laki-laki',
      chiefComplaint: 'Kecemasan akademik & insomnia menjelang ujian tesis',
      latestMoodTag: 'Cemas Sedang 😟',
      emotionalRiskScore: 6,
      isHighRisk: false,
      hasConsent: true, // Consent granted: Psychologist can see details
      lastSessionDate: DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      totalCompletedSessions: 3,
      dassHistory: [
        DassAssessmentDto(
          date: DateTime.now().subtract(const Duration(days: 14)).toIso8601String(),
          depressionScore: 12,
          anxietyScore: 18,
          stressScore: 22,
          severityLabel: 'Kecemasan Sedang - Stres Parah',
        ),
        DassAssessmentDto(
          date: DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
          depressionScore: 8,
          anxietyScore: 12,
          stressScore: 14,
          severityLabel: 'Membaik (Stres Ringan)',
        ),
      ],
      sharedDiarySummaries: [
        'Sesi 1: Pasien mengeluhkan palpitasi jantung saat memikirkan revisi bab 4.',
        'Sesi 2: Pasien mencoba teknik grounding 5-4-3-2-1 dan merasa lebih stabil.',
        'Sesi 3: Pasien berhasil tidur 6 jam tanpa terbangun tengah malam.',
      ],
      upcomingSchedule: const PatientScheduleDto(
        formattedTime: 'Hari Ini • 10:00 - 10:50 WIB',
        dateLabel: 'Selasa, 11 Nov 2026',
        timeRange: '10:00 - 10:50 WIB',
        isLiveNow: true,
        roomOpensAt: '09:45 WIB (Telah Dibuka)',
        statusText: 'Sesi Siap Dimulai (Live)',
        sessionId: 'session-live-001',
      ),
    ),
    PatientResponseDto(
      id: 'patient-002',
      name: 'Dinda Kirana',
      age: 23,
      gender: 'Perempuan',
      chiefComplaint: 'Burnout pekerjaan, overthinking berat dan serangan panik',
      latestMoodTag: 'Indikasi Krisis Darurat 🚨',
      emotionalRiskScore: 9,
      isHighRisk: true, // High Risk Alert!
      hasConsent: true,
      lastSessionDate: DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      totalCompletedSessions: 1,
      dassHistory: [
        DassAssessmentDto(
          date: DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          depressionScore: 24,
          anxietyScore: 28,
          stressScore: 32,
          severityLabel: 'Sangat Parah (Protokol De-eskalasi Aktif)',
        ),
      ],
      sharedDiarySummaries: [
        'Sesi 1: Krisis kecemasan akut. Protokol keselamatan 119 ext 8 diaktifkan.',
      ],
      upcomingSchedule: const PatientScheduleDto(
        formattedTime: 'Hari Ini • 14:00 - 14:50 WIB',
        dateLabel: 'Selasa, 11 Nov 2026',
        timeRange: '14:00 - 14:50 WIB',
        isLiveNow: false,
        roomOpensAt: '13:45 WIB',
        statusText: 'Menunggu Waktu Sesi (14:00 WIB)',
        sessionId: 'session-live-002',
      ),
    ),
    PatientResponseDto(
      id: 'patient-003',
      name: 'Aditya Nugraha',
      age: 29,
      gender: 'Laki-laki',
      chiefComplaint: 'Masalah komunikasi relasi dan regulasi emosi amarah',
      latestMoodTag: 'Khawatir 😐',
      emotionalRiskScore: 4,
      isHighRisk: false,
      hasConsent: false, // Consent NOT granted yet! Testing privacy guard
      lastSessionDate: DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      totalCompletedSessions: 2,
      consentRequestedAt: null,
      dassHistory: null,
      sharedDiarySummaries: null,
      upcomingSchedule: null, // Sesi lalu selesai, belum ada reservasi baru
    ),
    PatientResponseDto(
      id: 'patient-004',
      name: 'Maya Lestari',
      age: 21,
      gender: 'Perempuan',
      chiefComplaint: 'Krisis identitas kuartal hidup (Quarter-life crisis)',
      latestMoodTag: 'Tenang & Nyaman 🌿',
      emotionalRiskScore: 3,
      isHighRisk: false,
      hasConsent: true,
      lastSessionDate: DateTime.now().subtract(const Duration(days: 8)).toIso8601String(),
      totalCompletedSessions: 4,
      dassHistory: [
        DassAssessmentDto(
          date: DateTime.now().subtract(const Duration(days: 8)).toIso8601String(),
          depressionScore: 6,
          anxietyScore: 6,
          stressScore: 10,
          severityLabel: 'Normal - Terkendali Baik',
        ),
      ],
      sharedDiarySummaries: [
        'Sesi 4: Pasien merasa tujuan kariernya sudah mulai jelas dan optimis.',
      ],
      upcomingSchedule: const PatientScheduleDto(
        formattedTime: 'Besok Rabu, 12 Nov • 11:00 - 11:50 WIB',
        dateLabel: 'Rabu, 12 Nov 2026',
        timeRange: '11:00 - 11:50 WIB',
        isLiveNow: false,
        roomOpensAt: 'Rabu, 10:45 WIB',
        statusText: 'Terkonfirmasi Mendatang',
        sessionId: 'session-live-004',
      ),
    ),
  ];

  final Map<String, List<ClinicalNoteResponseDto>> _mockNotes = {
    'patient-001': [
      ClinicalNoteResponseDto(
        id: 'note-001',
        patientId: 'patient-001',
        sessionId: 'session-prev-001',
        createdAt: DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        subjective: 'Pasien menyatakan masih cemas jika dosen pembimbing membalas chat.',
        objective: 'Kontak mata membaik, nafas lebih teratur dibanding sesi pertama.',
        assessment: 'Kecemasan performansi akademik dengan distorsi kognitif katastrofik.',
        plan: 'Latihan Cognitive Restructuring, restrukturisasi pikiran negatif, pacer napas.',
        recommendedTasks: [
          'Jurnal Pikiran Otomatis (CBT Thought Record)',
          'Latihan pernapasan diafragma 5 menit sebelum membuka revisi',
        ],
      ),
    ],
  };

  @override
  Future<List<PatientResponseDto>> fetchPatients() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _mockPatients;
  }

  @override
  Future<PatientResponseDto> fetchPatientDetail(String patientId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockPatients.firstWhere(
      (p) => p.id == patientId,
      orElse: () => _mockPatients.first,
    );
  }

  @override
  Future<bool> sendConsentRequest(String patientId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final idx = _mockPatients.indexWhere((p) => p.id == patientId);
    if (idx != -1) {
      final p = _mockPatients[idx];
      _mockPatients[idx] = PatientResponseDto(
        id: p.id,
        name: p.name,
        age: p.age,
        gender: p.gender,
        chiefComplaint: p.chiefComplaint,
        latestMoodTag: p.latestMoodTag,
        emotionalRiskScore: p.emotionalRiskScore,
        isHighRisk: p.isHighRisk,
        hasConsent: false,
        lastSessionDate: p.lastSessionDate,
        totalCompletedSessions: p.totalCompletedSessions,
        consentRequestedAt: DateTime.now().toIso8601String(),
        dassHistory: p.dassHistory,
        sharedDiarySummaries: p.sharedDiarySummaries,
      );
    }
    return true;
  }

  @override
  Future<List<ClinicalNoteResponseDto>> fetchClinicalNotes(String patientId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockNotes[patientId] ?? [];
  }

  @override
  Future<ClinicalNoteResponseDto> createClinicalNote(
      CreateClinicalNoteRequestDto request) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final newNote = ClinicalNoteResponseDto(
      id: 'note-${DateTime.now().millisecondsSinceEpoch}',
      patientId: request.patientId,
      sessionId: request.sessionId,
      createdAt: DateTime.now().toIso8601String(),
      subjective: request.subjective,
      objective: request.objective,
      assessment: request.assessment,
      plan: request.plan,
      recommendedTasks: request.recommendedTasks,
    );
    _mockNotes.putIfAbsent(request.patientId, () => []).insert(0, newNote);
    return newNote;
  }
}

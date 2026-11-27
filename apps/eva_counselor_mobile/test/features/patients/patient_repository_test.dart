import 'package:flutter_test/flutter_test.dart';
import 'package:eva_counselor_mobile/features/patients/data/datasources/mock_patient_datasource.dart';
import 'package:eva_counselor_mobile/features/patients/data/repositories/patient_repository_impl.dart';

void main() {
  group('PatientRepository & Consent Gating Tests', () {
    late PatientRepositoryImpl repository;
    late MockPatientDataSource mockDataSource;

    setUp(() {
      mockDataSource = MockPatientDataSource();
      repository = PatientRepositoryImpl(dataSource: mockDataSource);
    });

    test('getPatients returns list of mapped domain entities', () async {
      final patients = await repository.getPatients();
      expect(patients.isNotEmpty, true);
      expect(patients.any((p) => p.name == 'Rian Pratama'), true);
    });

    test('Patient with hasConsent == true provides access to emotional history', () async {
      final patients = await repository.getPatients();
      final consentPatient = patients.firstWhere((p) => p.hasConsent);

      expect(consentPatient.hasConsent, true);
      expect(consentPatient.dassHistory, isNotNull);
      expect(consentPatient.dassHistory!.isNotEmpty, true);
    });

    test('Patient with hasConsent == false hides sensitive emotional records', () async {
      final patients = await repository.getPatients();
      final lockedPatient = patients.firstWhere((p) => !p.hasConsent);

      expect(lockedPatient.hasConsent, false);
      expect(lockedPatient.dassHistory, isNull);
    });

    test('requestPatientConsent triggers consent request successfully', () async {
      final success = await repository.requestPatientConsent('patient-003');
      expect(success, true);
    });

    test('Patient with upcoming live session has isLiveNow == true and VC room ready', () async {
      final patients = await repository.getPatients();
      final livePatient = patients.firstWhere((p) => p.id == 'patient-001');

      expect(livePatient.upcomingSchedule, isNotNull);
      expect(livePatient.upcomingSchedule!.isLiveNow, true);
      expect(livePatient.upcomingSchedule!.timeRange, '10:00 - 10:30 WIB');
    });

    test('Patient with future session has isLiveNow == false and VC room locked', () async {
      final patients = await repository.getPatients();
      final futurePatient = patients.firstWhere((p) => p.id == 'patient-002');

      expect(futurePatient.upcomingSchedule, isNotNull);
      expect(futurePatient.upcomingSchedule!.isLiveNow, false);
      expect(futurePatient.upcomingSchedule!.roomOpensAt, '13:45 WIB');
    });

    test('Patient without active upcoming booking returns null upcomingSchedule', () async {
      final patients = await repository.getPatients();
      final noSchedulePatient = patients.firstWhere((p) => p.id == 'patient-003');

      expect(noSchedulePatient.upcomingSchedule, isNull);
    });

    test('saveClinicalNote creates and stores SOAP note', () async {
      final note = await repository.saveClinicalNote(
        patientId: 'patient-001',
        sessionId: 'session-test-01',
        subjective: 'Pasien merasa gelisah mengenai sidang skripsi.',
        objective: 'Kontak mata terbatas, nafas cepat.',
        assessment: 'Kecemasan performansi moderat.',
        plan: 'Teknik pernapasan 4-7-8 dan cognitive restructuring.',
        recommendedTasks: ['Pacer napas harian'],
      );

      expect(note.id.isNotEmpty, true);
      expect(note.subjective, contains('gelisah'));
      expect(note.assessment, contains('Kecemasan performansi'));
      expect(note.coinsAwarded, 150);
    });

    test('saveClinicalNote is idempotent for coinsAwarded on repeated saves of same session', () async {
      final firstSave = await repository.saveClinicalNote(
        patientId: 'patient-001',
        sessionId: 'session-idempotent-01',
        subjective: 'Catatan awal.',
        objective: 'Observasi awal.',
        assessment: 'Asesmen awal.',
        plan: 'Rencana awal.',
        recommendedTasks: const [],
      );
      expect(firstSave.coinsAwarded, 150);

      final secondSave = await repository.saveClinicalNote(
        patientId: 'patient-001',
        sessionId: 'session-idempotent-01',
        subjective: 'Catatan revisi.',
        objective: 'Observasi revisi.',
        assessment: 'Asesmen revisi.',
        plan: 'Rencana revisi.',
        recommendedTasks: const [],
      );
      expect(secondSave.coinsAwarded, 0);
    });

    test('saveClinicalNote rejects expired H+1 session (lastSessionDate > 1 day ago without upcomingSchedule)', () async {
      await expectLater(
        repository.saveClinicalNote(
          patientId: 'patient-003',
          sessionId: 'session-expired-01',
          subjective: 'Terlambat.',
          objective: 'Observasi.',
          assessment: 'Asesmen.',
          plan: 'Rencana.',
          recommendedTasks: const [],
        ),
        throwsException,
      );
    });

    test('synthesizeSoapNote generates structured SOAP fields from transcript via Eva AI', () async {
      final draft = await repository.synthesizeSoapNote(
        transcript: 'Pasien: Saya sering cemas dok. Psikolog: Mari latihan nafas bersama.',
        patientName: 'Rian Pratama',
      );

      expect(draft.containsKey('subjective'), true);
      expect(draft.containsKey('objective'), true);
      expect(draft.containsKey('assessment'), true);
      expect(draft.containsKey('plan'), true);
      expect(draft['subjective']!.isNotEmpty, true);
      expect(draft['plan']!.isNotEmpty, true);
    });
  });
}

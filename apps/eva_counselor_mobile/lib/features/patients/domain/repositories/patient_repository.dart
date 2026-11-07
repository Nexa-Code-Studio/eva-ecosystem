import '../entities/clinical_note_entity.dart';
import '../entities/patient_entity.dart';

abstract class IPatientRepository {
  Future<List<PatientEntity>> getPatients();
  Future<PatientEntity> getPatientDetail(String patientId);
  Future<bool> requestPatientConsent(String patientId);
  Future<List<ClinicalNoteEntity>> getClinicalNotes(String patientId);
  Future<ClinicalNoteEntity> saveClinicalNote({
    required String patientId,
    required String sessionId,
    required String subjective,
    required String objective,
    required String assessment,
    required String plan,
    required List<String> recommendedTasks,
  });
}

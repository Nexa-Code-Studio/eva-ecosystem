import '../models/clinical_note_dto.dart';
import '../models/patient_dto.dart';

abstract class PatientDataSource {
  Future<List<PatientResponseDto>> fetchPatients();
  Future<PatientResponseDto> fetchPatientDetail(String patientId);
  Future<bool> sendConsentRequest(String patientId);
  Future<List<ClinicalNoteResponseDto>> fetchClinicalNotes(String patientId);
  Future<ClinicalNoteResponseDto> createClinicalNote(CreateClinicalNoteRequestDto request);
}

import '../../domain/entities/clinical_note_entity.dart';
import '../../domain/entities/patient_entity.dart';
import '../../domain/repositories/patient_repository.dart';
import '../datasources/patient_datasource.dart';
import '../models/clinical_note_dto.dart';

class PatientRepositoryImpl implements IPatientRepository {
  final PatientDataSource _dataSource;

  PatientRepositoryImpl({required PatientDataSource dataSource})
      : _dataSource = dataSource;

  @override
  Future<List<PatientEntity>> getPatients() async {
    final list = await _dataSource.fetchPatients();
    return list.map((dto) => dto.toEntity()).toList();
  }

  @override
  Future<PatientEntity> getPatientDetail(String patientId) async {
    final dto = await _dataSource.fetchPatientDetail(patientId);
    return dto.toEntity();
  }

  @override
  Future<bool> requestPatientConsent(String patientId) async {
    return await _dataSource.sendConsentRequest(patientId);
  }

  @override
  Future<List<ClinicalNoteEntity>> getClinicalNotes(String patientId) async {
    final dtos = await _dataSource.fetchClinicalNotes(patientId);
    return dtos.map((dto) => dto.toEntity()).toList();
  }

  @override
  Future<ClinicalNoteEntity> saveClinicalNote({
    required String patientId,
    required String sessionId,
    required String subjective,
    required String objective,
    required String assessment,
    required String plan,
    required List<String> recommendedTasks,
  }) async {
    final request = CreateClinicalNoteRequestDto(
      patientId: patientId,
      sessionId: sessionId,
      subjective: subjective,
      objective: objective,
      assessment: assessment,
      plan: plan,
      recommendedTasks: recommendedTasks,
    );
    final dto = await _dataSource.createClinicalNote(request);
    return dto.toEntity();
  }
}

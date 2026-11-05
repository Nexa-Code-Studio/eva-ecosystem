import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/clinical_note_dto.dart';
import '../models/patient_dto.dart';
import 'patient_datasource.dart';

class RemotePatientDataSource implements PatientDataSource {
  final ApiClient _client;

  RemotePatientDataSource({ApiClient? client}) : _client = client ?? ApiClient();

  @override
  Future<List<PatientResponseDto>> fetchPatients() async {
    final response = await _client.get(ApiEndpoints.patients);
    return (response as List<dynamic>)
        .map((p) => PatientResponseDto.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<PatientResponseDto> fetchPatientDetail(String patientId) async {
    final response = await _client.get(ApiEndpoints.patientDetail(patientId));
    return PatientResponseDto.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<bool> sendConsentRequest(String patientId) async {
    final response = await _client.post(ApiEndpoints.requestConsent(patientId));
    return (response as Map<String, dynamic>?)?['success'] as bool? ?? true;
  }

  @override
  Future<List<ClinicalNoteResponseDto>> fetchClinicalNotes(String patientId) async {
    final response = await _client.get(ApiEndpoints.clinicalNotes(patientId));
    return (response as List<dynamic>)
        .map((n) => ClinicalNoteResponseDto.fromJson(n as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ClinicalNoteResponseDto> createClinicalNote(
      CreateClinicalNoteRequestDto request) async {
    final response = await _client.post(
      ApiEndpoints.clinicalNotes(request.patientId),
      body: request.toJson(),
    );
    return ClinicalNoteResponseDto.fromJson(response as Map<String, dynamic>);
  }
}

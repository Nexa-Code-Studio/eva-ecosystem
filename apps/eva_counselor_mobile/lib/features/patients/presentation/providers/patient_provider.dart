import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';
import '../../domain/entities/clinical_note_entity.dart';
import '../../domain/entities/patient_entity.dart';
import '../../domain/repositories/patient_repository.dart';
import '../../data/datasources/patient_datasource.dart';
import '../../data/datasources/mock_patient_datasource.dart';
import '../../data/datasources/remote_patient_datasource.dart';
import '../../data/repositories/patient_repository_impl.dart';

final patientDataSourceProvider = Provider<PatientDataSource>((ref) {
  if (AppConfig.useMockData) {
    return MockPatientDataSource();
  }
  return RemotePatientDataSource();
});

final patientRepositoryProvider = Provider<IPatientRepository>((ref) {
  final ds = ref.watch(patientDataSourceProvider);
  return PatientRepositoryImpl(dataSource: ds);
});

final patientsListProvider = FutureProvider<List<PatientEntity>>((ref) async {
  final repo = ref.watch(patientRepositoryProvider);
  return await repo.getPatients();
});

final patientDetailProvider =
    FutureProvider.family<PatientEntity, String>((ref, patientId) async {
  final repo = ref.watch(patientRepositoryProvider);
  return await repo.getPatientDetail(patientId);
});

final patientNotesProvider =
    FutureProvider.family<List<ClinicalNoteEntity>, String>((ref, patientId) async {
  final repo = ref.watch(patientRepositoryProvider);
  return await repo.getClinicalNotes(patientId);
});

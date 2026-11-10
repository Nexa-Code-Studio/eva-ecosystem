import '../../domain/repositories/care_repository.dart';
import '../../domain/entities/psychologist_entity.dart';
import '../../domain/entities/clinic_entity.dart';
import '../../domain/entities/community_status_entity.dart';
import '../../domain/entities/consultation_session_entity.dart';
import '../datasources/care_datasource.dart';

class CareRepositoryImpl implements CareRepository {
  final CareDataSource _dataSource;

  CareRepositoryImpl(this._dataSource);

  @override
  Future<List<PsychologistEntity>> getPsychologists({String? category, String? query}) {
    return _dataSource.getPsychologists(category: category, query: query);
  }

  @override
  Future<List<ClinicEntity>> getClinics({String? query}) {
    return _dataSource.getClinics(query: query);
  }

  @override
  Future<CommunityStatusEntity> getCommunityStatus() {
    return _dataSource.getCommunityStatus();
  }

  @override
  Future<CommunityStatusEntity> joinCommunityWithVipTrial() {
    return _dataSource.joinCommunityWithVipTrial();
  }

  @override
  Future<List<ConsultationSessionEntity>> getConsultationSessions() {
    return _dataSource.getConsultationSessions();
  }

  @override
  Future<ConsultationSessionEntity> bookConsultation({
    required String psychologistId,
    required DateTime preferredDateTime,
    required ConsultationType sessionType,
    String? complaints,
    bool shareAiChatHistory = true,
  }) {
    return _dataSource.bookConsultation(
      psychologistId: psychologistId,
      preferredDateTime: preferredDateTime,
      sessionType: sessionType,
      complaints: complaints,
      shareAiChatHistory: shareAiChatHistory,
    );
  }
}

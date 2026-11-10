import '../../domain/repositories/care_repository.dart';
import '../../domain/entities/psychologist_entity.dart';
import '../../domain/entities/clinic_entity.dart';
import '../../domain/entities/community_status_entity.dart';
import '../../domain/entities/consultation_session_entity.dart';
import '../../../../core/network/fallback_policy.dart';

class FallbackCareRepository implements CareRepository {
  final CareRepository _remote;
  final CareRepository _mock;

  FallbackCareRepository({
    required CareRepository remote,
    required CareRepository mock,
  })  : _remote = remote,
        _mock = mock;

  @override
  Future<List<PsychologistEntity>> getPsychologists({String? category, String? query}) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.getPsychologists(category: category, query: query),
      mockCall: () => _mock.getPsychologists(category: category, query: query),
      operationName: 'getPsychologists',
    );
  }

  @override
  Future<List<ClinicEntity>> getClinics({String? query}) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.getClinics(query: query),
      mockCall: () => _mock.getClinics(query: query),
      operationName: 'getClinics',
    );
  }

  @override
  Future<CommunityStatusEntity> getCommunityStatus() {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.getCommunityStatus(),
      mockCall: () => _mock.getCommunityStatus(),
      operationName: 'getCommunityStatus',
    );
  }

  @override
  Future<CommunityStatusEntity> joinCommunityWithVipTrial() {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.joinCommunityWithVipTrial(),
      mockCall: () => _mock.joinCommunityWithVipTrial(),
      operationName: 'joinCommunityWithVipTrial',
    );
  }

  @override
  Future<List<ConsultationSessionEntity>> getConsultationSessions() {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.getConsultationSessions(),
      mockCall: () => _mock.getConsultationSessions(),
      operationName: 'getConsultationSessions',
    );
  }

  @override
  Future<ConsultationSessionEntity> bookConsultation({
    required String psychologistId,
    required DateTime preferredDateTime,
    required ConsultationType sessionType,
    String? complaints,
    bool shareAiChatHistory = true,
  }) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.bookConsultation(
        psychologistId: psychologistId,
        preferredDateTime: preferredDateTime,
        sessionType: sessionType,
        complaints: complaints,
        shareAiChatHistory: shareAiChatHistory,
      ),
      mockCall: () => _mock.bookConsultation(
        psychologistId: psychologistId,
        preferredDateTime: preferredDateTime,
        sessionType: sessionType,
        complaints: complaints,
        shareAiChatHistory: shareAiChatHistory,
      ),
      operationName: 'bookConsultation',
    );
  }
}

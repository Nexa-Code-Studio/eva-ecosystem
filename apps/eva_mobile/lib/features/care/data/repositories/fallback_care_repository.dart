import '../../domain/repositories/care_repository.dart';
import '../../domain/entities/psychologist_entity.dart';
import '../../domain/entities/psychologist_rating_review.dart';
import '../../domain/entities/community_status_entity.dart';
import '../../domain/entities/consultation_session_entity.dart';
import '../../domain/entities/counselor_timeline_entity.dart';
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
  Future<List<PsychologistEntity>> getPsychologists({
    String? availability,
    int? levelTier,
    String? sortBy,
    String? query,
  }) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.getPsychologists(
        availability: availability,
        levelTier: levelTier,
        sortBy: sortBy,
        query: query,
      ),
      mockCall: () => _mock.getPsychologists(
        availability: availability,
        levelTier: levelTier,
        sortBy: sortBy,
        query: query,
      ),
      operationName: 'getPsychologists',
    );
  }

  @override
  Future<PsychologistEntity> getCounselorDetail(String counselorId) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.getCounselorDetail(counselorId),
      mockCall: () => _mock.getCounselorDetail(counselorId),
      operationName: 'getCounselorDetail',
    );
  }

  @override
  Future<List<PatientReviewItem>> getCounselorReviews(String counselorId) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.getCounselorReviews(counselorId),
      mockCall: () => _mock.getCounselorReviews(counselorId),
      operationName: 'getCounselorReviews',
    );
  }

  @override
  Future<PsychologistRatingReview> submitSessionReview({
    required String sessionId,
    required String psychologistId,
    required double rating,
    String? highlightLabel,
    String? reviewText,
    bool isAnonymous = true,
  }) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.submitSessionReview(
        sessionId: sessionId,
        psychologistId: psychologistId,
        rating: rating,
        highlightLabel: highlightLabel,
        reviewText: reviewText,
        isAnonymous: isAnonymous,
      ),
      mockCall: () => _mock.submitSessionReview(
        sessionId: sessionId,
        psychologistId: psychologistId,
        rating: rating,
        highlightLabel: highlightLabel,
        reviewText: reviewText,
        isAnonymous: isAnonymous,
      ),
      operationName: 'submitSessionReview',
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
  Future<CounselorTimelineEntity> getCounselorTimeline({
    required String counselorId,
    required DateTime date,
  }) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.getCounselorTimeline(counselorId: counselorId, date: date),
      mockCall: () => _mock.getCounselorTimeline(counselorId: counselorId, date: date),
      operationName: 'getCounselorTimeline',
    );
  }

  @override
  Future<ConsultationSessionEntity> bookConsultation({
    required String psychologistId,
    required DateTime preferredDateTime,
    required ConsultationType sessionType,
    int sessionCount = 1,
    int durationMinutes = 30,
    String? complaints,
    bool shareAiChatHistory = false,
  }) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.bookConsultation(
        psychologistId: psychologistId,
        preferredDateTime: preferredDateTime,
        sessionType: sessionType,
        sessionCount: sessionCount,
        durationMinutes: durationMinutes,
        complaints: complaints,
        shareAiChatHistory: shareAiChatHistory,
      ),
      mockCall: () => _mock.bookConsultation(
        psychologistId: psychologistId,
        preferredDateTime: preferredDateTime,
        sessionType: sessionType,
        sessionCount: sessionCount,
        durationMinutes: durationMinutes,
        complaints: complaints,
        shareAiChatHistory: shareAiChatHistory,
      ),
      operationName: 'bookConsultation',
    );
  }
}

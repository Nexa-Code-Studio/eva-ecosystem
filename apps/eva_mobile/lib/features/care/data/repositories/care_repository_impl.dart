import '../../domain/repositories/care_repository.dart';
import '../../domain/entities/psychologist_entity.dart';
import '../../domain/entities/psychologist_rating_review.dart';
import '../../domain/entities/community_status_entity.dart';
import '../../domain/entities/consultation_session_entity.dart';
import '../../domain/entities/counselor_timeline_entity.dart';
import '../datasources/care_datasource.dart';

class CareRepositoryImpl implements CareRepository {
  final CareDataSource _dataSource;

  CareRepositoryImpl(this._dataSource);

  @override
  Future<List<PsychologistEntity>> getPsychologists({
    String? availability,
    int? levelTier,
    String? sortBy,
    String? query,
  }) {
    return _dataSource.getPsychologists(
      availability: availability,
      levelTier: levelTier,
      sortBy: sortBy,
      query: query,
    );
  }

  @override
  Future<PsychologistEntity> getCounselorDetail(String counselorId) {
    return _dataSource.getCounselorDetail(counselorId);
  }

  @override
  Future<List<PatientReviewItem>> getCounselorReviews(String counselorId) {
    return _dataSource.getCounselorReviews(counselorId);
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
    return _dataSource.submitSessionReview(
      sessionId: sessionId,
      psychologistId: psychologistId,
      rating: rating,
      highlightLabel: highlightLabel,
      reviewText: reviewText,
      isAnonymous: isAnonymous,
    );
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
  Future<CounselorTimelineEntity> getCounselorTimeline({
    required String counselorId,
    required DateTime date,
  }) async {
    final dto = await _dataSource.getCounselorTimeline(counselorId: counselorId, date: date);
    return dto.toEntity();
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
    return _dataSource.bookConsultation(
      psychologistId: psychologistId,
      preferredDateTime: preferredDateTime,
      sessionType: sessionType,
      sessionCount: sessionCount,
      durationMinutes: durationMinutes,
      complaints: complaints,
      shareAiChatHistory: shareAiChatHistory,
    );
  }
}

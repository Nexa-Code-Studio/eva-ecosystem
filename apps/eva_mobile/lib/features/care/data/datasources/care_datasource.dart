import '../../domain/entities/consultation_session_entity.dart';
import '../../domain/entities/psychologist_entity.dart';
import '../../domain/entities/psychologist_rating_review.dart';
import '../models/psychologist_model.dart';
import '../models/community_status_model.dart';
import '../models/consultation_session_model.dart';
import '../models/counselor_timeline_dto.dart';

abstract class CareDataSource {
  Future<List<PsychologistModel>> getPsychologists({
    String? availability,
    int? levelTier,
    String? sortBy,
    String? query,
  });
  Future<PsychologistModel> getCounselorDetail(String counselorId);
  Future<List<PatientReviewItem>> getCounselorReviews(String counselorId);
  Future<PsychologistRatingReview> submitSessionReview({
    required String sessionId,
    required String psychologistId,
    required double rating,
    String? highlightLabel,
    String? reviewText,
    bool isAnonymous = true,
  });
  Future<CommunityStatusModel> getCommunityStatus();
  Future<CommunityStatusModel> joinCommunityWithVipTrial();
  Future<List<ConsultationSessionModel>> getConsultationSessions();
  Future<CounselorTimelineDto> getCounselorTimeline({
    required String counselorId,
    required DateTime date,
  });
  Future<ConsultationSessionModel> bookConsultation({
    required String psychologistId,
    required DateTime preferredDateTime,
    required ConsultationType sessionType,
    int sessionCount = 1,
    int durationMinutes = 30,
    String? complaints,
    bool shareAiChatHistory = false,
  });
}

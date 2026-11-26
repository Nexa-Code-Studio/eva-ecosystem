import '../../../../core/network/api_client.dart';
import '../../domain/entities/consultation_session_entity.dart';
import '../../domain/entities/psychologist_entity.dart';
import '../../domain/entities/psychologist_rating_review.dart';
import '../models/psychologist_model.dart';
import '../models/community_status_model.dart';
import '../models/consultation_session_model.dart';
import '../models/counselor_timeline_dto.dart';
import '../models/session_review_dto.dart';
import 'care_datasource.dart';

class RemoteCareDataSource implements CareDataSource {
  final ApiClient _apiClient;

  RemoteCareDataSource({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  @override
  Future<List<PsychologistModel>> getPsychologists({
    String? availability,
    int? levelTier,
    String? sortBy,
    String? query,
  }) async {
    final queryParams = <String, String>{
      'tz_offset_minutes': DateTime.now().timeZoneOffset.inMinutes.toString(),
    };
    if (availability != null && availability.isNotEmpty && availability != 'all') {
      queryParams['availability'] = availability;
    }
    if (levelTier != null) {
      queryParams['level_tier'] = levelTier.toString();
    }
    if (sortBy != null && sortBy.isNotEmpty && sortBy != 'default') {
      queryParams['sort_by'] = sortBy;
    }
    if (query != null && query.trim().isNotEmpty) {
      queryParams['search'] = query.trim();
    }

    final response = await _apiClient.get(
      '/counselors',
      queryParams: queryParams,
    );
    final list = response as List? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(PsychologistModel.fromJson)
        .toList();
  }

  @override
  Future<CommunityStatusModel> getCommunityStatus() async {
    final response = await _apiClient.get('/community/status');
    if (response is Map<String, dynamic>) {
      return CommunityStatusModel.fromJson(response);
    }
    return const CommunityStatusModel(isMember: false, isVipActive: false);
  }

  @override
  Future<CommunityStatusModel> joinCommunityWithVipTrial() async {
    final response = await _apiClient.post('/community/join');
    if (response is Map<String, dynamic>) {
      return CommunityStatusModel.fromJson(response);
    }
    return const CommunityStatusModel(isMember: true, isVipActive: true, vipRemainingDays: 30);
  }

  @override
  Future<List<ConsultationSessionModel>> getConsultationSessions() async {
    final response = await _apiClient.get('/care/sessions');
    final list = response as List? ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(ConsultationSessionModel.fromJson)
        .toList();
  }

  @override
  Future<CounselorTimelineDto> getCounselorTimeline({
    required String counselorId,
    required DateTime date,
  }) async {
    final dateString =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final response = await _apiClient.get(
      '/counselors/$counselorId/timeline',
      queryParams: {'date': dateString},
    );

    if (response is Map<String, dynamic>) {
      return CounselorTimelineDto.fromJson(response);
    }
    throw Exception('Failed to load counselor availability timeline');
  }

  @override
  Future<ConsultationSessionModel> bookConsultation({
    required String psychologistId,
    required DateTime preferredDateTime,
    required ConsultationType sessionType,
    int sessionCount = 1,
    int durationMinutes = 30,
    String? complaints,
    bool shareAiChatHistory = false,
  }) async {
    final startIso = preferredDateTime.toUtc().toIso8601String();
    final response = await _apiClient.post(
      '/counselors/$psychologistId/book',
      body: {
        'psychologist_id': psychologistId,
        'scheduled_start_time': startIso,
        'preferred_date_time': startIso,
        'session_type': ConsultationType.onlineVideo.name,
        'session_count': sessionCount,
        'duration_minutes': durationMinutes > 0 ? durationMinutes : sessionCount * 30,
        'complaints': complaints,
        'share_ai_chat_history': shareAiChatHistory,
      },
    );

    if (response is Map<String, dynamic>) {
      return ConsultationSessionModel.fromJson(response);
    }
    throw Exception('Failed to book consultation');
  }

  @override
  Future<PsychologistModel> getCounselorDetail(String counselorId) async {
    final response = await _apiClient.get('/counselors/$counselorId');
    if (response is Map<String, dynamic>) {
      return PsychologistModel.fromJson(response);
    }
    throw Exception('Failed to load counselor profile detail');
  }

  @override
  Future<List<PatientReviewItem>> getCounselorReviews(String counselorId) async {
    final response = await _apiClient.get('/counselors/$counselorId/reviews');
    final rawList = response is List
        ? response
        : (response is Map<String, dynamic> && response['items'] is List
            ? response['items'] as List<dynamic>
            : const <dynamic>[]);
    return rawList
        .whereType<Map<String, dynamic>>()
        .map((e) => SessionReviewDto.fromJson(e, fallbackCounselorId: counselorId)
            .toPatientReviewItem())
        .toList();
  }

  @override
  Future<PsychologistRatingReview> submitSessionReview({
    required String sessionId,
    required String psychologistId,
    required double rating,
    String? highlightLabel,
    String? reviewText,
    bool isAnonymous = true,
  }) async {
    final cleanHighlight = highlightLabel?.trim();
    final cleanReview = reviewText?.trim();
    final response = await _apiClient.post(
      '/sessions/$sessionId/reviews',
      body: {
        'rating': rating,
        if (cleanHighlight != null && cleanHighlight.isNotEmpty)
          'highlight_label': cleanHighlight,
        if (cleanReview != null && cleanReview.isNotEmpty)
          'review_text': cleanReview,
        'is_anonymous': isAnonymous,
      },
    );
    if (response is Map<String, dynamic>) {
      return SessionReviewDto.fromJson(
        response,
        fallbackCounselorId: psychologistId,
      ).toRatingReview(overrideCounselorId: psychologistId);
    }
    throw Exception('Failed to submit session review');
  }
}

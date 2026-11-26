import '../../../../core/network/api_client.dart';
import '../../domain/entities/consultation_session_entity.dart';
import '../models/psychologist_model.dart';
import '../models/community_status_model.dart';
import '../models/consultation_session_model.dart';
import '../models/counselor_timeline_dto.dart';
import 'care_datasource.dart';

class RemoteCareDataSource implements CareDataSource {
  final ApiClient _apiClient;

  RemoteCareDataSource({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  @override
  Future<List<PsychologistModel>> getPsychologists({String? category, String? query}) async {
    final response = await _apiClient.get('/counselors');
    final list = response as List? ?? [];
    var items = list
        .whereType<Map<String, dynamic>>()
        .map(PsychologistModel.fromJson)
        .toList();

    if (category != null && category.isNotEmpty && category != 'all') {
      final cat = category.toLowerCase();
      if (cat == 'volunteer' || cat == 'relawan') {
        items = items.where((p) => p.isVolunteer).toList();
      } else if (cat == 'psychologist' || cat == 'psikolog') {
        items = items.where((p) => !p.isVolunteer).toList();
      } else if (cat == 'psychiatrist') {
        items = items.where((p) => p.isPsychiatrist).toList();
      }
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      items = items.where((p) {
        return p.name.toLowerCase().contains(q) ||
            p.title.toLowerCase().contains(q) ||
            p.specialties.any((s) => s.toLowerCase().contains(q));
      }).toList();
    }

    return items;
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
}

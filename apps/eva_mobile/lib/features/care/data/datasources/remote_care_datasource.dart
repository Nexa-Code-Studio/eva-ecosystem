import '../../../../core/network/api_client.dart';
import '../../domain/entities/consultation_session_entity.dart';
import '../models/psychologist_model.dart';
import '../models/clinic_model.dart';
import '../models/community_status_model.dart';
import '../models/consultation_session_model.dart';
import 'care_datasource.dart';

class RemoteCareDataSource implements CareDataSource {
  final ApiClient _apiClient;

  RemoteCareDataSource({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  @override
  Future<List<PsychologistModel>> getPsychologists({String? category, String? query}) async {
    final queryParams = <String, String>{};
    if (category != null && category.isNotEmpty) queryParams['category'] = category;
    if (query != null && query.isNotEmpty) queryParams['q'] = query;

    final response = await _apiClient.get(
      '/care/psychologists',
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );

    final list = response as List? ?? [];
    return list.map((e) => PsychologistModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<ClinicModel>> getClinics({String? query}) async {
    final queryParams = <String, String>{};
    if (query != null && query.isNotEmpty) queryParams['q'] = query;

    final response = await _apiClient.get(
      '/care/clinics',
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );

    final list = response as List? ?? [];
    return list.map((e) => ClinicModel.fromJson(e as Map<String, dynamic>)).toList();
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
    return list.map((e) => ConsultationSessionModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<ConsultationSessionModel> bookConsultation({
    required String psychologistId,
    required DateTime preferredDateTime,
    required ConsultationType sessionType,
    String? complaints,
    bool shareAiChatHistory = true,
  }) async {
    final response = await _apiClient.post(
      '/care/book',
      body: {
        'psychologist_id': psychologistId,
        'preferred_datetime': preferredDateTime.toIso8601String(),
        'session_type': sessionType.name,
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

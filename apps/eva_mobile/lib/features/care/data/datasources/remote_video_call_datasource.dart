import '../../../../core/network/api_client.dart';
import '../models/consultation_session_model.dart';
import '../models/extension_availability_dto.dart';
import '../models/video_call_session_dto.dart';
import 'video_call_datasource.dart';

class RemoteVideoCallDataSource implements VideoCallDataSource {
  final ApiClient _apiClient;

  RemoteVideoCallDataSource({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  @override
  Future<VideoCallSessionDto> joinRoom(String sessionId) async {
    final response =
        await _apiClient.post('/care/sessions/$sessionId/video-token');
    if (response is Map<String, dynamic>) {
      return VideoCallSessionDto.fromJson(response);
    }
    throw ApiException('Invalid video token response format');
  }

  @override
  Future<void> leaveRoom(String sessionId) async {
    await _apiClient.post(
      '/care/sessions/$sessionId/status',
      body: {'status': 'completed'},
    );
  }

  @override
  Future<ExtensionAvailabilityDto> checkExtensionAvailability(
      String sessionId) async {
    final response = await _apiClient
        .get('/sessions/$sessionId/extension-availability');
    if (response is Map<String, dynamic>) {
      return ExtensionAvailabilityDto.fromJson(response);
    }
    throw ApiException('Invalid extension availability response format');
  }

  @override
  Future<ConsultationSessionModel> extendSession(String sessionId) async {
    final response = await _apiClient.post('/sessions/$sessionId/extend');
    if (response is Map<String, dynamic>) {
      return ConsultationSessionModel.fromJson(response);
    }
    throw ApiException('Invalid session extension response format');
  }
}

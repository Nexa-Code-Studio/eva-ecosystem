import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/video_session_dto.dart';
import 'video_call_datasource.dart';

class RemoteVideoCallDataSource implements VideoCallDataSource {
  final ApiClient _client;

  RemoteVideoCallDataSource({ApiClient? client})
      : _client = client ?? ApiClient();

  @override
  Future<VideoSessionResponseDto> fetchSessionDetails(String sessionId) async {
    final response = await _client.get(ApiEndpoints.sessionDetail(sessionId));
    return VideoSessionResponseDto.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<bool> initiateCall(String sessionId) async {
    final response = await _client.post(ApiEndpoints.startSession(sessionId));
    return (response as Map<String, dynamic>?)?['success'] as bool? ?? true;
  }

  @override
  Future<bool> terminateCall(
      String sessionId, int durationSeconds, List<String> notes) async {
    final response = await _client.post(
      ApiEndpoints.endSession(sessionId),
      body: {
        'duration_seconds': durationSeconds,
        'quick_notes': notes,
      },
    );
    return (response as Map<String, dynamic>?)?['success'] as bool? ?? true;
  }
}

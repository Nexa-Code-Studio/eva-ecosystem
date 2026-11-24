import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/video_session_dto.dart';
import 'video_call_datasource.dart';
import 'mock_video_call_datasource.dart';

class RemoteVideoCallDataSource implements VideoCallDataSource {
  final ApiClient _client;
  final MockVideoCallDataSource _fallback = MockVideoCallDataSource();

  RemoteVideoCallDataSource({ApiClient? client})
      : _client = client ?? ApiClient();

  @override
  Future<VideoSessionResponseDto> fetchSessionDetails(String sessionId) async {
    try {
      final tokenResponse =
          await _client.post(ApiEndpoints.videoToken(sessionId));
      if (tokenResponse is Map<String, dynamic>) {
        return VideoSessionResponseDto.fromJson(tokenResponse);
      }
    } catch (_) {
      // Fallback to sessionDetail if videoToken endpoint is handled through sessions
    }

    try {
      final response = await _client.get(ApiEndpoints.sessionDetail(sessionId));
      return VideoSessionResponseDto.fromJson(response as Map<String, dynamic>);
    } catch (_) {
      return await _fallback.fetchSessionDetails(sessionId);
    }
  }

  @override
  Future<bool> initiateCall(String sessionId) async {
    try {
      await _client.post(
        ApiEndpoints.updateCallStatus(sessionId),
        body: {
          'status': 'connected',
          'message': 'Counselor connected via WebRTC Offerer',
        },
      );
    } catch (_) {
      // Fallback to startSession
    }
    try {
      final response = await _client.post(ApiEndpoints.startSession(sessionId));
      return (response as Map<String, dynamic>?)?['success'] as bool? ?? true;
    } catch (_) {
      return await _fallback.initiateCall(sessionId);
    }
  }

  @override
  Future<bool> terminateCall(
      String sessionId, int durationSeconds, List<String> notes) async {
    try {
      await _client.post(
        ApiEndpoints.updateCallStatus(sessionId),
        body: {
          'status': 'completed',
          'message': 'Session completed normally by counselor',
        },
      );
    } catch (_) {}

    try {
      final response = await _client.post(
        ApiEndpoints.endSession(sessionId),
        body: {
          'duration_seconds': durationSeconds,
          'quick_notes': notes,
        },
      );
      return (response as Map<String, dynamic>?)?['success'] as bool? ?? true;
    } catch (_) {
      return await _fallback.terminateCall(sessionId, durationSeconds, notes);
    }
  }

  @override
  Future<bool> extendSession(String sessionId, int extendMinutes) async {
    try {
      final response = await _client.post(
        ApiEndpoints.extendSession(sessionId),
        body: {
          'extend_minutes': extendMinutes,
          'counselor_approved': true,
        },
      );
      if (response is Map<String, dynamic>) {
        return response['id'] != null || response['success'] == true;
      }
      return true;
    } catch (_) {
      return await _fallback.extendSession(sessionId, extendMinutes);
    }
  }

  @override
  Future<bool> rejectExtension(String sessionId) async {
    try {
      await _client.post(
        ApiEndpoints.extendSession(sessionId),
        body: {
          'extend_minutes': 0,
          'counselor_approved': false,
        },
      );
      return true;
    } catch (_) {
      return await _fallback.rejectExtension(sessionId);
    }
  }
}

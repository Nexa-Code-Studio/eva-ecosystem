import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/video_session_dto.dart';
import 'video_call_datasource.dart';

class RemoteVideoCallDataSource implements VideoCallDataSource {
  final ApiClient _client;

  RemoteVideoCallDataSource({ApiClient? client})
      : _client = client ?? ApiClient();

  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  bool _isValidUuid(String str) => _uuidRegex.hasMatch(str);

  @override
  Future<VideoSessionResponseDto> fetchSessionDetails(String sessionId) async {
    if (!_isValidUuid(sessionId)) {
      return VideoSessionResponseDto(
        sessionId: sessionId,
        patientId: 'patient-001',
        patientName: 'Pasien Konseling',
        scheduledTime: DateTime.now().toIso8601String(),
        status: 'ready',
        signalingToken: 'simulated-token-$sessionId',
        channelName: 'counseling-room-$sessionId',
        wsUrl: '',
        iceServerConfigs: const [
          IceServerDto(
            urls: ['stun:stun.l.google.com:19302'],
          ),
        ],
      );
    }

    try {
      final tokenResponse =
          await _client.post(ApiEndpoints.videoToken(sessionId));
      if (tokenResponse is Map<String, dynamic>) {
        return VideoSessionResponseDto.fromJson(tokenResponse);
      }
    } catch (_) {
      // Fallback to sessionDetail if videoToken endpoint is handled through sessions
    }

    final response = await _client.get(ApiEndpoints.sessionDetail(sessionId));
    return VideoSessionResponseDto.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<bool> initiateCall(String sessionId) async {
    if (!_isValidUuid(sessionId)) return true;
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
    final response = await _client.post(ApiEndpoints.startSession(sessionId));
    return (response as Map<String, dynamic>?)?['success'] as bool? ?? true;
  }

  @override
  Future<bool> terminateCall(
      String sessionId, int durationSeconds, List<String> notes) async {
    if (!_isValidUuid(sessionId)) return true;
    try {
      await _client.post(
        ApiEndpoints.updateCallStatus(sessionId),
        body: {
          'status': 'completed',
          'message': 'Session completed normally by counselor',
        },
      );
    } catch (_) {}

    final response = await _client.post(
      ApiEndpoints.endSession(sessionId),
      body: {
        'duration_seconds': durationSeconds,
        'quick_notes': notes,
      },
    );
    return (response as Map<String, dynamic>?)?['success'] as bool? ?? true;
  }

  @override
  Future<bool> extendSession(String sessionId, int extendMinutes) async {
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
  }

  @override
  Future<bool> rejectExtension(String sessionId) async {
    await _client.post(
      ApiEndpoints.extendSession(sessionId),
      body: {
        'extend_minutes': 0,
        'counselor_approved': false,
      },
    );
    return true;
  }
}

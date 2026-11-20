import '../models/video_session_dto.dart';
import 'video_call_datasource.dart';

class MockVideoCallDataSource implements VideoCallDataSource {
  @override
  Future<VideoSessionResponseDto> fetchSessionDetails(String sessionId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return VideoSessionResponseDto(
      sessionId: sessionId,
      patientId: 'patient-001',
      patientName: 'Rian Pratama',
      scheduledTime: DateTime.now().toIso8601String(),
      status: 'ready',
      signalingToken: 'mock-webrtc-token-12345',
      channelName: 'counseling-room-$sessionId',
      wsUrl: 'ws://127.0.0.1:8888/api/v1/care/ws/$sessionId?token=mock-webrtc-token-12345',
      iceServerConfigs: const [
        IceServerDto(
          urls: [
            'stun:stun.l.google.com:19302',
            'stun:stun.cloudflare.com:3478',
            'turn:turn.cloudflare.com:3478?transport=udp',
          ],
          username: 'mock-turn-user',
          credential: 'mock-turn-password',
        ),
      ],
    );
  }

  @override
  Future<bool> initiateCall(String sessionId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return true;
  }

  @override
  Future<bool> terminateCall(
      String sessionId, int durationSeconds, List<String> notes) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return true;
  }

  @override
  Future<bool> extendSession(String sessionId, int extendMinutes) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return true;
  }

  @override
  Future<bool> rejectExtension(String sessionId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return true;
  }
}

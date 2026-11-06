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
    );
  }

  @override
  Future<bool> initiateCall(String sessionId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return true;
  }

  @override
  Future<bool> terminateCall(
      String sessionId, int durationSeconds, List<String> notes) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return true;
  }
}

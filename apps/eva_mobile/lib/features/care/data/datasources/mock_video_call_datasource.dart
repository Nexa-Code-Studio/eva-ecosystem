import 'dart:async';
import '../models/video_call_session_dto.dart';
import 'video_call_datasource.dart';

class MockVideoCallDataSource implements VideoCallDataSource {
  @override
  Future<VideoCallSessionDto> joinRoom(String sessionId) async {
    return VideoCallSessionDto(
      sessionId: sessionId,
      roomId: 'eva-room-$sessionId',
      token: 'mock-webrtc-token-$sessionId-${DateTime.now().millisecondsSinceEpoch}',
      participantId: 'user-patient-eva',
      status: 'active',
      iceServers: const [
        'stun:stun.l.google.com:19302',
        'stun:stun1.l.google.com:19302',
      ],
    );
  }

  @override
  Future<void> leaveRoom(String sessionId) async {}

  @override
  Future<void> updateMediaState({
    required String sessionId,
    required bool isMicMuted,
    required bool isCameraOff,
  }) async {}
}

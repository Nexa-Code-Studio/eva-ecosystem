import 'dart:async';
import 'package:webrtc_client/webrtc_client.dart';
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
      iceServerConfigs: const [
        IceServerConfig(urls: [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
        ]),
      ],
      wsUrl: 'ws://localhost:8888/api/v1/care/ws/$sessionId?token=mock-token',
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

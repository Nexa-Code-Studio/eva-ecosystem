import '../models/video_call_session_dto.dart';

abstract class VideoCallDataSource {
  Future<VideoCallSessionDto> joinRoom(String sessionId);
  Future<void> leaveRoom(String sessionId);
  Future<void> updateMediaState({
    required String sessionId,
    required bool isMicMuted,
    required bool isCameraOff,
  });
}

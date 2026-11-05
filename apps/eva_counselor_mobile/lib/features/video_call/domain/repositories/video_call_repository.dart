import '../entities/video_call_state_entity.dart';

abstract class IVideoCallRepository {
  Future<VideoCallSessionEntity> getSessionDetails(String sessionId);
  Future<bool> startSession(String sessionId);
  Future<bool> endSession(String sessionId, Duration duration, List<String> notes);
}

import '../entities/video_call_state_entity.dart';
import '../entities/consultation_session_entity.dart';

abstract class VideoCallRepository {
  Future<VideoCallStateEntity> joinCall(ConsultationSessionEntity session);
  Future<void> endCall(String sessionId);
  Future<void> syncMediaState({
    required String sessionId,
    required bool isMicMuted,
    required bool isCameraOff,
  });
}

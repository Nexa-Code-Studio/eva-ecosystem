import '../entities/consultation_session_entity.dart';
import '../entities/extension_availability_entity.dart';
import '../entities/video_call_state_entity.dart';

abstract class VideoCallRepository {
  Future<VideoCallStateEntity> joinCall(ConsultationSessionEntity session);
  Future<void> endCall(String sessionId);
  Future<ExtensionAvailabilityEntity> checkExtensionAvailability(String sessionId);
  Future<ConsultationSessionEntity> extendSession(String sessionId);
}

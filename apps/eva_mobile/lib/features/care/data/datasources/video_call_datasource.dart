import '../models/consultation_session_model.dart';
import '../models/extension_availability_dto.dart';
import '../models/video_call_session_dto.dart';

abstract class VideoCallDataSource {
  Future<VideoCallSessionDto> joinRoom(String sessionId);
  Future<void> leaveRoom(String sessionId);
  Future<ExtensionAvailabilityDto> checkExtensionAvailability(String sessionId);
  Future<ConsultationSessionModel> extendSession(String sessionId);
}

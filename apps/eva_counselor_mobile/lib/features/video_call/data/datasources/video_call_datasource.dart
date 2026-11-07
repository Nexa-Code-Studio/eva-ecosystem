import '../models/video_session_dto.dart';

abstract class VideoCallDataSource {
  Future<VideoSessionResponseDto> fetchSessionDetails(String sessionId);
  Future<bool> initiateCall(String sessionId);
  Future<bool> terminateCall(String sessionId, int durationSeconds, List<String> notes);
}

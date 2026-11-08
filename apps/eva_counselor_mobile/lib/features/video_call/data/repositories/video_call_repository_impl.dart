import '../../domain/entities/video_call_state_entity.dart';
import '../../domain/repositories/video_call_repository.dart';
import '../datasources/video_call_datasource.dart';

class VideoCallRepositoryImpl implements IVideoCallRepository {
  final VideoCallDataSource _dataSource;

  VideoCallRepositoryImpl({required VideoCallDataSource dataSource})
      : _dataSource = dataSource;

  @override
  Future<VideoCallSessionEntity> getSessionDetails(String sessionId) async {
    final dto = await _dataSource.fetchSessionDetails(sessionId);
    return dto.toEntity();
  }

  @override
  Future<bool> startSession(String sessionId) async {
    return await _dataSource.initiateCall(sessionId);
  }

  @override
  Future<bool> endSession(
      String sessionId, Duration duration, List<String> notes) async {
    return await _dataSource.terminateCall(sessionId, duration.inSeconds, notes);
  }
}

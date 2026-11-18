import '../../domain/entities/consultation_session_entity.dart';
import '../../domain/entities/video_call_state_entity.dart';
import '../../domain/repositories/video_call_repository.dart';
import '../datasources/video_call_datasource.dart';

class VideoCallRepositoryImpl implements VideoCallRepository {
  final VideoCallDataSource dataSource;

  VideoCallRepositoryImpl({required this.dataSource});

  @override
  Future<VideoCallStateEntity> joinCall(ConsultationSessionEntity session) async {
    final dto = await dataSource.joinRoom(session.id);
    return VideoCallStateEntity(
      session: session,
      connectionState: VideoCallConnectionState.connected,
      isMicMuted: false,
      isCameraOff: false,
      isFrontCamera: true,
      isSpeakerOn: true,
      isRemoteSpeaking: true,
      callDurationSeconds: 0,
      roomId: dto.roomId,
      token: dto.token,
    );
  }

  @override
  Future<void> endCall(String sessionId) async {
    await dataSource.leaveRoom(sessionId);
  }

  @override
  Future<void> syncMediaState({
    required String sessionId,
    required bool isMicMuted,
    required bool isCameraOff,
  }) async {
    await dataSource.updateMediaState(
      sessionId: sessionId,
      isMicMuted: isMicMuted,
      isCameraOff: isCameraOff,
    );
  }
}

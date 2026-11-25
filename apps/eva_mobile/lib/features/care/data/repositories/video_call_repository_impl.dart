import '../../domain/entities/consultation_session_entity.dart';
import '../../domain/entities/extension_availability_entity.dart';
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
      connectionState: VideoCallConnectionState.connecting,
      isMicMuted: false,
      isCameraOff: false,
      isFrontCamera: true,
      isSpeakerOn: true,
      isRemoteSpeaking: false,
      callDurationSeconds: 0,
      maxDurationSeconds: session.durationMinutes * 60,
      isExtended: session.isExtended,
      roomId: dto.roomId,
      token: dto.token,
      iceServers: dto.iceServerConfigs,
      wsUrl: dto.wsUrl,
      isWaitingForCounselor: true,
    );
  }

  @override
  Future<void> endCall(String sessionId) async {
    await dataSource.leaveRoom(sessionId);
  }

  @override
  Future<ExtensionAvailabilityEntity> checkExtensionAvailability(
      String sessionId) async {
    final dto = await dataSource.checkExtensionAvailability(sessionId);
    return dto.toEntity();
  }

  @override
  Future<ConsultationSessionEntity> extendSession(String sessionId) {
    return dataSource.extendSession(sessionId);
  }
}

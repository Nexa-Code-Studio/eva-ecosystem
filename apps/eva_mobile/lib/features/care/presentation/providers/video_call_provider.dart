import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webrtc_client/webrtc_client.dart';
import '../../../../config/app_config.dart';
import '../../domain/entities/consultation_session_entity.dart';
import '../../domain/entities/video_call_state_entity.dart';
import '../../domain/repositories/video_call_repository.dart';
import '../../data/datasources/mock_video_call_datasource.dart';
import '../../data/datasources/remote_video_call_datasource.dart';
import '../../data/repositories/fallback_video_call_repository.dart';
import '../../data/repositories/video_call_repository_impl.dart';
import '../controllers/video_call_controller.dart';

final videoCallRepositoryProvider = Provider<VideoCallRepository>((ref) {
  final mockRepo = VideoCallRepositoryImpl(dataSource: MockVideoCallDataSource());
  final remoteRepo =
      VideoCallRepositoryImpl(dataSource: RemoteVideoCallDataSource());

  if (AppConfig.useMockData) {
    return mockRepo;
  } else if (AppConfig.useHybridFallback) {
    return FallbackVideoCallRepository(remote: remoteRepo, mock: mockRepo);
  }
  return remoteRepo;
});

final videoCallControllerProvider = StateNotifierProvider.autoDispose
    .family<VideoCallController, VideoCallStateEntity,
        ConsultationSessionEntity>((ref, session) {
  if (session.isPreview) {
    return VideoCallController(
      repository: VideoCallRepositoryImpl(dataSource: MockVideoCallDataSource()),
      initialSession: session,
      peerManager: MockWebRtcPeerManager(),
      signalingService: MockSignalingService(),
      isPreviewMode: true,
    );
  }
  final repository = ref.watch(videoCallRepositoryProvider);
  return VideoCallController(
    repository: repository,
    initialSession: session,
  );
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webrtc_client/webrtc_client.dart';
import '../../../../core/config/app_config.dart';
import '../../domain/entities/video_call_state_entity.dart';
import '../../domain/repositories/video_call_repository.dart';
import '../../data/datasources/video_call_datasource.dart';
import '../../data/datasources/mock_video_call_datasource.dart';
import '../../data/datasources/remote_video_call_datasource.dart';
import '../../data/repositories/video_call_repository_impl.dart';
import '../controllers/video_call_controller.dart';

final videoCallDataSourceProvider = Provider<VideoCallDataSource>((ref) {
  if (AppConfig.useMockData) {
    return MockVideoCallDataSource();
  }
  return RemoteVideoCallDataSource();
});

final videoCallRepositoryProvider = Provider<IVideoCallRepository>((ref) {
  final ds = ref.watch(videoCallDataSourceProvider);
  return VideoCallRepositoryImpl(dataSource: ds);
});

final webrtcPeerManagerProvider = Provider.autoDispose<IWebRtcPeerManager>((ref) {
  if (AppConfig.useMockData) {
    return MockWebRtcPeerManager();
  }
  return WebRtcPeerManager();
});

final webrtcSignalingServiceProvider =
    Provider.autoDispose<IWebRtcSignalingService>((ref) {
  if (AppConfig.useMockData) {
    return MockSignalingService();
  }
  return WebRtcSignalingService();
});

final videoCallControllerProvider = StateNotifierProvider.autoDispose.family<
    VideoCallController, VideoCallSessionEntity, String>(
  (ref, sessionId) {
    final repo = ref.watch(videoCallRepositoryProvider);
    final peer = ref.watch(webrtcPeerManagerProvider);
    final signaling = ref.watch(webrtcSignalingServiceProvider);
    final initial = VideoCallSessionEntity(
      sessionId: sessionId,
      patientId: 'patient-001',
      patientName: 'Pasien',
      scheduledTime: DateTime.now(),
      isWaitingForPatient: true,
      status: VideoCallStatus.waiting,
    );
    return VideoCallController(
      repo,
      initial,
      peerManager: peer,
      signalingService: signaling,
    );
  },
);

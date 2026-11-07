import 'package:flutter_riverpod/flutter_riverpod.dart';
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

final videoCallControllerProvider = StateNotifierProvider.family<
    VideoCallController, VideoCallSessionEntity, VideoCallSessionEntity>(
  (ref, initialSession) {
    final repo = ref.watch(videoCallRepositoryProvider);
    return VideoCallController(repo, initialSession);
  },
);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eva_mobile/config/app_config.dart';
import '../../domain/repositories/voice_call_repository.dart';
import '../../domain/entities/voice_session_entity.dart';
import '../../data/datasources/mock_voice_call_datasource.dart';
import '../../data/datasources/remote_voice_call_datasource.dart';
import '../../data/repositories/voice_call_repository_impl.dart';
import '../../data/repositories/fallback_voice_call_repository.dart';

final voiceCallRepositoryProvider = Provider<VoiceCallRepository>((ref) {
  final mockRepo = VoiceCallRepositoryImpl(MockVoiceCallDataSource());
  final remoteRepo = VoiceCallRepositoryImpl(RemoteVoiceCallDataSource());

  if (AppConfig.useMockData) {
    return mockRepo;
  } else if (AppConfig.useHybridFallback) {
    return FallbackVoiceCallRepository(remote: remoteRepo, mock: mockRepo);
  } else {
    return remoteRepo;
  }
});

final activeVoiceSessionProvider = StateProvider<VoiceSessionEntity?>((ref) => null);

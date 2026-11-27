import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../dass/presentation/providers/dass_provider.dart';
import '../../../diary/presentation/providers/diary_provider.dart';
import '../../../memory/presentation/providers/memory_provider.dart';
import '../../../monitoring/presentation/providers/monitoring_provider.dart';
import '../../data/datasources/voice_call_ws_client.dart';
import '../../data/services/ai_audio_playback_service.dart';
import '../../data/services/single_audio_capture_service.dart';
import '../../data/services/stateless_synthesis_service.dart';
import '../controllers/ai_call_controller.dart';
import '../controllers/ai_call_state.dart';

final singleAudioCaptureServiceProvider =
    Provider.autoDispose<SingleAudioCaptureService>((ref) {
  final service = SingleAudioCaptureService();
  ref.onDispose(() => service.dispose());
  return service;
});

final aiAudioPlaybackServiceProvider =
    Provider.autoDispose<AiAudioPlaybackService>((ref) {
  final service = AiAudioPlaybackService();
  ref.onDispose(() => service.dispose());
  return service;
});

final voiceCallWsClientProvider = Provider<VoiceCallWsClient>((ref) {
  final client = VoiceCallWsClient();
  ref.onDispose(() => client.dispose());
  return client;
});

final statelessSynthesisServiceProvider = Provider<StatelessSynthesisService>((ref) {
  final localDb = ref.watch(encryptedLocalDatabaseProvider);
  final diarySource = ref.watch(localDiaryDataSourceProvider);
  final dassSource = ref.watch(localDassDataSourceProvider);
  return StatelessSynthesisService(
    localDb: localDb,
    diaryDataSource: diarySource,
    dassDataSource: dassSource,
  );
});

final aiCallControllerProvider =
    StateNotifierProvider<AiCallController, AiCallViewState>((ref) {
  final audioCapture = ref.watch(singleAudioCaptureServiceProvider);
  final playback = ref.watch(aiAudioPlaybackServiceProvider);
  final ws = ref.watch(voiceCallWsClientProvider);
  final memoryRepo = ref.watch(memoryRepositoryProvider);
  final diarySource = ref.watch(localDiaryDataSourceProvider);
  final synthesisService = ref.watch(statelessSynthesisServiceProvider);

  return AiCallController(
    audioCaptureService: audioCapture,
    audioPlaybackService: playback,
    wsClient: ws,
    memoryRepository: memoryRepo,
    diaryDataSource: diarySource,
    synthesisService: synthesisService,
    onArtifactsCommitted: () {
      ref.invalidate(diaryEntriesProvider);
      ref.invalidate(conversationsProvider);
      ref.invalidate(monitoringDataProvider);
      ref.invalidate(dassAssessmentNotifierProvider);
    },
  );
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../dass/presentation/providers/dass_provider.dart';
import '../../../diary/presentation/providers/diary_provider.dart';
import '../../../memory/presentation/providers/memory_provider.dart';
import '../../../monitoring/presentation/providers/monitoring_provider.dart';
import '../../config/audio_pipeline_config.dart';
import '../../data/datasources/voice_call_ws_client.dart';
import '../../data/services/ai_audio_playback_service.dart';
import '../../data/services/single_audio_capture_service.dart';
import '../../data/services/speech_recognition_service.dart';
import '../../data/services/stateless_synthesis_service.dart';
import '../controllers/ai_call_controller.dart';
import '../controllers/ai_call_state.dart';

final audioPipelineConfigResolverProvider =
    Provider<AudioPipelineConfigResolver>((ref) {
  return const AudioPipelineConfigResolver();
});

final speechRecognitionServiceProvider =
    Provider.autoDispose<SpeechRecognitionService>((ref) {
  final service = SpeechRecognitionService();
  ref.onDispose(() => service.dispose());
  return service;
});

final singleAudioCaptureServiceProvider =
    Provider.autoDispose<SingleAudioCaptureService>((ref) {
  final speech = ref.watch(speechRecognitionServiceProvider);
  final configResolver = ref.watch(audioPipelineConfigResolverProvider);
  final service = SingleAudioCaptureService(
    fallbackSpeechService: speech,
    configResolver: configResolver,
  );
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
  final speech = ref.watch(speechRecognitionServiceProvider);
  final singleAudio = ref.watch(singleAudioCaptureServiceProvider);
  final playback = ref.watch(aiAudioPlaybackServiceProvider);
  final ws = ref.watch(voiceCallWsClientProvider);
  final memoryRepo = ref.watch(memoryRepositoryProvider);
  final diarySource = ref.watch(localDiaryDataSourceProvider);
  final synthesisService = ref.watch(statelessSynthesisServiceProvider);

  return AiCallController(
    speechService: speech,
    singleAudioService: singleAudio,
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

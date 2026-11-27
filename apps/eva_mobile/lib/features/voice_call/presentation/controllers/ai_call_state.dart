import '../../domain/entities/audio_pipeline_mode.dart';
import '../../domain/entities/call_state.dart';

class AiCallViewState {
  final CallState callState;
  final ConversationMode conversationMode;
  final String callId;
  final int userTurnId;
  final int activeSttSessionId;
  final int assistantTurnId;
  final String currentTranscript;
  final String latestPartial;
  final String aiTranscript;
  final String accumulatedTranscript;
  final double soundLevel;
  final int callDurationSeconds;
  final bool isMuted;
  final bool isSpeakerOn;
  final bool isUserSpeaking;
  final String? errorMessage;
  final String? crisisHotline;
  final String? crisisHotlineUrl;
  final bool isCrisisSession;
  final String voiceMode;
  final List<Map<String, dynamic>> pendingMemoryCandidates;
  final bool isFinalizing;
  final String? detectedEmotion;
  final double? detectedEmotionConfidence;
  final List<Map<String, dynamic>> activeEmotionsBreakdown;
  final AudioPipelineDiagnosticSnapshot? audioDiagnostics;
  final int? remainingSecondsInCycle;
  final int currentBilledMinute;
  final int coinsPerMinute;
  final bool isLowBalanceWarning;
  final bool isBillingEnded;
  final String? billingEndReason;

  const AiCallViewState({
    this.callState = CallState.idle,
    this.conversationMode = ConversationMode.hybridAuto,
    this.callId = '',
    this.userTurnId = 1,
    this.activeSttSessionId = 0,
    this.assistantTurnId = 0,
    this.currentTranscript = '',
    this.latestPartial = '',
    this.aiTranscript = '',
    this.accumulatedTranscript = '',
    this.soundLevel = 0.05,
    this.callDurationSeconds = 0,
    this.isMuted = false,
    this.isSpeakerOn = true,
    this.isUserSpeaking = false,
    this.errorMessage,
    this.crisisHotline,
    this.crisisHotlineUrl,
    this.isCrisisSession = false,
    this.voiceMode = 'mode_2',
    this.pendingMemoryCandidates = const [],
    this.isFinalizing = false,
    this.detectedEmotion,
    this.detectedEmotionConfidence,
    this.activeEmotionsBreakdown = const [],
    this.audioDiagnostics,
    this.remainingSecondsInCycle,
    this.currentBilledMinute = 0,
    this.coinsPerMinute = 1,
    this.isLowBalanceWarning = false,
    this.isBillingEnded = false,
    this.billingEndReason,
  });

  AiCallViewState copyWith({
    CallState? callState,
    ConversationMode? conversationMode,
    String? callId,
    int? userTurnId,
    int? activeSttSessionId,
    int? assistantTurnId,
    String? currentTranscript,
    String? latestPartial,
    String? aiTranscript,
    String? accumulatedTranscript,
    double? soundLevel,
    int? callDurationSeconds,
    bool? isMuted,
    bool? isSpeakerOn,
    bool? isUserSpeaking,
    String? errorMessage,
    String? crisisHotline,
    String? crisisHotlineUrl,
    bool? isCrisisSession,
    String? voiceMode,
    List<Map<String, dynamic>>? pendingMemoryCandidates,
    bool? isFinalizing,
    String? detectedEmotion,
    double? detectedEmotionConfidence,
    List<Map<String, dynamic>>? activeEmotionsBreakdown,
    AudioPipelineDiagnosticSnapshot? audioDiagnostics,
    int? remainingSecondsInCycle,
    int? currentBilledMinute,
    int? coinsPerMinute,
    bool? isLowBalanceWarning,
    bool? isBillingEnded,
    String? billingEndReason,
    bool clearCrisis = false,
    bool clearError = false,
    bool clearRemainingSeconds = false,
    bool clearBillingEnd = false,
  }) {
    return AiCallViewState(
      callState: callState ?? this.callState,
      conversationMode: conversationMode ?? this.conversationMode,
      callId: callId ?? this.callId,
      userTurnId: userTurnId ?? this.userTurnId,
      activeSttSessionId: activeSttSessionId ?? this.activeSttSessionId,
      assistantTurnId: assistantTurnId ?? this.assistantTurnId,
      currentTranscript: currentTranscript ?? this.currentTranscript,
      latestPartial: latestPartial ?? this.latestPartial,
      aiTranscript: aiTranscript ?? this.aiTranscript,
      accumulatedTranscript: accumulatedTranscript ?? this.accumulatedTranscript,
      soundLevel: soundLevel ?? this.soundLevel,
      callDurationSeconds: callDurationSeconds ?? this.callDurationSeconds,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isUserSpeaking: isUserSpeaking ?? this.isUserSpeaking,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      crisisHotline: clearCrisis ? null : (crisisHotline ?? this.crisisHotline),
      crisisHotlineUrl: clearCrisis ? null : (crisisHotlineUrl ?? this.crisisHotlineUrl),
      isCrisisSession: clearCrisis ? false : (isCrisisSession ?? this.isCrisisSession),
      voiceMode: voiceMode ?? this.voiceMode,
      pendingMemoryCandidates: pendingMemoryCandidates ?? this.pendingMemoryCandidates,
      isFinalizing: isFinalizing ?? this.isFinalizing,
      detectedEmotion: detectedEmotion ?? this.detectedEmotion,
      detectedEmotionConfidence: detectedEmotionConfidence ?? this.detectedEmotionConfidence,
      activeEmotionsBreakdown: activeEmotionsBreakdown ?? this.activeEmotionsBreakdown,
      audioDiagnostics: audioDiagnostics ?? this.audioDiagnostics,
      remainingSecondsInCycle: clearRemainingSeconds
          ? null
          : (remainingSecondsInCycle ?? this.remainingSecondsInCycle),
      currentBilledMinute: currentBilledMinute ?? this.currentBilledMinute,
      coinsPerMinute: coinsPerMinute ?? this.coinsPerMinute,
      isLowBalanceWarning: isLowBalanceWarning ?? this.isLowBalanceWarning,
      isBillingEnded: clearBillingEnd ? false : (isBillingEnded ?? this.isBillingEnded),
      billingEndReason: clearBillingEnd ? null : (billingEndReason ?? this.billingEndReason),
    );
  }
}

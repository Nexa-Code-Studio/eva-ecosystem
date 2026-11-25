import 'dart:typed_data';

/// Developer/runtime requested audio pipeline mode.
enum AudioPipelineModeConfig {
  auto('auto'),
  nativeHybrid('native_hybrid'),
  sttOnly('stt_only');

  final String wireName;
  const AudioPipelineModeConfig(this.wireName);
}

/// Effective active runtime audio pipeline mode.
enum EffectiveAudioPipelineMode {
  nativeHybrid('native_hybrid'),
  sttOnly('stt_only'),
  failed('failed');

  final String wireName;
  const EffectiveAudioPipelineMode(this.wireName);
}

/// Non-PII reason explaining why the pipeline degraded or failed.
enum FallbackReason {
  none('none'),
  platformUnsupported('platform_unsupported'),
  unsupportedOs('unsupported_os'),
  recognitionUnavailable('recognition_unavailable'),
  micSilencedByRecognizer('mic_silenced_by_recognizer'),
  pipeUnresponsive('pipe_unresponsive'),
  recognizerFatalError('recognizer_fatal_error'),
  forcedSttOnlyOverride('forced_stt_only_override'),
  forcedNativeHybridUnavailable('forced_native_hybrid_unavailable'),
  invalidOverrideDefaultedToAuto('invalid_override_defaulted_to_auto'),
  releaseBuildLockedToAuto('release_build_locked_to_auto');

  final String wireName;
  const FallbackReason(this.wireName);

  static FallbackReason fromNativeReason(String? raw) {
    if (raw == null || raw.isEmpty) return FallbackReason.none;
    final normalized = raw.toLowerCase();
    if (normalized.contains('silenced')) {
      return FallbackReason.micSilencedByRecognizer;
    }
    if (normalized.contains('pipe') || normalized.contains('timeout')) {
      return FallbackReason.pipeUnresponsive;
    }
    if (normalized.contains('recognition_unavailable')) {
      return FallbackReason.recognitionUnavailable;
    }
    return FallbackReason.recognizerFatalError;
  }
}

/// Native capability report returned by Android NativeAudioCapabilityChecker.
class AudioPipelineCapability {
  final bool supported;
  final int sdkInt;
  final bool isRecognitionAvailable;
  final bool isOnDeviceAvailable;
  final String? recognitionServicePackage;
  final bool supportsAudioSourceApi;
  final bool? localeSupported;
  final bool segmentedSessionCandidate;
  final String checkSupportStatus;

  const AudioPipelineCapability({
    required this.supported,
    required this.sdkInt,
    required this.isRecognitionAvailable,
    required this.isOnDeviceAvailable,
    this.recognitionServicePackage,
    required this.supportsAudioSourceApi,
    this.localeSupported,
    required this.segmentedSessionCandidate,
    required this.checkSupportStatus,
  });

  factory AudioPipelineCapability.unsupportedPlatform() {
    return const AudioPipelineCapability(
      supported: false,
      sdkInt: 0,
      isRecognitionAvailable: false,
      isOnDeviceAvailable: false,
      supportsAudioSourceApi: false,
      segmentedSessionCandidate: false,
      checkSupportStatus: 'non_android_platform',
    );
  }

  factory AudioPipelineCapability.fromMap(Map<dynamic, dynamic> map) {
    return AudioPipelineCapability(
      supported: map['supported'] == true,
      sdkInt: (map['sdkInt'] as num?)?.toInt() ?? 0,
      isRecognitionAvailable: map['isRecognitionAvailable'] == true,
      isOnDeviceAvailable: map['isOnDeviceAvailable'] == true,
      recognitionServicePackage: map['recognitionServicePackage'] as String?,
      supportsAudioSourceApi: map['supportsAudioSourceApi'] == true,
      localeSupported: map['localeSupported'] as bool?,
      segmentedSessionCandidate: map['segmentedSessionCandidate'] == true,
      checkSupportStatus: (map['checkSupportStatus'] as String?) ?? 'unknown',
    );
  }

  String toStatusSummary() {
    return 'sdk=$sdkInt,audioSourceApi=$supportsAudioSourceApi,'
        'recAvail=$isRecognitionAvailable,onDevice=$isOnDeviceAvailable,'
        'checkSupport=$checkSupportStatus,localeSupported=$localeSupported';
  }
}

/// Non-PII diagnostic snapshot emitted on initialization, mode selection, and fallback/failure.
class AudioPipelineDiagnosticSnapshot {
  final AudioPipelineModeConfig selectedMode;
  final EffectiveAudioPipelineMode effectiveMode;
  final String capabilityStatus;
  final FallbackReason fallbackReason;
  final String? nativeDetailReason;
  final String? configWarning;
  final bool isDebugOrProfileOverrideActive;

  const AudioPipelineDiagnosticSnapshot({
    required this.selectedMode,
    required this.effectiveMode,
    required this.capabilityStatus,
    required this.fallbackReason,
    this.nativeDetailReason,
    this.configWarning,
    required this.isDebugOrProfileOverrideActive,
  });

  String toDiagnosticLogLine() {
    final warningPart = configWarning != null ? ' configWarning=$configWarning' : '';
    final detailPart = nativeDetailReason != null ? ' detail=$nativeDetailReason' : '';
    return '[AUDIO PIPELINE] selectedMode=${selectedMode.wireName} '
        'effectiveMode=${effectiveMode.wireName} '
        'capabilityStatus=($capabilityStatus) '
        'fallbackReason=${fallbackReason.wireName}'
        '$detailPart$warningPart '
        'overrideActive=$isDebugOrProfileOverrideActive';
  }
}

/// Immutable PCM16 16kHz mono audio frame contract for STT transports and fan-out consumers.
class AudioPcmFrame {
  final Uint8List bytes;
  final int sessionId;
  final int generationId;
  final int sequence;
  final int timestampMs;

  const AudioPcmFrame({
    required this.bytes,
    required this.sessionId,
    required this.generationId,
    required this.sequence,
    required this.timestampMs,
  });
}

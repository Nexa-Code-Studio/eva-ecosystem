import 'package:flutter/foundation.dart';
import '../domain/entities/audio_pipeline_mode.dart';

/// Resolved compile-time / developer audio pipeline configuration.
class ResolvedAudioPipelineConfig {
  final AudioPipelineModeConfig selectedMode;
  final String rawConfiguredValue;
  final bool allowAutomaticFallback;
  final bool isDebugOrProfileOverrideActive;
  final String? configWarning;
  final FallbackReason configReason;

  const ResolvedAudioPipelineConfig({
    required this.selectedMode,
    required this.rawConfiguredValue,
    required this.allowAutomaticFallback,
    required this.isDebugOrProfileOverrideActive,
    this.configWarning,
    this.configReason = FallbackReason.none,
  });
}

/// Resolves `--dart-define=FORCE_AUDIO_PIPELINE_MODE=auto|native_hybrid|stt_only`.
///
/// Guarantees:
/// - Default is `auto`.
/// - Production (`kReleaseMode`) ALWAYS uses `auto` (ignores non-auto overrides with diagnostic warning).
/// - Debug/Profile supports `auto`, `native_hybrid` (no silent fallback), and `stt_only` (disables PCM & emotion).
/// - Invalid configuration emits an explicit non-PII diagnostic warning and falls back safely to `auto`.
class AudioPipelineConfigResolver {
  static const String _envForceMode = String.fromEnvironment(
    'FORCE_AUDIO_PIPELINE_MODE',
    defaultValue: 'auto',
  );

  final String _rawOverride;
  final bool _isReleaseMode;

  const AudioPipelineConfigResolver({
    String? rawOverride,
    bool? isReleaseMode,
  })  : _rawOverride = rawOverride ?? _envForceMode,
        _isReleaseMode = isReleaseMode ?? kReleaseMode;

  ResolvedAudioPipelineConfig resolve() {
    final trimmed = _rawOverride.trim();
    final normalized = trimmed.toLowerCase();

    if (_isReleaseMode) {
      final hasNonAutoOverride = normalized.isNotEmpty && normalized != 'auto';
      return ResolvedAudioPipelineConfig(
        selectedMode: AudioPipelineModeConfig.auto,
        rawConfiguredValue: trimmed.isEmpty ? 'auto' : trimmed,
        allowAutomaticFallback: true,
        isDebugOrProfileOverrideActive: false,
        configWarning: hasNonAutoOverride
            ? 'override_ignored_in_release:${_sanitizeForLog(trimmed)}'
            : null,
        configReason: hasNonAutoOverride
            ? FallbackReason.releaseBuildLockedToAuto
            : FallbackReason.none,
      );
    }

    if (normalized.isEmpty || normalized == 'auto') {
      return const ResolvedAudioPipelineConfig(
        selectedMode: AudioPipelineModeConfig.auto,
        rawConfiguredValue: 'auto',
        allowAutomaticFallback: true,
        isDebugOrProfileOverrideActive: false,
      );
    }

    if (normalized == 'native_hybrid') {
      return const ResolvedAudioPipelineConfig(
        selectedMode: AudioPipelineModeConfig.nativeHybrid,
        rawConfiguredValue: 'native_hybrid',
        allowAutomaticFallback: false,
        isDebugOrProfileOverrideActive: true,
      );
    }

    if (normalized == 'stt_only') {
      return const ResolvedAudioPipelineConfig(
        selectedMode: AudioPipelineModeConfig.sttOnly,
        rawConfiguredValue: 'stt_only',
        allowAutomaticFallback: false,
        isDebugOrProfileOverrideActive: true,
        configReason: FallbackReason.forcedSttOnlyOverride,
      );
    }

    return ResolvedAudioPipelineConfig(
      selectedMode: AudioPipelineModeConfig.auto,
      rawConfiguredValue: trimmed,
      allowAutomaticFallback: true,
      isDebugOrProfileOverrideActive: false,
      configWarning: 'invalid_override_value:${_sanitizeForLog(trimmed)}',
      configReason: FallbackReason.invalidOverrideDefaultedToAuto,
    );
  }

  static String _sanitizeForLog(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return cleaned.length > 32 ? cleaned.substring(0, 32) : cleaned;
  }
}

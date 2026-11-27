import 'package:flutter_test/flutter_test.dart';
import 'package:eva_mobile/features/voice_call/config/audio_pipeline_config.dart';
import 'package:eva_mobile/features/voice_call/domain/entities/audio_pipeline_mode.dart';

void main() {
  group('AudioPipelineConfigResolver', () {
    test('defaults to auto with automatic fallback enabled in debug/profile', () {
      const resolver = AudioPipelineConfigResolver(
        rawOverride: '',
        isReleaseMode: false,
      );
      final resolved = resolver.resolve();

      expect(resolved.selectedMode, AudioPipelineModeConfig.auto);
      expect(resolved.allowAutomaticFallback, isTrue);
      expect(resolved.isDebugOrProfileOverrideActive, isFalse);
      expect(resolved.configWarning, isNull);
    });

    test('supports native_hybrid override in debug/profile with no silent fallback', () {
      const resolver = AudioPipelineConfigResolver(
        rawOverride: 'native_hybrid',
        isReleaseMode: false,
      );
      final resolved = resolver.resolve();

      expect(resolved.selectedMode, AudioPipelineModeConfig.nativeHybrid);
      expect(resolved.allowAutomaticFallback, isFalse);
      expect(resolved.isDebugOrProfileOverrideActive, isTrue);
      expect(resolved.configWarning, isNull);
    });

    test('supports stt_only override in debug/profile', () {
      const resolver = AudioPipelineConfigResolver(
        rawOverride: 'stt_only',
        isReleaseMode: false,
      );
      final resolved = resolver.resolve();

      expect(resolved.selectedMode, AudioPipelineModeConfig.sttOnly);
      expect(resolved.allowAutomaticFallback, isFalse);
      expect(resolved.isDebugOrProfileOverrideActive, isTrue);
      expect(resolved.configReason, FallbackReason.forcedSttOnlyOverride);
      expect(resolved.configWarning, isNull);
    });

    test('locks production release builds to auto even when override is supplied', () {
      const forcedNativeRelease = AudioPipelineConfigResolver(
        rawOverride: 'native_hybrid',
        isReleaseMode: true,
      );
      final resolvedNative = forcedNativeRelease.resolve();

      expect(resolvedNative.selectedMode, AudioPipelineModeConfig.auto);
      expect(resolvedNative.allowAutomaticFallback, isTrue);
      expect(resolvedNative.isDebugOrProfileOverrideActive, isFalse);
      expect(resolvedNative.configReason, FallbackReason.releaseBuildLockedToAuto);
      expect(resolvedNative.configWarning, contains('override_ignored_in_release'));

      const forcedSttOnlyRelease = AudioPipelineConfigResolver(
        rawOverride: 'stt_only',
        isReleaseMode: true,
      );
      final resolvedStt = forcedSttOnlyRelease.resolve();
      expect(resolvedStt.selectedMode, AudioPipelineModeConfig.auto);
      expect(resolvedStt.allowAutomaticFallback, isTrue);
      expect(resolvedStt.configWarning, contains('override_ignored_in_release'));
    });

    test('emits clear diagnostic warning on invalid override and falls back safely to auto', () {
      const resolver = AudioPipelineConfigResolver(
        rawOverride: 'invalid_mode_xyz',
        isReleaseMode: false,
      );
      final resolved = resolver.resolve();

      expect(resolved.selectedMode, AudioPipelineModeConfig.auto);
      expect(resolved.allowAutomaticFallback, isTrue);
      expect(resolved.isDebugOrProfileOverrideActive, isFalse);
      expect(resolved.configReason, FallbackReason.invalidOverrideDefaultedToAuto);
      expect(resolved.configWarning, 'invalid_override_value:invalid_mode_xyz');
    });
  });
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../config/audio_pipeline_config.dart';
import '../../domain/entities/audio_pipeline_mode.dart';
import 'speech_recognition_service.dart';

/// Unified Single-Mic Audio Capture & Speech Service.
///
/// Orchestrates strictly mutually-exclusive microphone ownership:
/// - `nativeHybrid` (Android API 33+ validated): native Kotlin AudioRecord owns the mic
///   and fans out PCM16 16kHz mono asynchronously to Android SpeechRecognizer (virtual pipe)
///   and the Emotion2Vec WebSocket audio stream.
/// - `sttOnly` (fallback or explicit override): Flutter SpeechRecognitionService owns the mic
///   exclusively; native PCM capture and emotion streaming are disabled completely.
/// - `native_hybrid` debug/profile override never silently falls back to `sttOnly`.
class SingleAudioCaptureService {
  static const MethodChannel _defaultMethodChannel =
      MethodChannel('com.eva.single_audio/methods');
  static const EventChannel _defaultAudioStreamChannel =
      EventChannel('com.eva.single_audio/audio_stream');
  static const EventChannel _defaultSttEventsChannel =
      EventChannel('com.eva.single_audio/stt_events');

  final SpeechRecognitionService? _fallbackSpeechService;
  final AudioPipelineConfigResolver _configResolver;
  final MethodChannel _methodChannel;
  final EventChannel _audioStreamChannel;
  final EventChannel _sttEventsChannel;
  final bool _isAndroid;
  final void Function(String line)? _diagnosticLogger;

  SingleAudioCaptureService({
    SpeechRecognitionService? fallbackSpeechService,
    AudioPipelineConfigResolver? configResolver,
    MethodChannel? methodChannel,
    EventChannel? audioStreamChannel,
    EventChannel? sttEventsChannel,
    bool? isAndroidOverride,
    void Function(String line)? diagnosticLogger,
  })  : _fallbackSpeechService = fallbackSpeechService,
        _configResolver = configResolver ?? const AudioPipelineConfigResolver(),
        _methodChannel = methodChannel ?? _defaultMethodChannel,
        _audioStreamChannel = audioStreamChannel ?? _defaultAudioStreamChannel,
        _sttEventsChannel = sttEventsChannel ?? _defaultSttEventsChannel,
        _isAndroid = isAndroidOverride ?? (!kIsWeb && Platform.isAndroid),
        _diagnosticLogger = diagnosticLogger;

  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _isListening = false;
  bool _isMuted = false;
  bool _nativeCaptureActive = false;
  bool _fallbackLockedForAppSession = false;
  int _activeSttSessionId = 0;
  int _lastAcceptedGenerationId = 0;
  String _activeLocale = 'id-ID';

  ResolvedAudioPipelineConfig? _resolvedConfig;
  AudioPipelineCapability _capability = AudioPipelineCapability.unsupportedPlatform();
  EffectiveAudioPipelineMode _effectiveMode = EffectiveAudioPipelineMode.sttOnly;
  FallbackReason _fallbackReason = FallbackReason.none;
  String? _nativeDetailReason;

  // Serializes all async lifecycle operations (init/start/stop/mute/fallback) to prevent races.
  bool _opInFlight = false;
  Future<void> _opChain = Future<void>.value();

  StreamSubscription<dynamic>? _audioSubscription;
  StreamSubscription<dynamic>? _nativeSttSubscription;
  final List<StreamSubscription<dynamic>> _fallbackSubscriptions = [];

  final StreamController<Uint8List> _audioController =
      StreamController<Uint8List>.broadcast();
  final StreamController<SttPartialResult> _partialController =
      StreamController<SttPartialResult>.broadcast();
  final StreamController<SttFinalResult> _finalSegmentController =
      StreamController<SttFinalResult>.broadcast();
  final StreamController<SttStatusEvent> _statusController =
      StreamController<SttStatusEvent>.broadcast();
  final StreamController<double> _soundLevelController =
      StreamController<double>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();
  final StreamController<AudioPipelineDiagnosticSnapshot> _diagnosticController =
      StreamController<AudioPipelineDiagnosticSnapshot>.broadcast();

  Stream<Uint8List> get audioStream => _audioController.stream;
  Stream<SttPartialResult> get partialStream => _partialController.stream;
  Stream<SttFinalResult> get finalSegmentStream => _finalSegmentController.stream;
  Stream<SttStatusEvent> get statusStream => _statusController.stream;
  Stream<double> get soundLevelStream => _soundLevelController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<AudioPipelineDiagnosticSnapshot> get diagnosticStream =>
      _diagnosticController.stream;

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  int get activeSttSessionId => _activeSttSessionId;
  bool get isMuted => _isMuted;

  AudioPipelineModeConfig get selectedMode =>
      _resolvedConfig?.selectedMode ?? _configResolver.resolve().selectedMode;
  EffectiveAudioPipelineMode get effectiveMode => _effectiveMode;
  FallbackReason get fallbackReason => _fallbackReason;
  AudioPipelineCapability get capability => _capability;

  /// Raw 16kHz PCM16 stream is active ONLY when effective mode is Native Hybrid.
  bool get isRawAudioStreamSupported =>
      _effectiveMode == EffectiveAudioPipelineMode.nativeHybrid;

  bool get isInjectionSupported =>
      _effectiveMode == EffectiveAudioPipelineMode.nativeHybrid;

  AudioPipelineDiagnosticSnapshot get diagnosticSnapshot {
    final cfg = _resolvedConfig ?? _configResolver.resolve();
    return AudioPipelineDiagnosticSnapshot(
      selectedMode: cfg.selectedMode,
      effectiveMode: _effectiveMode,
      capabilityStatus: _capability.toStatusSummary(),
      fallbackReason: _fallbackReason,
      nativeDetailReason: _nativeDetailReason,
      configWarning: cfg.configWarning,
      isDebugOrProfileOverrideActive: cfg.isDebugOrProfileOverrideActive,
    );
  }

  Future<T> _enqueueOp<T>(Future<T> Function() action) {
    final completer = Completer<T>();

    Future<void> execute() async {
      _opInFlight = true;
      try {
        final result = await action();
        if (!completer.isCompleted) completer.complete(result);
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      } finally {
        _opInFlight = false;
      }
    }

    if (!_opInFlight) {
      // Start synchronously up to the first await while preserving strict serialization for concurrent callers.
      _opChain = execute().catchError((_) {});
    } else {
      _opChain = _opChain.then((_) => execute()).catchError((_) {});
    }
    return completer.future;
  }

  void _emitDiagnostics() {
    final snap = diagnosticSnapshot;
    final line = snap.toDiagnosticLogLine();
    if (_diagnosticLogger != null) {
      _diagnosticLogger(line);
    } else {
      debugPrint(line);
    }
    if (!_diagnosticController.isClosed) {
      _diagnosticController.add(snap);
    }
  }

  void _setupFallbackStreams() {
    for (final sub in _fallbackSubscriptions) {
      sub.cancel();
    }
    _fallbackSubscriptions.clear();

    final fallback = _fallbackSpeechService;
    if (fallback == null) return;

    _fallbackSubscriptions.add(
      fallback.partialStream.listen((data) {
        if (_effectiveMode == EffectiveAudioPipelineMode.sttOnly &&
            !_partialController.isClosed) {
          _partialController.add(data);
        }
      }),
    );
    _fallbackSubscriptions.add(
      fallback.finalSegmentStream.listen((data) {
        if (_effectiveMode == EffectiveAudioPipelineMode.sttOnly &&
            !_finalSegmentController.isClosed) {
          _finalSegmentController.add(data);
        }
      }),
    );
    _fallbackSubscriptions.add(
      fallback.statusStream.listen((data) {
        if (_effectiveMode == EffectiveAudioPipelineMode.sttOnly &&
            !_statusController.isClosed) {
          _statusController.add(data);
        }
      }),
    );
    _fallbackSubscriptions.add(
      fallback.soundLevelStream.listen((data) {
        if (_effectiveMode == EffectiveAudioPipelineMode.sttOnly &&
            !_soundLevelController.isClosed) {
          _soundLevelController.add(data);
        }
      }),
    );
    _fallbackSubscriptions.add(
      fallback.errorStream.listen((data) {
        if (_effectiveMode == EffectiveAudioPipelineMode.sttOnly &&
            !_errorController.isClosed) {
          _errorController.add(data);
        }
      }),
    );
  }

  void _subscribeNativeChannels() {
    _audioSubscription?.cancel();
    _audioSubscription = _audioStreamChannel.receiveBroadcastStream().listen(
      (dynamic data) {
        if (_isDisposed ||
            _effectiveMode != EffectiveAudioPipelineMode.nativeHybrid ||
            _isMuted) {
          return;
        }
        if (data is Uint8List) {
          if (!_audioController.isClosed) _audioController.add(data);
        } else if (data is List<int>) {
          if (!_audioController.isClosed) {
            _audioController.add(Uint8List.fromList(data));
          }
        }
      },
      onError: (dynamic error) {
        // Isolated: Emotion audio stream error never disrupts STT
        debugPrint('⚠️ [AUDIO PIPELINE] Native audio stream isolated error: $error');
      },
    );

    _nativeSttSubscription?.cancel();
    _nativeSttSubscription = _sttEventsChannel.receiveBroadcastStream().listen(
      (dynamic rawEvent) {
        if (_isDisposed || rawEvent is! Map) return;
        _handleNativeSttEvent(rawEvent);
      },
      onError: (dynamic error) {
        debugPrint('⚠️ [AUDIO PIPELINE] Native STT event stream error: $error');
      },
    );
  }

  void _unsubscribeNativeChannels() {
    _audioSubscription?.cancel();
    _audioSubscription = null;
    _nativeSttSubscription?.cancel();
    _nativeSttSubscription = null;
  }

  void _handleNativeSttEvent(Map<dynamic, dynamic> event) {
    final type = event['type'] as String?;
    if (type == null) return;

    final sessionId = (event['sttSessionId'] as num?)?.toInt() ?? _activeSttSessionId;
    final generationId = (event['generationId'] as num?)?.toInt() ?? 0;

    if (type == 'fallback_required') {
      final reasonStr = event['reason'] as String?;
      _enqueueOp(() => _transitionToSttOnlyFallback(
            reason: FallbackReason.fromNativeReason(reasonStr),
            nativeDetail: reasonStr,
            resumeActiveSession: _isListening && !_isMuted,
          ));
      return;
    }

    if (type == 'native_hybrid_failed') {
      final reasonStr = event['reason'] as String? ?? 'native_hybrid_failed';
      _enqueueOp(() => _handleForcedNativeHybridFailure(
            reason: FallbackReason.fromNativeReason(reasonStr),
            nativeDetail: reasonStr,
          ));
      return;
    }

    if (_effectiveMode != EffectiveAudioPipelineMode.nativeHybrid) return;
    if (generationId > 0 && generationId < _lastAcceptedGenerationId) return;
    if (generationId > _lastAcceptedGenerationId) {
      _lastAcceptedGenerationId = generationId;
    }

    if (type == 'sound_level') {
      final level = (event['level'] as num?)?.toDouble() ?? 0.0;
      if (!_isMuted && !_soundLevelController.isClosed) {
        _soundLevelController.add(level.clamp(0.0, 1.0));
      }
      return;
    }

    if (sessionId != _activeSttSessionId) return;

    final seq = (event['sequence'] as num?)?.toInt() ?? 0;
    if (type == 'partial') {
      final text = (event['text'] as String?)?.trim() ?? '';
      if (text.isNotEmpty && !_partialController.isClosed) {
        _partialController.add(SttPartialResult(
          text: text,
          sttSessionId: sessionId,
          sequence: seq,
        ));
      }
    } else if (type == 'final') {
      final text = (event['text'] as String?)?.trim() ?? '';
      if (text.isNotEmpty && !_finalSegmentController.isClosed) {
        _finalSegmentController.add(SttFinalResult(
          text: text,
          sttSessionId: sessionId,
          sequence: seq,
        ));
      }
    } else if (type == 'status') {
      final status = (event['status'] as String?) ?? '';
      if (status.isNotEmpty && !_statusController.isClosed) {
        _statusController.add(SttStatusEvent(
          status: status,
          sttSessionId: sessionId,
        ));
      }
    } else if (type == 'error') {
      final err = (event['error'] as String?) ?? 'native_stt_error';
      if (!_errorController.isClosed) {
        _errorController.add(err);
      }
    }
  }

  Future<bool> initialize({String locale = 'id-ID'}) {
    return _enqueueOp(() => _initializeLocked(locale: locale));
  }

  Future<bool> _initializeLocked({String locale = 'id-ID'}) async {
    if (_isDisposed) return false;
    if (_isInitialized) return true;

    _activeLocale = locale;
    final config = _configResolver.resolve();
    _resolvedConfig = config;
    _fallbackReason = config.configReason;
    _nativeDetailReason = null;

    // Case 1: Explicit stt_only override (debug/profile) -> disable native PCM & emotion completely.
    if (config.selectedMode == AudioPipelineModeConfig.sttOnly) {
      _capability = const AudioPipelineCapability(
        supported: false,
        sdkInt: 0,
        isRecognitionAvailable: false,
        isOnDeviceAvailable: false,
        supportsAudioSourceApi: false,
        segmentedSessionCandidate: false,
        checkSupportStatus: 'disabled_by_stt_only_override',
      );
      _effectiveMode = EffectiveAudioPipelineMode.sttOnly;
      _fallbackReason = FallbackReason.forcedSttOnlyOverride;
      await _initFallbackSpeechLocked();
      _isInitialized = true;
      _emitDiagnostics();
      return true;
    }

    // Case 2: Non-Android platform
    if (!_isAndroid) {
      _capability = AudioPipelineCapability.unsupportedPlatform();
      if (config.selectedMode == AudioPipelineModeConfig.nativeHybrid) {
        // Forced native_hybrid MUST NOT silently fall back.
        _effectiveMode = EffectiveAudioPipelineMode.failed;
        _fallbackReason = FallbackReason.forcedNativeHybridUnavailable;
        _nativeDetailReason = 'non_android_platform';
        _isInitialized = true;
        _emitDiagnostics();
        if (!_errorController.isClosed) {
          _errorController.add('native_hybrid_forced_unavailable:non_android_platform');
        }
        return false;
      }

      _effectiveMode = EffectiveAudioPipelineMode.sttOnly;
      _fallbackReason = FallbackReason.platformUnsupported;
      await _initFallbackSpeechLocked();
      _isInitialized = true;
      _emitDiagnostics();
      return true;
    }

    // Case 3: Android -> probe native capability without hardcoded emulator restrictions.
    try {
      final rawCap = await _methodChannel.invokeMethod<dynamic>(
        'checkCapability',
        {'locale': locale},
      );
      if (rawCap is Map) {
        _capability = AudioPipelineCapability.fromMap(rawCap);
      } else {
        _capability = AudioPipelineCapability.unsupportedPlatform();
      }
    } catch (e) {
      _capability = AudioPipelineCapability(
        supported: false,
        sdkInt: 0,
        isRecognitionAvailable: false,
        isOnDeviceAvailable: false,
        supportsAudioSourceApi: false,
        segmentedSessionCandidate: false,
        checkSupportStatus: 'channel_error:${e.runtimeType}',
      );
    }

    final nativeCapable = _capability.supportsAudioSourceApi &&
        _capability.isRecognitionAvailable &&
        !_fallbackLockedForAppSession;

    if (nativeCapable) {
      _effectiveMode = EffectiveAudioPipelineMode.nativeHybrid;
      _subscribeNativeChannels();
      _isInitialized = true;
      _emitDiagnostics();
      return true;
    }

    final incapReason = !_capability.supportsAudioSourceApi
        ? FallbackReason.unsupportedOs
        : FallbackReason.recognitionUnavailable;

    if (config.selectedMode == AudioPipelineModeConfig.nativeHybrid) {
      // Forced native_hybrid MUST NOT silently fall back.
      _effectiveMode = EffectiveAudioPipelineMode.failed;
      _fallbackReason = FallbackReason.forcedNativeHybridUnavailable;
      _nativeDetailReason = incapReason.wireName;
      _isInitialized = true;
      _emitDiagnostics();
      if (!_errorController.isClosed) {
        _errorController.add('native_hybrid_forced_unavailable:${incapReason.wireName}');
      }
      return false;
    }

    // Auto mode -> deterministic fallback to STT Only
    _effectiveMode = EffectiveAudioPipelineMode.sttOnly;
    _fallbackReason = incapReason;
    await _initFallbackSpeechLocked();
    _isInitialized = true;
    _emitDiagnostics();
    return true;
  }

  Future<void> _initFallbackSpeechLocked() async {
    final fallback = _fallbackSpeechService;
    if (fallback == null) return;
    if (!fallback.isInitialized) {
      await fallback.initialize();
    }
    _setupFallbackStreams();
  }

  Future<void> _transitionToSttOnlyFallback({
    required FallbackReason reason,
    String? nativeDetail,
    required bool resumeActiveSession,
  }) async {
    if (_isDisposed) return;

    final config = _resolvedConfig ?? _configResolver.resolve();
    if (!config.allowAutomaticFallback) {
      await _handleForcedNativeHybridFailure(
        reason: reason,
        nativeDetail: nativeDetail,
      );
      return;
    }

    if (_effectiveMode == EffectiveAudioPipelineMode.sttOnly) {
      return;
    }

    // 1. Enforce Mic-Release Barrier in Kotlin BEFORE starting speech_to_text
    if (_isAndroid) {
      try {
        await _methodChannel.invokeMethod<dynamic>(
          'stopAll',
          {'destroyRecognizer': true},
        );
      } catch (e) {
        debugPrint('⚠️ [AUDIO PIPELINE] Mic-Release Barrier stopAll error: $e');
      }
    }
    _nativeCaptureActive = false;
    _unsubscribeNativeChannels();

    // 2. Lock app session to stt_only to avoid oscillation/ping-pong
    _fallbackLockedForAppSession = true;
    _effectiveMode = EffectiveAudioPipelineMode.sttOnly;
    _fallbackReason = reason;
    _nativeDetailReason = nativeDetail;
    _emitDiagnostics();

    // 3. Initialize & resume fallback STT ONLY after barrier completed
    await _initFallbackSpeechLocked();
    if (resumeActiveSession && !_isMuted && !_isDisposed) {
      await _fallbackSpeechService?.startListening(
        sttSessionId: _activeSttSessionId,
      );
    }
  }

  Future<void> _handleForcedNativeHybridFailure({
    required FallbackReason reason,
    String? nativeDetail,
  }) async {
    if (_isDisposed) return;

    // Clean up native resources safely without leaking mic, but NEVER start speech_to_text
    if (_isAndroid) {
      try {
        await _methodChannel.invokeMethod<dynamic>(
          'stopAll',
          {'destroyRecognizer': true},
        );
      } catch (_) {}
    }
    _nativeCaptureActive = false;
    _isListening = false;
    _effectiveMode = EffectiveAudioPipelineMode.failed;
    _fallbackReason = reason;
    _nativeDetailReason = nativeDetail;
    _emitDiagnostics();

    if (!_errorController.isClosed) {
      _errorController.add('native_hybrid_failed:${nativeDetail ?? reason.wireName}');
    }
  }

  Future<void> setMuted(bool muted) {
    return _enqueueOp(() => _setMutedLocked(muted));
  }

  Future<void> _setMutedLocked(bool muted) async {
    if (_isDisposed) return;
    if (_isMuted == muted) return;
    _isMuted = muted;

    if (_effectiveMode == EffectiveAudioPipelineMode.nativeHybrid && _isAndroid) {
      try {
        await _methodChannel.invokeMethod<dynamic>('setMuted', {'muted': muted});
      } catch (e) {
        debugPrint('⚠️ [AUDIO PIPELINE] native setMuted error: $e');
      }
      if (muted && !_soundLevelController.isClosed) {
        _soundLevelController.add(0.0);
      }
      return;
    }

    if (_effectiveMode == EffectiveAudioPipelineMode.sttOnly) {
      _fallbackSpeechService?.setMuted(muted);
      if (!muted && _isListening) {
        await _fallbackSpeechService?.startListening(
          sttSessionId: _activeSttSessionId,
        );
      }
    }
  }

  Future<void> startListening({
    required int sttSessionId,
    String locale = 'id-ID',
    bool keepCaptureWarm = false,
  }) {
    return _enqueueOp(() => _startListeningLocked(
          sttSessionId: sttSessionId,
          locale: locale,
          keepCaptureWarm: keepCaptureWarm,
        ));
  }

  Future<void> _startListeningLocked({
    required int sttSessionId,
    required String locale,
    required bool keepCaptureWarm,
  }) async {
    if (_isDisposed || _isMuted) return;

    if (!_isInitialized) {
      final ok = await _initializeLocked(locale: locale);
      if (!ok) {
        return;
      }
    }

    _activeLocale = locale;
    _activeSttSessionId = sttSessionId;
    _isListening = true;

    if (_effectiveMode == EffectiveAudioPipelineMode.failed) {
      if (!_errorController.isClosed) {
        _errorController.add(
          'native_hybrid_failed:${_nativeDetailReason ?? _fallbackReason.wireName}',
        );
      }
      return;
    }

    if (_effectiveMode == EffectiveAudioPipelineMode.nativeHybrid && _isAndroid) {
      final config = _resolvedConfig ?? _configResolver.resolve();
      try {
        final bool started;
        if (keepCaptureWarm && _nativeCaptureActive) {
          started = (await _methodChannel.invokeMethod<bool>('rearmStt', {
                'locale': _activeLocale,
                'sttSessionId': sttSessionId,
                'enableSegmentedSession': _capability.segmentedSessionCandidate,
              })) ??
              false;
        } else {
          started = (await _methodChannel.invokeMethod<bool>('startNativeHybrid', {
                'locale': _activeLocale,
                'sttSessionId': sttSessionId,
                'enableSegmentedSession': _capability.segmentedSessionCandidate,
                'allowAutomaticFallback': config.allowAutomaticFallback,
              })) ??
              false;
        }

        if (started) {
          _nativeCaptureActive = true;
          return;
        }

        // Start returned false
        if (config.allowAutomaticFallback) {
          await _transitionToSttOnlyFallback(
            reason: FallbackReason.recognizerFatalError,
            nativeDetail: 'start_native_hybrid_returned_false',
            resumeActiveSession: true,
          );
        } else {
          await _handleForcedNativeHybridFailure(
            reason: FallbackReason.recognizerFatalError,
            nativeDetail: 'start_native_hybrid_returned_false',
          );
        }
      } catch (e) {
        if (config.allowAutomaticFallback) {
          await _transitionToSttOnlyFallback(
            reason: FallbackReason.recognizerFatalError,
            nativeDetail: 'method_channel_exception:${e.runtimeType}',
            resumeActiveSession: true,
          );
        } else {
          await _handleForcedNativeHybridFailure(
            reason: FallbackReason.recognizerFatalError,
            nativeDetail: 'method_channel_exception:${e.runtimeType}',
          );
        }
      }
      return;
    }

    // STT Only mode: speech_to_text exclusively owns microphone
    await _fallbackSpeechService?.startListening(sttSessionId: sttSessionId);
  }

  Future<void> stopListening() {
    return _enqueueOp(() => _stopListeningLocked(destroyRecognizer: false));
  }

  Future<void> _stopListeningLocked({required bool destroyRecognizer}) async {
    _isListening = false;

    if (_effectiveMode == EffectiveAudioPipelineMode.nativeHybrid && _isAndroid) {
      if (_nativeCaptureActive || destroyRecognizer) {
        try {
          await _methodChannel.invokeMethod<dynamic>(
            'stopAll',
            {'destroyRecognizer': destroyRecognizer},
          );
        } catch (e) {
          debugPrint('⚠️ [AUDIO PIPELINE] stopAll error: $e');
        }
        _nativeCaptureActive = false;
      }
    }

    if (_effectiveMode == EffectiveAudioPipelineMode.sttOnly) {
      await _fallbackSpeechService?.stopListening();
    }

    if (!_soundLevelController.isClosed) {
      _soundLevelController.add(0.0);
    }
  }

  Future<Map<String, dynamic>> getNativeDiagnostics() async {
    if (!_isAndroid || _effectiveMode == EffectiveAudioPipelineMode.sttOnly) {
      return {
        'selectedMode': selectedMode.wireName,
        'effectiveMode': _effectiveMode.wireName,
        'fallbackReason': _fallbackReason.wireName,
      };
    }
    try {
      final raw = await _methodChannel.invokeMethod<dynamic>('getDiagnostics');
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}
    return {};
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _isListening = false;

    if (_isAndroid && _nativeCaptureActive) {
      _methodChannel
          .invokeMethod<dynamic>('stopAll', {'destroyRecognizer': true})
          .catchError((_) {});
      _nativeCaptureActive = false;
    }

    _unsubscribeNativeChannels();
    for (final sub in _fallbackSubscriptions) {
      sub.cancel();
    }
    _fallbackSubscriptions.clear();
    _fallbackSpeechService?.dispose();

    _audioController.close();
    _partialController.close();
    _finalSegmentController.close();
    _statusController.close();
    _soundLevelController.close();
    _errorController.close();
    _diagnosticController.close();
  }
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'speech_recognition_service.dart';

/// Single Audio Capture & Speech Service.
/// Combines the battle-tested, reliable SpeechRecognitionService (speech_to_text with dictation mode
/// and auto-resolved Indonesian locale) for real-time STT, while concurrently running the
/// native AudioCaptureEngine worker to stream raw 16kHz PCM audio chunks to the VPS WebSocket
/// for Emotion2vec speech emotion analysis.
class SingleAudioCaptureService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.eva.single_audio/methods');
  static const EventChannel _audioStreamChannel =
      EventChannel('com.eva.single_audio/audio_stream');

  final SpeechRecognitionService? _fallbackSpeechService;

  SingleAudioCaptureService({SpeechRecognitionService? fallbackSpeechService})
      : _fallbackSpeechService = fallbackSpeechService;

  bool _isInitialized = false;
  bool _isListening = false;
  bool _isMuted = false;
  int _activeSttSessionId = 0;

  StreamSubscription? _audioSubscription;
  final List<StreamSubscription> _fallbackSubscriptions = [];

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

  Stream<Uint8List> get audioStream => _audioController.stream;
  Stream<SttPartialResult> get partialStream => _partialController.stream;
  Stream<SttFinalResult> get finalSegmentStream => _finalSegmentController.stream;
  Stream<SttStatusEvent> get statusStream => _statusController.stream;
  Stream<double> get soundLevelStream => _soundLevelController.stream;
  Stream<String> get errorStream => _errorController.stream;

  bool get isListening => _isListening;
  bool get isInitialized => _isInitialized;
  int get activeSttSessionId => _activeSttSessionId;
  bool get isMuted => _isMuted;

  /// Raw 16kHz PCM16 stream is currently implemented via Android native AudioRecord only.
  /// On iOS and non-Android platforms, voice calls gracefully operate in text-only fallback mode.
  bool get isRawAudioStreamSupported => Platform.isAndroid;

  /// Backward-compatible capability flag (virtual STT pipe injection is disabled in parallel mode).
  bool get isInjectionSupported => false;

  void _setupFallbackStreams() {
    for (final sub in _fallbackSubscriptions) {
      sub.cancel();
    }
    _fallbackSubscriptions.clear();

    if (_fallbackSpeechService != null) {
      _fallbackSubscriptions.add(
        _fallbackSpeechService.partialStream.listen((data) {
          if (!_partialController.isClosed) _partialController.add(data);
        }),
      );
      _fallbackSubscriptions.add(
        _fallbackSpeechService.finalSegmentStream.listen((data) {
          if (!_finalSegmentController.isClosed) _finalSegmentController.add(data);
        }),
      );
      _fallbackSubscriptions.add(
        _fallbackSpeechService.statusStream.listen((data) {
          if (!_statusController.isClosed) _statusController.add(data);
        }),
      );
      _fallbackSubscriptions.add(
        _fallbackSpeechService.soundLevelStream.listen((data) {
          if (!_soundLevelController.isClosed) _soundLevelController.add(data);
        }),
      );
      _fallbackSubscriptions.add(
        _fallbackSpeechService.errorStream.listen((data) {
          if (!_errorController.isClosed) _errorController.add(data);
        }),
      );
    }
  }

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    // 1. Initialize proven SpeechRecognitionService (speech_to_text with dictation mode)
    if (_fallbackSpeechService != null) {
      final sttOk = await _fallbackSpeechService.initialize();
      _setupFallbackStreams();
      debugPrint('🎙️ [PARALLEL AUDIO] STT Service initialized: $sttOk (Locale: ${_fallbackSpeechService.resolvedLocaleId})');
    }

    // 2. Setup native raw audio stream for VPS streaming on Android
    if (Platform.isAndroid) {
      try {
        _audioSubscription?.cancel();
        _audioSubscription = _audioStreamChannel.receiveBroadcastStream().listen(
          (dynamic data) {
            if (data is Uint8List) {
              if (!_audioController.isClosed) _audioController.add(data);
            } else if (data is List<int>) {
              if (!_audioController.isClosed) {
                _audioController.add(Uint8List.fromList(data));
              }
            }
          },
          onError: (dynamic error) {
            debugPrint('⚠️ [PARALLEL AUDIO] Audio stream error: $error');
          },
        );
        debugPrint('🎙️ [PARALLEL AUDIO] Native PCM audio stream listener active');
      } catch (e) {
        debugPrint('⚠️ [PARALLEL AUDIO] Failed to subscribe to native audio stream: $e');
      }
    }

    _isInitialized = true;
    return true;
  }

  void setMuted(bool muted) {
    _isMuted = muted;
    _fallbackSpeechService?.setMuted(muted);
    if (_isMuted && _isListening) {
      stopListening();
    }
  }

  Future<void> startListening({
    required int sttSessionId,
    String locale = 'id-ID',
  }) async {
    if (_isMuted) return;
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) {
        _errorController.add('Failed to initialize audio capture and STT');
        return;
      }
    }

    _activeSttSessionId = sttSessionId;
    _isListening = true;

    // 1. Start STT with proven speech_to_text configuration
    if (_fallbackSpeechService != null) {
      await _fallbackSpeechService.startListening(sttSessionId: sttSessionId);
    }

    // 2. Start parallel native audio worker to stream 16kHz PCM chunks to WebSocket for Emotion2vec
    if (Platform.isAndroid) {
      try {
        await _methodChannel.invokeMethod('startAudioCapture');
      } catch (e) {
        debugPrint('⚠️ [PARALLEL AUDIO] startAudioCapture method channel error: $e');
      }
    }
  }

  Future<void> stopListening() async {
    _isListening = false;

    // 1. Stop STT
    if (_fallbackSpeechService != null) {
      await _fallbackSpeechService.stopListening();
    }

    // 2. Stop parallel native audio worker
    if (Platform.isAndroid) {
      try {
        await _methodChannel.invokeMethod('stopAudioCapture');
      } catch (e) {
        debugPrint('⚠️ [PARALLEL AUDIO] stopAudioCapture method channel error: $e');
      }
    }
  }

  void dispose() {
    stopListening();
    _audioSubscription?.cancel();
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
  }
}

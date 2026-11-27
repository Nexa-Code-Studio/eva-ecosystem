import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Pure single-owner raw PCM 16kHz 16-bit mono audio capture service.
/// Captures 4800-byte (150ms) PCM frames from Android native AudioCaptureEngine
/// and forwards them along with normalized RMS sound levels to AiCallController.
class SingleAudioCaptureService {
  static const MethodChannel _defaultMethodChannel =
      MethodChannel('com.eva.single_audio/methods');
  static const EventChannel _defaultAudioStreamChannel =
      EventChannel('com.eva.single_audio/audio_stream');
  static const EventChannel _defaultAudioEventsChannel =
      EventChannel('com.eva.single_audio/audio_events');

  final MethodChannel _methodChannel;
  final EventChannel _audioStreamChannel;
  final EventChannel _audioEventsChannel;
  final bool Function() _isAndroidPlatform;
  final Future<bool> Function()? _permissionRequester;

  SingleAudioCaptureService({
    MethodChannel? methodChannel,
    EventChannel? audioStreamChannel,
    EventChannel? audioEventsChannel,
    bool Function()? isAndroidPlatform,
    Future<bool> Function()? permissionRequester,
  })  : _methodChannel = methodChannel ?? _defaultMethodChannel,
        _audioStreamChannel = audioStreamChannel ?? _defaultAudioStreamChannel,
        _audioEventsChannel = audioEventsChannel ?? _defaultAudioEventsChannel,
        _isAndroidPlatform =
            isAndroidPlatform ?? (() => !kIsWeb && Platform.isAndroid),
        _permissionRequester = permissionRequester;

  bool _isInitialized = false;
  bool _isCapturing = false;
  bool _isMuted = false;
  bool _isDisposed = false;

  StreamSubscription? _audioSubscription;
  StreamSubscription? _audioEventsSubscription;

  final StreamController<Uint8List> _audioController =
      StreamController<Uint8List>.broadcast();
  final StreamController<double> _soundLevelController =
      StreamController<double>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  Stream<Uint8List> get audioStream => _audioController.stream;
  Stream<double> get soundLevelStream => _soundLevelController.stream;
  Stream<String> get errorStream => _errorController.stream;

  bool get isInitialized => _isInitialized;
  bool get isCapturing => _isCapturing;
  bool get isListening => _isCapturing;
  bool get isMuted => _isMuted;

  /// Raw 16kHz PCM16 capture is implemented on Android native AudioRecord.
  bool get isRawAudioStreamSupported => _isAndroidPlatform();

  Future<bool> _ensureMicrophonePermission() async {
    if (_permissionRequester != null) {
      return _permissionRequester();
    }
    if (!_isAndroidPlatform()) return false;
    try {
      final status = await Permission.microphone.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('⚠️ [PCM CAPTURE] Microphone permission check error: $e');
      return false;
    }
  }

  Future<bool> initialize() async {
    if (_isDisposed) return false;
    if (_isInitialized) return true;

    if (_isAndroidPlatform()) {
      try {
        await _audioSubscription?.cancel();
        _audioSubscription =
            _audioStreamChannel.receiveBroadcastStream().listen(
          (dynamic data) {
            if (_isDisposed || _isMuted || !_isCapturing) return;
            if (data is Uint8List) {
              if (!_audioController.isClosed) _audioController.add(data);
            } else if (data is List<int>) {
              if (!_audioController.isClosed) {
                _audioController.add(Uint8List.fromList(data));
              }
            }
          },
          onError: (dynamic error) {
            if (!_errorController.isClosed) {
              _errorController.add('audio_stream_error: $error');
            }
          },
        );

        await _audioEventsSubscription?.cancel();
        _audioEventsSubscription =
            _audioEventsChannel.receiveBroadcastStream().listen(
          (dynamic data) {
            if (_isDisposed || data is! Map) return;
            final type = data['type'] as String?;
            if (type == 'sound_level') {
              final level = (data['level'] as num?)?.toDouble() ?? 0.0;
              if (!_soundLevelController.isClosed) {
                _soundLevelController.add(_isMuted ? 0.0 : level.clamp(0.0, 1.0));
              }
            } else if (type == 'error') {
              final message = data['error']?.toString() ?? 'native_audio_error';
              if (!_errorController.isClosed) {
                _errorController.add(message);
              }
            }
          },
          onError: (dynamic error) {
            if (!_errorController.isClosed) {
              _errorController.add('audio_events_error: $error');
            }
          },
        );
      } catch (e) {
        debugPrint('⚠️ [PCM CAPTURE] Channel subscription error: $e');
        if (!_errorController.isClosed) {
          _errorController.add('channel_subscribe_error: $e');
        }
      }
    }

    _isInitialized = true;
    return true;
  }

  Future<bool> startCapture() async {
    if (_isDisposed || _isMuted) return false;
    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return false;
    }
    if (_isCapturing) return true;

    if (!_isAndroidPlatform()) {
      return false;
    }

    final granted = await _ensureMicrophonePermission();
    if (!granted) {
      if (!_errorController.isClosed) {
        _errorController.add('microphone_permission_denied');
      }
      return false;
    }

    try {
      final started =
          await _methodChannel.invokeMethod<bool>('startCapture') ?? false;
      _isCapturing = started;
      if (!started && !_errorController.isClosed) {
        _errorController.add('native_capture_start_failed');
      }
      return started;
    } catch (e) {
      debugPrint('⚠️ [PCM CAPTURE] startCapture error: $e');
      if (!_errorController.isClosed) {
        _errorController.add('start_capture_error: $e');
      }
      return false;
    }
  }

  Future<void> stopCapture() async {
    if (!_isCapturing) return;
    _isCapturing = false;

    if (_isAndroidPlatform()) {
      try {
        await _methodChannel.invokeMethod('stopCapture');
      } catch (e) {
        debugPrint('⚠️ [PCM CAPTURE] stopCapture error: $e');
      }
    }
  }

  Future<void> setMuted(bool muted) async {
    if (_isMuted == muted) return;
    _isMuted = muted;

    if (_isAndroidPlatform()) {
      try {
        await _methodChannel.invokeMethod('setMuted', {'muted': muted});
      } catch (e) {
        debugPrint('⚠️ [PCM CAPTURE] setMuted error: $e');
      }
    }

    if (muted && _isCapturing) {
      await stopCapture();
    }
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    stopCapture();
    _audioSubscription?.cancel();
    _audioEventsSubscription?.cancel();
    _audioController.close();
    _soundLevelController.close();
    _errorController.close();
  }
}

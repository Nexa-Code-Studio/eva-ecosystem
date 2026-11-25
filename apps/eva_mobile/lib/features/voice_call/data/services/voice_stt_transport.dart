import 'dart:async';
import '../../domain/entities/audio_pipeline_mode.dart';
import 'speech_recognition_service.dart';

/// Explicit availability status for a VoiceSttTransport provider.
enum VoiceSttTransportAvailability {
  available,
  unavailable,
}

/// Structured non-PII error emitted by a VoiceSttTransport.
class VoiceSttTransportError {
  final String code;
  final String message;
  final bool isRecoverable;
  final int sttSessionId;
  final int generationId;

  const VoiceSttTransportError({
    required this.code,
    required this.message,
    this.isRecoverable = false,
    this.sttSessionId = 0,
    this.generationId = 0,
  });
}

/// Provider abstraction for future Remote Hybrid STT engines consuming PCM16 16kHz frames.
///
/// Lifecycle contract:
/// 1. `initialize()` probes/prepares transport and returns explicit availability.
/// 2. `start(...)` activates a recognition turn bound to `sttSessionId` & `generationId`.
/// 3. `ingestAudioFrame(...)` feeds 16kHz PCM16 frames without throwing on backpressure/unavailable.
/// 4. `stop()` gracefully finishes an active turn; `cancel()` aborts immediately.
/// 5. `partialStream`, `finalSegmentStream`, `statusStream`, `errorStream` report results & errors.
/// 6. `dispose()` releases resources idempotently.
abstract class VoiceSttTransport {
  String get providerId;
  VoiceSttTransportAvailability get availability;
  bool get isInitialized;
  bool get isActive;

  Stream<SttPartialResult> get partialStream;
  Stream<SttFinalResult> get finalSegmentStream;
  Stream<SttStatusEvent> get statusStream;
  Stream<VoiceSttTransportError> get errorStream;

  Future<VoiceSttTransportAvailability> initialize();

  Future<void> start({
    required int sttSessionId,
    required int generationId,
    String locale = 'id-ID',
  });

  Future<void> ingestAudioFrame(AudioPcmFrame frame);

  Future<void> stop();

  Future<void> cancel();

  Future<void> dispose();
}

/// Explicit no-op / unconfigured stub for Remote Hybrid STT.
/// Reports `unavailable` deterministically, does not integrate any paid provider,
/// and is NOT enabled as a runtime fallback in this phase.
class UnconfiguredRemoteHybridSttTransport implements VoiceSttTransport {
  final StreamController<SttPartialResult> _partialController =
      StreamController<SttPartialResult>.broadcast();
  final StreamController<SttFinalResult> _finalController =
      StreamController<SttFinalResult>.broadcast();
  final StreamController<SttStatusEvent> _statusController =
      StreamController<SttStatusEvent>.broadcast();
  final StreamController<VoiceSttTransportError> _errorController =
      StreamController<VoiceSttTransportError>.broadcast();

  bool _isInitialized = false;
  bool _isDisposed = false;
  int _droppedFrames = 0;

  @override
  String get providerId => 'remote_hybrid_unconfigured';

  @override
  VoiceSttTransportAvailability get availability =>
      VoiceSttTransportAvailability.unavailable;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isActive => false;

  int get droppedFramesCount => _droppedFrames;

  @override
  Stream<SttPartialResult> get partialStream => _partialController.stream;

  @override
  Stream<SttFinalResult> get finalSegmentStream => _finalController.stream;

  @override
  Stream<SttStatusEvent> get statusStream => _statusController.stream;

  @override
  Stream<VoiceSttTransportError> get errorStream => _errorController.stream;

  @override
  Future<VoiceSttTransportAvailability> initialize() async {
    if (_isDisposed) return VoiceSttTransportAvailability.unavailable;
    _isInitialized = true;
    return VoiceSttTransportAvailability.unavailable;
  }

  @override
  Future<void> start({
    required int sttSessionId,
    required int generationId,
    String locale = 'id-ID',
  }) async {
    if (_isDisposed) return;
    if (!_statusController.isClosed) {
      _statusController.add(SttStatusEvent(
        status: 'unavailable',
        sttSessionId: sttSessionId,
      ));
    }
    if (!_errorController.isClosed) {
      _errorController.add(VoiceSttTransportError(
        code: 'remote_stt_unavailable',
        message: 'Remote Hybrid STT provider is not configured in this build.',
        isRecoverable: false,
        sttSessionId: sttSessionId,
        generationId: generationId,
      ));
    }
  }

  @override
  Future<void> ingestAudioFrame(AudioPcmFrame frame) async {
    if (_isDisposed) return;
    _droppedFrames++;
  }

  @override
  Future<void> stop() async {
    // Idempotent no-op when unconfigured.
  }

  @override
  Future<void> cancel() async {
    // Idempotent no-op when unconfigured.
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    await _partialController.close();
    await _finalController.close();
    await _statusController.close();
    await _errorController.close();
  }
}

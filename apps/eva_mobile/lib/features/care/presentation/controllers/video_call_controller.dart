import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/consultation_session_entity.dart';
import '../../domain/entities/video_call_state_entity.dart';
import '../../domain/repositories/video_call_repository.dart';

class VideoCallController extends StateNotifier<VideoCallStateEntity> {
  final VideoCallRepository repository;
  Timer? _callTimer;
  Timer? _speechSimulationTimer;

  VideoCallController({
    required this.repository,
    required ConsultationSessionEntity initialSession,
  }) : super(VideoCallStateEntity(
          session: initialSession,
          connectionState: VideoCallConnectionState.connecting,
          roomId: 'room-${initialSession.id}',
        )) {
    _initializeCall(initialSession);
  }

  Future<void> _initializeCall(ConsultationSessionEntity session) async {
    try {
      state = state.copyWith(
        connectionState: VideoCallConnectionState.connecting,
      );

      final connectedState = await repository.joinCall(session);

      state = connectedState.copyWith(
        connectionState: VideoCallConnectionState.connected,
      );

      _startCallTimer();
      _startSpeechSimulation();
    } catch (e) {
      state = state.copyWith(
        connectionState: VideoCallConnectionState.reconnecting,
        errorMessage: e.toString(),
      );
    }
  }

  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      state = state.copyWith(
        callDurationSeconds: state.callDurationSeconds + 1,
      );
    });
  }

  void _startSpeechSimulation() {
    _speechSimulationTimer?.cancel();
    _speechSimulationTimer =
        Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      state = state.copyWith(
        isRemoteSpeaking: !state.isRemoteSpeaking,
      );
    });
  }

  void toggleMic() {
    final newMicState = !state.isMicMuted;
    state = state.copyWith(isMicMuted: newMicState);
    repository.syncMediaState(
      sessionId: state.session.id,
      isMicMuted: newMicState,
      isCameraOff: state.isCameraOff,
    );
  }

  void toggleCamera() {
    final newCameraState = !state.isCameraOff;
    state = state.copyWith(isCameraOff: newCameraState);
    repository.syncMediaState(
      sessionId: state.session.id,
      isMicMuted: state.isMicMuted,
      isCameraOff: newCameraState,
    );
  }

  void switchCamera() {
    state = state.copyWith(isFrontCamera: !state.isFrontCamera);
  }

  void toggleSpeaker() {
    state = state.copyWith(isSpeakerOn: !state.isSpeakerOn);
  }

  Future<void> endCall() async {
    _callTimer?.cancel();
    _speechSimulationTimer?.cancel();
    state = state.copyWith(connectionState: VideoCallConnectionState.ended);
    await repository.endCall(state.session.id);
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _speechSimulationTimer?.cancel();
    super.dispose();
  }
}

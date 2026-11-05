import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/video_call_state_entity.dart';
import '../../domain/repositories/video_call_repository.dart';

class VideoCallController extends StateNotifier<VideoCallSessionEntity> {
  final IVideoCallRepository _repository;
  Timer? _durationTimer;

  VideoCallController(this._repository, VideoCallSessionEntity initial)
      : super(initial);

  void startCall() async {
    state = state.copyWith(status: VideoCallStatus.connecting);
    await _repository.startSession(state.sessionId);
    state = state.copyWith(status: VideoCallStatus.connected);

    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      state = state.copyWith(
        callDuration: Duration(seconds: state.callDuration.inSeconds + 1),
      );
    });
  }

  void toggleMic() {
    state = state.copyWith(isMicMuted: !state.isMicMuted);
  }

  void toggleVideo() {
    state = state.copyWith(isVideoDisabled: !state.isVideoDisabled);
  }

  void flipCamera() {
    state = state.copyWith(isFrontCamera: !state.isFrontCamera);
  }

  void addQuickNote(String note) {
    if (note.trim().isEmpty) return;
    final updated = List<String>.from(state.realTimeNotes)..add(note.trim());
    state = state.copyWith(realTimeNotes: updated);
  }

  void endCall() async {
    _durationTimer?.cancel();
    state = state.copyWith(status: VideoCallStatus.ended);
    await _repository.endSession(
      state.sessionId,
      state.callDuration,
      state.realTimeNotes,
    );
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }
}

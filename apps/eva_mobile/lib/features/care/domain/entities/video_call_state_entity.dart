import 'package:flutter/foundation.dart';
import 'consultation_session_entity.dart';

enum VideoCallConnectionState {
  connecting,
  connected,
  reconnecting,
  ended,
}

@immutable
class VideoCallStateEntity {
  final ConsultationSessionEntity session;
  final VideoCallConnectionState connectionState;
  final bool isMicMuted;
  final bool isCameraOff;
  final bool isFrontCamera;
  final bool isSpeakerOn;
  final bool isRemoteSpeaking;
  final int callDurationSeconds;
  final String roomId;
  final String? token;
  final String? errorMessage;

  const VideoCallStateEntity({
    required this.session,
    this.connectionState = VideoCallConnectionState.connecting,
    this.isMicMuted = false,
    this.isCameraOff = false,
    this.isFrontCamera = true,
    this.isSpeakerOn = true,
    this.isRemoteSpeaking = true,
    this.callDurationSeconds = 0,
    required this.roomId,
    this.token,
    this.errorMessage,
  });

  VideoCallStateEntity copyWith({
    ConsultationSessionEntity? session,
    VideoCallConnectionState? connectionState,
    bool? isMicMuted,
    bool? isCameraOff,
    bool? isFrontCamera,
    bool? isSpeakerOn,
    bool? isRemoteSpeaking,
    int? callDurationSeconds,
    String? roomId,
    String? token,
    String? errorMessage,
  }) {
    return VideoCallStateEntity(
      session: session ?? this.session,
      connectionState: connectionState ?? this.connectionState,
      isMicMuted: isMicMuted ?? this.isMicMuted,
      isCameraOff: isCameraOff ?? this.isCameraOff,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isRemoteSpeaking: isRemoteSpeaking ?? this.isRemoteSpeaking,
      callDurationSeconds: callDurationSeconds ?? this.callDurationSeconds,
      roomId: roomId ?? this.roomId,
      token: token ?? this.token,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

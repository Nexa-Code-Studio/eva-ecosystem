import 'package:flutter/foundation.dart';
import 'package:webrtc_client/webrtc_client.dart';
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
  final VideoQualityPreset qualityPreset;
  final bool isCameraPermissionGranted;
  final bool isMicPermissionGranted;
  final bool isWaitingForCounselor;
  final bool isCounselorReconnecting;
  final String? counselorStatusMessage;
  final List<IceServerConfig> iceServers;
  final String? wsUrl;

  const VideoCallStateEntity({
    required this.session,
    this.connectionState = VideoCallConnectionState.connecting,
    this.isMicMuted = false,
    this.isCameraOff = false,
    this.isFrontCamera = true,
    this.isSpeakerOn = true,
    this.isRemoteSpeaking = false,
    this.callDurationSeconds = 0,
    required this.roomId,
    this.token,
    this.errorMessage,
    this.qualityPreset = VideoQualityPreset.hd720p,
    this.isCameraPermissionGranted = true,
    this.isMicPermissionGranted = true,
    this.isWaitingForCounselor = true,
    this.isCounselorReconnecting = false,
    this.counselorStatusMessage,
    this.iceServers = const [],
    this.wsUrl,
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
    VideoQualityPreset? qualityPreset,
    bool? isCameraPermissionGranted,
    bool? isMicPermissionGranted,
    bool? isWaitingForCounselor,
    bool? isCounselorReconnecting,
    String? counselorStatusMessage,
    bool clearCounselorStatusMessage = false,
    List<IceServerConfig>? iceServers,
    String? wsUrl,
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
      qualityPreset: qualityPreset ?? this.qualityPreset,
      isCameraPermissionGranted:
          isCameraPermissionGranted ?? this.isCameraPermissionGranted,
      isMicPermissionGranted:
          isMicPermissionGranted ?? this.isMicPermissionGranted,
      isWaitingForCounselor:
          isWaitingForCounselor ?? this.isWaitingForCounselor,
      isCounselorReconnecting:
          isCounselorReconnecting ?? this.isCounselorReconnecting,
      counselorStatusMessage: clearCounselorStatusMessage
          ? null
          : (counselorStatusMessage ?? this.counselorStatusMessage),
      iceServers: iceServers ?? this.iceServers,
      wsUrl: wsUrl ?? this.wsUrl,
    );
  }
}

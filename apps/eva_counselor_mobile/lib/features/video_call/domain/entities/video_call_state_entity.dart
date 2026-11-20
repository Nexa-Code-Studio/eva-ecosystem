import 'package:webrtc_client/webrtc_client.dart';

enum VideoCallStatus {
  idle,
  waiting,
  connecting,
  connected,
  reconnecting,
  ended,
  error,
}

class VideoCallSessionEntity {
  final String sessionId;
  final String patientId;
  final String patientName;
  final DateTime scheduledTime;
  final Duration callDuration;
  final VideoCallStatus status;
  final bool isMicMuted;
  final bool isVideoDisabled;
  final bool isFrontCamera;
  final bool isSpeakerOn;
  final VideoQualityPreset qualityPreset;
  final List<String> realTimeNotes;
  final List<String> liveChatMessages;

  // Connection & Waiting states
  final bool isWaitingForPatient;
  final bool isPatientReconnecting;
  final String? patientStatusMessage;

  // Permissions
  final bool isCameraPermissionGranted;
  final bool isMicPermissionGranted;

  // Credentials
  final String? signalingToken;
  final String? channelName;
  final String? wsUrl;
  final List<IceServerConfig> iceServers;

  // In-call 30-min extension fields
  final bool isExtended;
  final bool isExtensionRequested;
  final Duration maxDuration;
  final bool? isExtensionApproved;

  const VideoCallSessionEntity({
    required this.sessionId,
    required this.patientId,
    required this.patientName,
    required this.scheduledTime,
    this.callDuration = Duration.zero,
    this.status = VideoCallStatus.idle,
    this.isMicMuted = false,
    this.isVideoDisabled = false,
    this.isFrontCamera = true,
    this.isSpeakerOn = true,
    this.qualityPreset = VideoQualityPreset.hd720p,
    this.realTimeNotes = const [],
    this.liveChatMessages = const [],
    this.isWaitingForPatient = true,
    this.isPatientReconnecting = false,
    this.patientStatusMessage,
    this.isCameraPermissionGranted = true,
    this.isMicPermissionGranted = true,
    this.signalingToken,
    this.channelName,
    this.wsUrl,
    this.iceServers = const [],
    this.isExtended = false,
    this.isExtensionRequested = false,
    this.maxDuration = const Duration(minutes: 30),
    this.isExtensionApproved,
  });

  VideoCallSessionEntity copyWith({
    String? sessionId,
    String? patientId,
    String? patientName,
    DateTime? scheduledTime,
    Duration? callDuration,
    VideoCallStatus? status,
    bool? isMicMuted,
    bool? isVideoDisabled,
    bool? isFrontCamera,
    bool? isSpeakerOn,
    VideoQualityPreset? qualityPreset,
    List<String>? realTimeNotes,
    List<String>? liveChatMessages,
    bool? isWaitingForPatient,
    bool? isPatientReconnecting,
    String? patientStatusMessage,
    bool clearPatientStatusMessage = false,
    bool? isCameraPermissionGranted,
    bool? isMicPermissionGranted,
    String? signalingToken,
    String? channelName,
    String? wsUrl,
    List<IceServerConfig>? iceServers,
    bool? isExtended,
    bool? isExtensionRequested,
    Duration? maxDuration,
    bool? isExtensionApproved,
  }) {
    return VideoCallSessionEntity(
      sessionId: sessionId ?? this.sessionId,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      callDuration: callDuration ?? this.callDuration,
      status: status ?? this.status,
      isMicMuted: isMicMuted ?? this.isMicMuted,
      isVideoDisabled: isVideoDisabled ?? this.isVideoDisabled,
      isFrontCamera: isFrontCamera ?? this.isFrontCamera,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      qualityPreset: qualityPreset ?? this.qualityPreset,
      realTimeNotes: realTimeNotes ?? this.realTimeNotes,
      liveChatMessages: liveChatMessages ?? this.liveChatMessages,
      isWaitingForPatient: isWaitingForPatient ?? this.isWaitingForPatient,
      isPatientReconnecting: isPatientReconnecting ?? this.isPatientReconnecting,
      patientStatusMessage: clearPatientStatusMessage
          ? null
          : (patientStatusMessage ?? this.patientStatusMessage),
      isCameraPermissionGranted:
          isCameraPermissionGranted ?? this.isCameraPermissionGranted,
      isMicPermissionGranted:
          isMicPermissionGranted ?? this.isMicPermissionGranted,
      signalingToken: signalingToken ?? this.signalingToken,
      channelName: channelName ?? this.channelName,
      wsUrl: wsUrl ?? this.wsUrl,
      iceServers: iceServers ?? this.iceServers,
      isExtended: isExtended ?? this.isExtended,
      isExtensionRequested: isExtensionRequested ?? this.isExtensionRequested,
      maxDuration: maxDuration ?? this.maxDuration,
      isExtensionApproved: isExtensionApproved ?? this.isExtensionApproved,
    );
  }
}

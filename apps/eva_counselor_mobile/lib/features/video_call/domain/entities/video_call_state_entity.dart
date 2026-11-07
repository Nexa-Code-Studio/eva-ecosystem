enum VideoCallStatus {
  idle,
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
  final List<String> realTimeNotes;

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
    this.realTimeNotes = const [],
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
    List<String>? realTimeNotes,
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
      realTimeNotes: realTimeNotes ?? this.realTimeNotes,
    );
  }
}

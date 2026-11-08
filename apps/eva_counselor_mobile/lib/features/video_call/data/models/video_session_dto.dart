import '../../domain/entities/video_call_state_entity.dart';

class VideoSessionResponseDto {
  final String sessionId;
  final String patientId;
  final String patientName;
  final String scheduledTime;
  final String status;
  final String? signalingToken;
  final String? channelName;

  const VideoSessionResponseDto({
    required this.sessionId,
    required this.patientId,
    required this.patientName,
    required this.scheduledTime,
    required this.status,
    this.signalingToken,
    this.channelName,
  });

  factory VideoSessionResponseDto.fromJson(Map<String, dynamic> json) {
    return VideoSessionResponseDto(
      sessionId: json['session_id']?.toString() ?? '',
      patientId: json['patient_id']?.toString() ?? '',
      patientName: json['patient_name']?.toString() ?? 'Pasien',
      scheduledTime: json['scheduled_time']?.toString() ??
          DateTime.now().toIso8601String(),
      status: json['status']?.toString() ?? 'ready',
      signalingToken: json['signaling_token']?.toString(),
      channelName: json['channel_name']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'patient_id': patientId,
        'patient_name': patientName,
        'scheduled_time': scheduledTime,
        'status': status,
        'signaling_token': signalingToken,
        'channel_name': channelName,
      };

  VideoCallSessionEntity toEntity() {
    return VideoCallSessionEntity(
      sessionId: sessionId,
      patientId: patientId,
      patientName: patientName,
      scheduledTime: DateTime.tryParse(scheduledTime) ?? DateTime.now(),
      status: VideoCallStatus.idle,
    );
  }
}

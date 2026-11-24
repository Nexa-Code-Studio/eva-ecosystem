import 'package:webrtc_client/webrtc_client.dart';
import '../../domain/entities/video_call_state_entity.dart';

class IceServerDto {
  final List<String> urls;
  final String? username;
  final String? credential;

  const IceServerDto({
    required this.urls,
    this.username,
    this.credential,
  });

  factory IceServerDto.fromJson(Map<String, dynamic> json) {
    final rawUrls = json['urls'];
    List<String> parsedUrls = [];
    if (rawUrls is List) {
      parsedUrls = rawUrls.map((e) => e.toString()).toList();
    } else if (rawUrls is String) {
      parsedUrls = [rawUrls];
    }
    return IceServerDto(
      urls: parsedUrls,
      username: json['username']?.toString(),
      credential: json['credential']?.toString(),
    );
  }

  IceServerConfig toDomain() => IceServerConfig(
        urls: urls,
        username: username,
        credential: credential,
      );

  Map<String, dynamic> toJson() => {
        'urls': urls,
        if (username != null) 'username': username,
        if (credential != null) 'credential': credential,
      };
}

class VideoSessionResponseDto {
  final String sessionId;
  final String patientId;
  final String patientName;
  final String scheduledTime;
  final String status;
  final String? signalingToken;
  final String? channelName;
  final String? wsUrl;
  final List<IceServerDto> iceServerConfigs;

  const VideoSessionResponseDto({
    required this.sessionId,
    required this.patientId,
    required this.patientName,
    required this.scheduledTime,
    required this.status,
    this.signalingToken,
    this.channelName,
    this.wsUrl,
    this.iceServerConfigs = const [],
  });

  factory VideoSessionResponseDto.fromJson(Map<String, dynamic> json) {
    final token = json['signaling_token']?.toString() ?? json['token']?.toString();
    final channel = json['channel_name']?.toString() ?? json['room_id']?.toString();

    // Parse ICE server configs (both structured ice_server_configs and flat ice_servers list)
    List<IceServerDto> configs = [];
    if (json['ice_server_configs'] is List) {
      configs = (json['ice_server_configs'] as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => IceServerDto.fromJson(m))
          .toList();
    } else if (json['ice_servers'] is List) {
      final flatUrls = (json['ice_servers'] as List).map((e) => e.toString()).toList();
      configs = [IceServerDto(urls: flatUrls)];
    }

    return VideoSessionResponseDto(
      sessionId: json['session_id']?.toString() ?? '',
      patientId: json['patient_id']?.toString() ?? '',
      patientName: json['patient_name']?.toString() ?? 'Pasien',
      scheduledTime: json['scheduled_time']?.toString() ??
          DateTime.now().toIso8601String(),
      status: json['status']?.toString() ?? 'ready',
      signalingToken: token,
      channelName: channel,
      wsUrl: json['ws_url']?.toString(),
      iceServerConfigs: configs,
    );
  }

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'patient_id': patientId,
        'patient_name': patientName,
        'scheduled_time': scheduledTime,
        'status': status,
        if (signalingToken != null) 'signaling_token': signalingToken,
        if (channelName != null) 'channel_name': channelName,
        if (wsUrl != null) 'ws_url': wsUrl,
        'ice_server_configs': iceServerConfigs.map((e) => e.toJson()).toList(),
      };

  VideoCallSessionEntity toEntity() {
    return VideoCallSessionEntity(
      sessionId: sessionId,
      patientId: patientId,
      patientName: patientName,
      scheduledTime: DateTime.tryParse(scheduledTime) ?? DateTime.now(),
      status: VideoCallStatus.idle,
      signalingToken: signalingToken,
      channelName: channelName,
      wsUrl: wsUrl,
      iceServers: iceServerConfigs.map((e) => e.toDomain()).toList(),
    );
  }
}

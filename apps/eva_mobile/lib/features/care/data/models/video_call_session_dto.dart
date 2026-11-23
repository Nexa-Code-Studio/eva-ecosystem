import 'package:webrtc_client/webrtc_client.dart';

class VideoCallSessionDto {
  final String sessionId;
  final String roomId;
  final String token;
  final String? participantId;
  final String status;
  final List<String> iceServers;
  final List<IceServerConfig> iceServerConfigs;
  final String? wsUrl;

  const VideoCallSessionDto({
    required this.sessionId,
    required this.roomId,
    required this.token,
    this.participantId,
    required this.status,
    this.iceServers = const [],
    this.iceServerConfigs = const [],
    this.wsUrl,
  });

  factory VideoCallSessionDto.fromJson(Map<String, dynamic> json) {
    final rawServers = (json['ice_servers'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const [];

    List<IceServerConfig> configs = [];
    if (json['ice_server_configs'] is List) {
      configs = (json['ice_server_configs'] as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => IceServerConfig.fromJson(m))
          .toList();
    } else if (rawServers.isNotEmpty) {
      configs = [IceServerConfig(urls: rawServers)];
    }

    return VideoCallSessionDto(
      sessionId: json['session_id'] as String? ?? '',
      roomId: json['room_id'] as String? ?? 'eva-room-default',
      token: json['token'] as String? ?? '',
      participantId: json['participant_id'] as String?,
      status: json['status'] as String? ?? 'active',
      iceServers: rawServers,
      iceServerConfigs: configs,
      wsUrl: json['ws_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'room_id': roomId,
      'token': token,
      'participant_id': participantId,
      'status': status,
      'ice_servers': iceServers,
      'ice_server_configs': iceServerConfigs.map((c) => c.toMap()).toList(),
      if (wsUrl != null) 'ws_url': wsUrl,
    };
  }
}

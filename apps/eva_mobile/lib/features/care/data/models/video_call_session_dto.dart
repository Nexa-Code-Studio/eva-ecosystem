class VideoCallSessionDto {
  final String sessionId;
  final String roomId;
  final String token;
  final String? participantId;
  final String status;
  final List<String> iceServers;

  const VideoCallSessionDto({
    required this.sessionId,
    required this.roomId,
    required this.token,
    this.participantId,
    required this.status,
    this.iceServers = const [],
  });

  factory VideoCallSessionDto.fromJson(Map<String, dynamic> json) {
    return VideoCallSessionDto(
      sessionId: json['session_id'] as String? ?? '',
      roomId: json['room_id'] as String? ?? 'eva-room-default',
      token: json['token'] as String? ?? '',
      participantId: json['participant_id'] as String?,
      status: json['status'] as String? ?? 'active',
      iceServers: (json['ice_servers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
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
    };
  }
}

class SignalingMessage {
  final String type;
  final String? senderRole;
  final String? senderId;
  final String timestamp;
  final Map<String, dynamic> payload;

  const SignalingMessage({
    required this.type,
    this.senderRole,
    this.senderId,
    required this.timestamp,
    required this.payload,
  });

  factory SignalingMessage.create({
    required String type,
    String? senderRole,
    String? senderId,
    Map<String, dynamic>? payload,
  }) {
    return SignalingMessage(
      type: type,
      senderRole: senderRole,
      senderId: senderId,
      timestamp: DateTime.now().toUtc().toIso8601String(),
      payload: payload ?? const {},
    );
  }

  factory SignalingMessage.fromJson(Map<String, dynamic> json) {
    return SignalingMessage(
      type: json['type']?.toString() ?? '',
      senderRole: json['sender_role']?.toString(),
      senderId: json['sender_id']?.toString(),
      timestamp: json['timestamp']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
      payload: (json['payload'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        if (senderRole != null) 'sender_role': senderRole,
        if (senderId != null) 'sender_id': senderId,
        'timestamp': timestamp,
        'payload': payload,
      };
}

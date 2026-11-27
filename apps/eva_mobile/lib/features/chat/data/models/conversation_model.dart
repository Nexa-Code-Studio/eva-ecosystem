import '../../domain/entities/conversation_entity.dart';
import 'chat_message_model.dart';

class ConversationModel extends ConversationEntity {
  const ConversationModel({
    required super.id,
    required super.title,
    required super.date,
    required super.lastSessionTime,
    super.duration = '00:00',
    required super.moodTag,
    required super.moodEmoji,
    required super.summary,
    required super.messages,
    super.emotionsBreakdown = const [],
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final rawMessages = (json['messages'] ?? json['transcripts']) as List? ?? [];
    final rawEmotions = (json['emotions_breakdown'] ?? json['emotionsBreakdown']) as List? ?? [];
    return ConversationModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      lastSessionTime: json['last_session_time']?.toString() ??
          json['lastSessionTime']?.toString() ??
          json['lastMessageTime']?.toString() ??
          '',
      duration: json['duration']?.toString() ?? '00:00',
      moodTag: json['mood_tag']?.toString() ??
          json['moodTag']?.toString() ??
          json['dominant_emotion']?.toString() ??
          '',
      moodEmoji: json['mood_emoji']?.toString() ??
          json['moodEmoji']?.toString() ??
          json['dominant_emoji']?.toString() ??
          '',
      summary: json['summary']?.toString() ?? '',
      messages: rawMessages.map((m) => ChatMessageModel.fromJson(m)).toList(),
      emotionsBreakdown: rawEmotions
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date,
      'last_session_time': lastSessionTime,
      'duration': duration,
      'mood_tag': moodTag,
      'mood_emoji': moodEmoji,
      'summary': summary,
      'messages': messages.map((m) => (m as ChatMessageModel).toJson()).toList(),
      'emotions_breakdown': emotionsBreakdown,
    };
  }
}

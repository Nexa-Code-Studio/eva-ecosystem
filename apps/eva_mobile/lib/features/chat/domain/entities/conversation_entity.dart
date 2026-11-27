import 'chat_message_entity.dart';

class ConversationEntity {
  final String id;
  final String title;
  final String date;
  final String lastSessionTime;
  final String duration;
  final String moodTag;
  final String moodEmoji;
  final String summary;
  final List<ChatMessageEntity> messages;
  final List<Map<String, dynamic>> emotionsBreakdown;

  const ConversationEntity({
    required this.id,
    required this.title,
    required this.date,
    required this.lastSessionTime,
    this.duration = '00:00',
    required this.moodTag,
    required this.moodEmoji,
    required this.summary,
    required this.messages,
    this.emotionsBreakdown = const [],
  });
}

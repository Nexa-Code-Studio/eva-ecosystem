import '../../domain/repositories/chat_repository.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../../../../config/app_config.dart';

/// Local-First chat repository that strictly prioritizes encrypted on-device session summaries.
/// Under the Zero Cloud Persistence policy, conversations and transcripts are never stored on
/// or retrieved from the remote backend. Returns a clean empty state when no local sessions exist.
class FallbackChatRepository implements ChatRepository {
  final ChatRepository _local;
  final ChatRepository? _mock;

  FallbackChatRepository({
    required ChatRepository local,
    ChatRepository? remote,
    ChatRepository? mock,
  })  : _local = local,
        _mock = mock;

  @override
  Future<List<ConversationEntity>> getConversations() async {
    // 1. Retrieve local on-device voice sessions first
    List<ConversationEntity> localList = const [];
    try {
      localList = await _local.getConversations();
    } catch (_) {
      localList = const [];
    }

    if (localList.isNotEmpty) {
      return localList;
    }

    // 2. Under Zero Cloud Persistence, conversation history is never retrieved from cloud PostgreSQL.
    // Fallback to mock only if mock profile is explicitly enabled
    if (AppConfig.useMockData && _mock != null) {
      return await _mock.getConversations();
    }

    // 3. Return clean empty state for new/unpopulated users
    return const <ConversationEntity>[];
  }

  @override
  Future<ConversationEntity?> getConversationById(String id) async {
    // 1. Check local on-device storage first
    try {
      final localConv = await _local.getConversationById(id);
      if (localConv != null) return localConv;
    } catch (_) {}

    // 2. Fallback to mock only if explicitly enabled
    if (AppConfig.useMockData && _mock != null) {
      return await _mock.getConversationById(id);
    }

    return null;
  }

  @override
  Future<ChatMessageEntity> sendMessage(String conversationId, String text) {
    return _local.sendMessage(conversationId, text);
  }

  @override
  Stream<String> streamConversationSummary(String conversationId) async* {
    await for (final token in _local.streamConversationSummary(conversationId)) {
      yield token;
    }
  }
}


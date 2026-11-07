import '../../domain/repositories/chat_repository.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../../../../core/network/fallback_policy.dart';

class FallbackChatRepository implements ChatRepository {
  final ChatRepository _remote;
  final ChatRepository _mock;

  FallbackChatRepository({
    required ChatRepository remote,
    required ChatRepository mock,
  })  : _remote = remote,
        _mock = mock;

  @override
  Future<List<ConversationEntity>> getConversations() {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.getConversations(),
      mockCall: () => _mock.getConversations(),
      operationName: 'getConversations',
    );
  }

  @override
  Future<ConversationEntity?> getConversationById(String id) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.getConversationById(id),
      mockCall: () => _mock.getConversationById(id),
      operationName: 'getConversationById($id)',
    );
  }

  @override
  Future<ChatMessageEntity> sendMessage(String conversationId, String text) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.sendMessage(conversationId, text),
      mockCall: () => _mock.sendMessage(conversationId, text),
      operationName: 'sendMessage',
    );
  }

  @override
  Stream<String> streamConversationSummary(String conversationId) {
    return FallbackExecutor.executeStream(
      remoteStreamCall: () => _remote.streamConversationSummary(conversationId),
      mockStreamCall: () => _mock.streamConversationSummary(conversationId),
      operationName: 'streamConversationSummary($conversationId)',
    );
  }
}

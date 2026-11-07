import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../data/datasources/mock_chat_datasource.dart';
import '../../data/datasources/remote_chat_datasource.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../data/repositories/fallback_chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final mockRepo = ChatRepositoryImpl(MockChatDataSource());
  final remoteRepo = ChatRepositoryImpl(RemoteChatDataSource());

  if (AppConfig.useMockData) {
    return mockRepo;
  } else if (AppConfig.useHybridFallback) {
    return FallbackChatRepository(remote: remoteRepo, mock: mockRepo);
  } else {
    return remoteRepo;
  }
});

final conversationsProvider = FutureProvider<List<ConversationEntity>>((ref) async {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.getConversations();
});

final conversationDetailProvider = FutureProvider.family<ConversationEntity?, String>((ref, id) async {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.getConversationById(id);
});

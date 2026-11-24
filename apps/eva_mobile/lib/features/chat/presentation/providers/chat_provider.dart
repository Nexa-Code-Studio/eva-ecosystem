import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eva_mobile/config/app_config.dart';
import '../../../../features/memory/presentation/providers/memory_provider.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../data/datasources/mock_chat_datasource.dart';
import '../../data/datasources/local_chat_datasource.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../data/repositories/fallback_chat_repository.dart';

final localChatDataSourceProvider = Provider<LocalChatDataSource>((ref) {
  final localDb = ref.watch(encryptedLocalDatabaseProvider);
  return LocalChatDataSource(localDb);
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final mockRepo = ChatRepositoryImpl(MockChatDataSource());
  final localSource = ref.watch(localChatDataSourceProvider);
  final localRepo = ChatRepositoryImpl(localSource);

  if (AppConfig.useMockData) {
    return mockRepo;
  } else if (AppConfig.useHybridFallback) {
    return FallbackChatRepository(local: localRepo, mock: mockRepo);
  } else {
    // Local-First: On-device encrypted storage is primary source of truth
    return localRepo;
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

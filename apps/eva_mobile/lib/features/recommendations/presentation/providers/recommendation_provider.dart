import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';
import '../../domain/repositories/recommendation_repository.dart';
import '../../domain/entities/recommendation_entity.dart';
import '../../data/datasources/mock_recommendation_datasource.dart';
import '../../data/datasources/remote_recommendation_datasource.dart';
import '../../data/repositories/recommendation_repository_impl.dart';
import '../../data/repositories/fallback_recommendation_repository.dart';

final recommendationRepositoryProvider = Provider<RecommendationRepository>((ref) {
  final mockRepo = RecommendationRepositoryImpl(MockRecommendationDataSource());
  final remoteRepo = RecommendationRepositoryImpl(RemoteRecommendationDataSource());

  if (AppConfig.useMockData) {
    return mockRepo;
  } else if (AppConfig.useHybridFallback) {
    return FallbackRecommendationRepository(remote: remoteRepo, mock: mockRepo);
  } else {
    return remoteRepo;
  }
});

final recommendationsProvider = FutureProvider<List<RecommendationEntity>>((ref) async {
  final repo = ref.watch(recommendationRepositoryProvider);
  return repo.getRecommendations();
});

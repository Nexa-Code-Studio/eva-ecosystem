import '../../domain/repositories/recommendation_repository.dart';
import '../../domain/entities/recommendation_entity.dart';
import '../../../../core/network/fallback_policy.dart';

class FallbackRecommendationRepository implements RecommendationRepository {
  final RecommendationRepository _remote;
  final RecommendationRepository _mock;

  FallbackRecommendationRepository({
    required RecommendationRepository remote,
    required RecommendationRepository mock,
  })  : _remote = remote,
        _mock = mock;

  @override
  Future<List<RecommendationEntity>> getRecommendations() {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.getRecommendations(),
      mockCall: () => _mock.getRecommendations(),
      operationName: 'getRecommendations',
    );
  }

  @override
  Future<Map<String, dynamic>> getTodayRecommendation() {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.getTodayRecommendation(),
      mockCall: () => _mock.getTodayRecommendation(),
      operationName: 'getTodayRecommendation',
    );
  }

  @override
  Future<void> markAsCompleted(String id) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.markAsCompleted(id),
      mockCall: () => _mock.markAsCompleted(id),
      operationName: 'markAsCompleted($id)',
    );
  }
}

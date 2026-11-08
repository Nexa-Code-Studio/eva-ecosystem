import '../entities/recommendation_entity.dart';

abstract class RecommendationRepository {
  Future<List<RecommendationEntity>> getRecommendations();
  Future<Map<String, dynamic>> getTodayRecommendation();
  Future<void> markAsCompleted(String id);
}

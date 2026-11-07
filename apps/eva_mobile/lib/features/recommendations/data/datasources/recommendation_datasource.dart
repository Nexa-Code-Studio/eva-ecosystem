import '../models/recommendation_model.dart';

abstract class RecommendationDataSource {
  Future<List<RecommendationModel>> getRecommendations();
  Future<Map<String, dynamic>> getTodayRecommendation();
  Future<void> markAsCompleted(String id);
}

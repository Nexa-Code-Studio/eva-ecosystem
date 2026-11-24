import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/counselor_level_metrics_entity.dart';
import '../../domain/entities/counselor_review_entity.dart';

abstract class ICounselorProfileDataSource {
  Future<CounselorLevelMetricsEntity> fetchLevelMetrics();
  Future<CounselorReviewsListEntity> fetchReviews({String? counselorId});
  Future<CounselorLevelMetricsEntity> updateCustomPrice(double customPrice);
}

class CounselorProfileRemoteDataSource implements ICounselorProfileDataSource {
  final ApiClient _apiClient;

  CounselorProfileRemoteDataSource({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  @override
  Future<CounselorLevelMetricsEntity> fetchLevelMetrics() async {
    final response = await _apiClient.get(ApiEndpoints.levelMetrics);
    return CounselorLevelMetricsEntity.fromJson(
        response as Map<String, dynamic>);
  }

  @override
  Future<CounselorReviewsListEntity> fetchReviews({String? counselorId}) async {
    final endpoint = counselorId != null && counselorId.isNotEmpty
        ? ApiEndpoints.counselorReviews(counselorId)
        : ApiEndpoints.myReviews;
    final response = await _apiClient.get(endpoint);
    return CounselorReviewsListEntity.fromResponse(
      response,
      counselorId: counselorId ?? '',
    );
  }

  @override
  Future<CounselorLevelMetricsEntity> updateCustomPrice(double customPrice) async {
    final response = await _apiClient.patch(
      ApiEndpoints.updatePricing,
      body: {'custom_price_per_session': customPrice},
    );
    return CounselorLevelMetricsEntity.fromJson(
        response as Map<String, dynamic>);
  }
}

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../domain/entities/counselor_level_metrics_entity.dart';
import '../../domain/entities/counselor_review_entity.dart';
import '../../domain/entities/counselor_schedule_config_entity.dart';

abstract class ICounselorProfileDataSource {
  Future<CounselorLevelMetricsEntity> fetchLevelMetrics();
  Future<CounselorReviewsListEntity> fetchReviews({String? counselorId});
  Future<CounselorLevelMetricsEntity> updateCustomPrice(double customPrice);
  Future<CounselorScheduleConfigEntity> fetchScheduleConfig();
  Future<CounselorScheduleConfigEntity> updateScheduleConfig({
    required Map<String, dynamic> scheduleConfig,
    required int bufferTimeMinutes,
  });
  Future<CounselorDailyTimelineEntity> fetchMyDailyTimeline(DateTime date);
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

  @override
  Future<CounselorScheduleConfigEntity> fetchScheduleConfig() async {
    final response = await _apiClient.get(ApiEndpoints.scheduleConfig);
    return CounselorScheduleConfigEntity.fromJson(
      response as Map<String, dynamic>,
    );
  }

  @override
  Future<CounselorScheduleConfigEntity> updateScheduleConfig({
    required Map<String, dynamic> scheduleConfig,
    required int bufferTimeMinutes,
  }) async {
    final response = await _apiClient.put(
      ApiEndpoints.scheduleConfig,
      body: {
        'schedule_config': scheduleConfig,
        'buffer_time_minutes': bufferTimeMinutes,
      },
    );
    return CounselorScheduleConfigEntity.fromJson(
      response as Map<String, dynamic>,
    );
  }

  @override
  Future<CounselorDailyTimelineEntity> fetchMyDailyTimeline(DateTime date) async {
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final tzOffset = date.timeZoneOffset.inMinutes;
    final response = await _apiClient.get(
      ApiEndpoints.myTimeline(dateStr, tzOffsetMinutes: tzOffset),
    );
    return CounselorDailyTimelineEntity.fromJson(
      response as Map<String, dynamic>,
    );
  }
}

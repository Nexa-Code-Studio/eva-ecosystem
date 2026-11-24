import '../../domain/entities/counselor_level_metrics_entity.dart';
import '../../domain/entities/counselor_review_entity.dart';
import '../datasources/counselor_profile_remote_data_source.dart';

class CounselorProfileRepository {
  final ICounselorProfileDataSource _dataSource;

  CounselorProfileRepository({ICounselorProfileDataSource? dataSource})
      : _dataSource = dataSource ?? CounselorProfileRemoteDataSource();

  Future<CounselorLevelMetricsEntity> getLevelMetrics() {
    return _dataSource.fetchLevelMetrics();
  }

  Future<CounselorReviewsListEntity> getReviews({String? counselorId}) {
    return _dataSource.fetchReviews(counselorId: counselorId);
  }

  Future<CounselorLevelMetricsEntity> updatePricing(double customPrice) {
    return _dataSource.updateCustomPrice(customPrice);
  }
}

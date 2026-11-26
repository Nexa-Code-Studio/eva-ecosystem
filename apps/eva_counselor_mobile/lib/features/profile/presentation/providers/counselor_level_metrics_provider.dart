import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';
import '../../data/datasources/counselor_profile_mock_data_source.dart';
import '../../data/datasources/counselor_profile_remote_data_source.dart';
import '../../data/repositories/counselor_profile_repository.dart';
import '../../domain/entities/counselor_level_metrics_entity.dart';
import '../../domain/entities/counselor_review_entity.dart';
import '../../domain/entities/counselor_schedule_config_entity.dart';

final _sharedMockCounselorProfileDataSource = CounselorProfileMockDataSource();

final counselorProfileDataSourceProvider =
    Provider<ICounselorProfileDataSource>((ref) {
  if (AppConfig.useMockData) {
    return _sharedMockCounselorProfileDataSource;
  }
  return CounselorProfileRemoteDataSource();
});

final counselorProfileRepositoryProvider =
    Provider<CounselorProfileRepository>((ref) {
  final dataSource = ref.watch(counselorProfileDataSourceProvider);
  return CounselorProfileRepository(dataSource: dataSource);
});

class CounselorLevelMetricsNotifier
    extends AsyncNotifier<CounselorLevelMetricsEntity?> {
  @override
  Future<CounselorLevelMetricsEntity?> build() async {
    final repo = ref.read(counselorProfileRepositoryProvider);
    try {
      return await repo.getLevelMetrics();
    } catch (e) {
      // If server error or unauthenticated, return null and let UI show retry or fallback
      return null;
    }
  }

  Future<void> refreshMetrics() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(counselorProfileRepositoryProvider);
      return await repo.getLevelMetrics();
    });
  }

  Future<CounselorLevelMetricsEntity> updateCustomPrice(double newPrice) async {
    final repo = ref.read(counselorProfileRepositoryProvider);
    final updated = await repo.updatePricing(newPrice);
    state = AsyncValue.data(updated);
    return updated;
  }
}

final counselorLevelMetricsProvider = AsyncNotifierProvider<
    CounselorLevelMetricsNotifier, CounselorLevelMetricsEntity?>(
  CounselorLevelMetricsNotifier.new,
);

final counselorReviewsProvider = FutureProvider.autoDispose
    .family<CounselorReviewsListEntity, String?>((ref, counselorId) async {
  final repo = ref.watch(counselorProfileRepositoryProvider);
  return await repo.getReviews(counselorId: counselorId);
});

final counselorScheduleConfigProvider =
    FutureProvider.autoDispose<CounselorScheduleConfigEntity>((ref) async {
  final repo = ref.watch(counselorProfileRepositoryProvider);
  return await repo.getScheduleConfig();
});

final counselorDailyTimelineProvider = FutureProvider.autoDispose
    .family<CounselorDailyTimelineEntity, String>((ref, dateIso) async {
  final repo = ref.watch(counselorProfileRepositoryProvider);
  final parsedDate = DateTime.tryParse(dateIso) ?? DateTime.now();
  return await repo.getMyDailyTimeline(parsedDate);
});

import '../../domain/entities/counselor_level_metrics_entity.dart';
import '../../domain/entities/counselor_review_entity.dart';
import '../../domain/entities/counselor_schedule_config_entity.dart';
import 'counselor_profile_remote_data_source.dart';

class CounselorProfileMockDataSource implements ICounselorProfileDataSource {
  Map<String, dynamic> _scheduleConfig = {
    'monday': {
      'is_active': true,
      'operating_hours': {'start': '08:00', 'end': '17:00'},
      'breaks': [
        {'start': '12:00', 'end': '13:00', 'label': 'Istirahat Siang'},
      ],
    },
    'tuesday': {
      'is_active': true,
      'operating_hours': {'start': '08:00', 'end': '17:00'},
      'breaks': [
        {'start': '12:00', 'end': '13:00', 'label': 'Istirahat Siang'},
      ],
    },
    'wednesday': {
      'is_active': true,
      'operating_hours': {'start': '08:00', 'end': '17:00'},
      'breaks': [
        {'start': '12:00', 'end': '13:00', 'label': 'Istirahat Siang'},
      ],
    },
    'thursday': {
      'is_active': true,
      'operating_hours': {'start': '08:00', 'end': '17:00'},
      'breaks': [
        {'start': '12:00', 'end': '13:00', 'label': 'Istirahat Siang'},
      ],
    },
    'friday': {
      'is_active': true,
      'operating_hours': {'start': '08:00', 'end': '17:00'},
      'breaks': [
        {'start': '11:30', 'end': '13:00', 'label': 'Shalat Jumat & Istirahat'},
        {'start': '15:30', 'end': '16:00', 'label': 'Istirahat Sore'},
      ],
    },
    'saturday': {
      'is_active': false,
      'operating_hours': {'start': '09:00', 'end': '14:00'},
      'breaks': <Map<String, dynamic>>[],
    },
    'sunday': {
      'is_active': false,
      'operating_hours': {'start': '09:00', 'end': '14:00'},
      'breaks': <Map<String, dynamic>>[],
    },
  };
  int _bufferTimeMinutes = 10;

  @override
  Future<CounselorLevelMetricsEntity> fetchLevelMetrics() async {
    return const CounselorLevelMetricsEntity(
      counselorId: 'mock-counselor-1',
      levelTier: 2,
      levelName: 'Registered Counselor',
      badgeIcon: 'shield-check',
      totalCompletedSessions: 14,
      totalConsultationHours: 7.0,
      averageRating: 4.85,
      ratingCount: 12,
      activeSessionPrice: 150,
      platformFeePercentage: 20,
      allowCustomPrice: false,
    );
  }

  @override
  Future<CounselorReviewsListEntity> fetchReviews({String? counselorId}) async {
    return CounselorReviewsListEntity(
      counselorId: counselorId ?? 'mock-counselor-1',
      items: const [],
      total: 0,
      averageRating: 4.85,
    );
  }

  @override
  Future<CounselorLevelMetricsEntity> updateCustomPrice(double customPrice) async {
    return fetchLevelMetrics();
  }

  @override
  Future<CounselorScheduleConfigEntity> fetchScheduleConfig() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return CounselorScheduleConfigEntity.fromJson({
      'counselor_id': 'mock-counselor-1',
      'buffer_time_minutes': _bufferTimeMinutes,
      'schedule_config': _scheduleConfig,
    });
  }

  @override
  Future<CounselorScheduleConfigEntity> updateScheduleConfig({
    required Map<String, dynamic> scheduleConfig,
    required int bufferTimeMinutes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    _scheduleConfig = Map<String, dynamic>.from(scheduleConfig);
    _bufferTimeMinutes = bufferTimeMinutes;
    return fetchScheduleConfig();
  }

  @override
  Future<CounselorDailyTimelineEntity> fetchMyDailyTimeline(DateTime date) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final key = weekdayKeyFromDate(date);
    final dayRaw = _scheduleConfig[key] as Map<String, dynamic>? ?? const {};
    final dayCfg = CounselorDayScheduleEntity.fromJson(dayRaw);
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final blocked = dayCfg.isActive
        ? dayCfg.breaks
            .map(
              (b) => CounselorBlockedRangeEntity(
                start: b.start,
                end: b.end,
                type: 'break',
                label: b.label,
              ),
            )
            .toList()
        : const <CounselorBlockedRangeEntity>[];

    return CounselorDailyTimelineEntity(
      counselorId: 'mock-counselor-1',
      date: dateStr,
      isActive: dayCfg.isActive,
      isOnline: true,
      operatingStart: dayCfg.startTime,
      operatingEnd: dayCfg.endTime,
      bufferTimeMinutes: _bufferTimeMinutes,
      blockedRanges: blocked,
      bookedSessions: const [],
    );
  }
}

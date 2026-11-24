import 'package:flutter/foundation.dart';

@immutable
class NextLevelTargetEntity {
  final int levelTier;
  final String levelName;
  final String badgeIcon;
  final int targetSessions;
  final double targetRating;
  final double targetHours;
  final int sessionsRemaining;
  final double hoursRemaining;
  final bool ratingAchieved;

  const NextLevelTargetEntity({
    required this.levelTier,
    required this.levelName,
    required this.badgeIcon,
    required this.targetSessions,
    required this.targetRating,
    required this.targetHours,
    required this.sessionsRemaining,
    required this.hoursRemaining,
    required this.ratingAchieved,
  });

  factory NextLevelTargetEntity.fromJson(Map<String, dynamic> json) {
    return NextLevelTargetEntity(
      levelTier: json['level_tier'] as int? ?? 1,
      levelName: json['name'] as String? ?? json['level_name'] as String? ?? 'Level Berikutnya',
      badgeIcon: json['badge_icon'] as String? ?? 'verified',
      targetSessions: json['min_completed_sessions'] as int? ?? json['target_sessions'] as int? ?? 0,
      targetRating: (json['min_average_rating'] as num?)?.toDouble() ?? (json['target_rating'] as num?)?.toDouble() ?? 0.0,
      targetHours: (json['min_consultation_hours'] as num?)?.toDouble() ?? (json['target_hours'] as num?)?.toDouble() ?? 0.0,
      sessionsRemaining: json['sessions_remaining'] as int? ?? 0,
      hoursRemaining: (json['hours_remaining'] as num?)?.toDouble() ?? 0.0,
      ratingAchieved: json['rating_achieved'] as bool? ?? false,
    );
  }
}

@immutable
class CounselorLevelMetricsEntity {
  final String counselorId;
  final int levelTier;
  final String levelName;
  final String badgeIcon;
  final int totalCompletedSessions;
  final double totalConsultationHours;
  final double averageRating;
  final int ratingCount;
  final double activeSessionPrice;
  final double platformFeePercentage;
  final bool allowCustomPrice;
  final double? customPricePerSession;
  final double? minCustomPrice;
  final double? maxCustomPrice;
  final NextLevelTargetEntity? nextLevel;

  const CounselorLevelMetricsEntity({
    required this.counselorId,
    required this.levelTier,
    required this.levelName,
    required this.badgeIcon,
    required this.totalCompletedSessions,
    required this.totalConsultationHours,
    required this.averageRating,
    required this.ratingCount,
    required this.activeSessionPrice,
    required this.platformFeePercentage,
    required this.allowCustomPrice,
    this.customPricePerSession,
    this.minCustomPrice,
    this.maxCustomPrice,
    this.nextLevel,
  });

  double get platformFeeAmount => activeSessionPrice * (platformFeePercentage / 100.0);

  double get netCounselorEarning => activeSessionPrice - platformFeeAmount;

  /// Progress fraction towards the next tier level (0.0 to 1.0)
  double get progressFraction {
    if (nextLevel == null) return 1.0;
    if (nextLevel!.targetSessions <= 0) return 1.0;
    final ratio = totalCompletedSessions / nextLevel!.targetSessions;
    return ratio.clamp(0.0, 1.0);
  }

  factory CounselorLevelMetricsEntity.fromJson(Map<String, dynamic> json) {
    final currentLevel = json['current_level'] as Map<String, dynamic>?;
    final nextLevelRaw = json['next_level'] as Map<String, dynamic>?;
    final nextProgressRaw = json['next_level_progress'] as Map<String, dynamic>?;

    NextLevelTargetEntity? nextTarget;
    if (nextLevelRaw != null) {
      final targetSessions = (nextProgressRaw?['min_completed_sessions'] as int?) ??
          (nextLevelRaw['min_completed_sessions'] as int?) ??
          (nextLevelRaw['target_sessions'] as int?) ??
          0;
      final completedSessions = (nextProgressRaw?['completed_sessions'] as int?) ??
          (json['total_completed_sessions'] as int?) ??
          0;
      final targetHours = (nextProgressRaw?['min_consultation_hours'] as num?)?.toDouble() ??
          (nextLevelRaw['min_consultation_hours'] as num?)?.toDouble() ??
          (nextLevelRaw['target_hours'] as num?)?.toDouble() ??
          0.0;
      final completedHours = (nextProgressRaw?['consultation_hours'] as num?)?.toDouble() ??
          (json['total_consultation_hours'] as num?)?.toDouble() ??
          0.0;
      final targetRating = (nextProgressRaw?['min_average_rating'] as num?)?.toDouble() ??
          (nextLevelRaw['min_average_rating'] as num?)?.toDouble() ??
          (nextLevelRaw['target_rating'] as num?)?.toDouble() ??
          0.0;
      final avgRating = (json['average_rating'] as num?)?.toDouble() ?? 5.0;

      final sessionsRemaining = (targetSessions - completedSessions).clamp(0, 999999);
      final hoursRemaining = (targetHours - completedHours).clamp(0.0, 999999.0);
      final ratingAchieved = avgRating >= targetRating;

      nextTarget = NextLevelTargetEntity(
        levelTier: nextLevelRaw['level_tier'] as int? ?? 2,
        levelName: nextLevelRaw['name'] as String? ?? nextLevelRaw['level_name'] as String? ?? 'Level Berikutnya',
        badgeIcon: nextLevelRaw['badge_icon'] as String? ?? 'verified',
        targetSessions: targetSessions,
        targetRating: targetRating,
        targetHours: targetHours,
        sessionsRemaining: nextLevelRaw['sessions_remaining'] as int? ?? sessionsRemaining,
        hoursRemaining: (nextLevelRaw['hours_remaining'] as num?)?.toDouble() ?? hoursRemaining,
        ratingAchieved: nextLevelRaw['rating_achieved'] as bool? ?? ratingAchieved,
      );
    } else if (json['next_level_target'] != null) {
      nextTarget = NextLevelTargetEntity.fromJson(json['next_level_target'] as Map<String, dynamic>);
    }

    return CounselorLevelMetricsEntity(
      counselorId: json['counselor_id'] as String? ?? '',
      levelTier: (currentLevel?['level_tier'] as int?) ?? json['level_tier'] as int? ?? 1,
      levelName: (currentLevel?['name'] as String?) ?? json['level_name'] as String? ?? 'Praktisi',
      badgeIcon: (currentLevel?['badge_icon'] as String?) ?? json['badge_icon'] as String? ?? 'verified',
      totalCompletedSessions: json['total_completed_sessions'] as int? ?? 0,
      totalConsultationHours: (json['total_consultation_hours'] as num?)?.toDouble() ?? 0.0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 5.0,
      ratingCount: json['rating_count'] as int? ?? 0,
      activeSessionPrice: (json['active_session_price'] as num?)?.toDouble() ??
          (json['effective_session_price'] as num?)?.toDouble() ??
          (currentLevel?['default_session_price'] as num?)?.toDouble() ??
          50000.0,
      platformFeePercentage: (json['platform_fee_percentage'] as num?)?.toDouble() ??
          (currentLevel?['platform_fee_percentage'] as num?)?.toDouble() ??
          20.0,
      allowCustomPrice: (currentLevel?['allow_custom_price'] as bool?) ?? json['allow_custom_price'] as bool? ?? false,
      customPricePerSession: (json['custom_price_per_session'] as num?)?.toDouble(),
      minCustomPrice: (currentLevel?['min_custom_price'] as num?)?.toDouble() ?? (json['min_custom_price'] as num?)?.toDouble(),
      maxCustomPrice: (currentLevel?['max_custom_price'] as num?)?.toDouble() ?? (json['max_custom_price'] as num?)?.toDouble(),
      nextLevel: nextTarget,
    );
  }

  CounselorLevelMetricsEntity copyWith({
    String? counselorId,
    int? levelTier,
    String? levelName,
    String? badgeIcon,
    int? totalCompletedSessions,
    double? totalConsultationHours,
    double? averageRating,
    int? ratingCount,
    double? activeSessionPrice,
    double? platformFeePercentage,
    bool? allowCustomPrice,
    double? customPricePerSession,
    double? minCustomPrice,
    double? maxCustomPrice,
    NextLevelTargetEntity? nextLevel,
  }) {
    return CounselorLevelMetricsEntity(
      counselorId: counselorId ?? this.counselorId,
      levelTier: levelTier ?? this.levelTier,
      levelName: levelName ?? this.levelName,
      badgeIcon: badgeIcon ?? this.badgeIcon,
      totalCompletedSessions: totalCompletedSessions ?? this.totalCompletedSessions,
      totalConsultationHours: totalConsultationHours ?? this.totalConsultationHours,
      averageRating: averageRating ?? this.averageRating,
      ratingCount: ratingCount ?? this.ratingCount,
      activeSessionPrice: activeSessionPrice ?? this.activeSessionPrice,
      platformFeePercentage: platformFeePercentage ?? this.platformFeePercentage,
      allowCustomPrice: allowCustomPrice ?? this.allowCustomPrice,
      customPricePerSession: customPricePerSession ?? this.customPricePerSession,
      minCustomPrice: minCustomPrice ?? this.minCustomPrice,
      maxCustomPrice: maxCustomPrice ?? this.maxCustomPrice,
      nextLevel: nextLevel ?? this.nextLevel,
    );
  }
}

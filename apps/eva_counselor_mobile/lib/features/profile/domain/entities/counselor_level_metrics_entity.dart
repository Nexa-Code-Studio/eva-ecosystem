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
      levelName: json['level_name'] as String? ?? 'Level Berikutnya',
      badgeIcon: json['badge_icon'] as String? ?? 'verified',
      targetSessions: json['target_sessions'] as int? ?? 0,
      targetRating: (json['target_rating'] as num?)?.toDouble() ?? 0.0,
      targetHours: (json['target_hours'] as num?)?.toDouble() ?? 0.0,
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
    return CounselorLevelMetricsEntity(
      counselorId: json['counselor_id'] as String? ?? '',
      levelTier: json['level_tier'] as int? ?? 1,
      levelName: json['level_name'] as String? ?? 'Praktisi',
      badgeIcon: json['badge_icon'] as String? ?? 'verified',
      totalCompletedSessions: json['total_completed_sessions'] as int? ?? 0,
      totalConsultationHours: (json['total_consultation_hours'] as num?)?.toDouble() ?? 0.0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 5.0,
      ratingCount: json['rating_count'] as int? ?? 0,
      activeSessionPrice: (json['active_session_price'] as num?)?.toDouble() ?? 50000.0,
      platformFeePercentage: (json['platform_fee_percentage'] as num?)?.toDouble() ?? 20.0,
      allowCustomPrice: json['allow_custom_price'] as bool? ?? false,
      customPricePerSession: (json['custom_price_per_session'] as num?)?.toDouble(),
      minCustomPrice: (json['min_custom_price'] as num?)?.toDouble(),
      maxCustomPrice: (json['max_custom_price'] as num?)?.toDouble(),
      nextLevel: json['next_level'] != null
          ? NextLevelTargetEntity.fromJson(json['next_level'] as Map<String, dynamic>)
          : null,
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

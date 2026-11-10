import 'package:flutter/foundation.dart';
import 'psychologist_entity.dart';

/// Domain entity representing a patient's rating & qualitative review for a psychologist or volunteer.
/// Structured with Star rating, Baik/Tidak (sentiment), Label, and Deskripsi.
@immutable
class PsychologistRatingReview {
  final String psychologistId;
  final double rating; // Star rating (1.0 to 5.0)
  final bool isPositive; // Baik (true) vs Kurang Baik (false)
  final String label; // Short highlight tag/label (e.g., 'Sangat Sabar & Empati')
  final String description; // Full qualitative description
  final List<String> tags; // Optional extra tags
  final DateTime createdAt;
  final bool isAnonymous;

  const PsychologistRatingReview({
    required this.psychologistId,
    required this.rating,
    this.isPositive = true,
    required this.label,
    required this.description,
    this.tags = const [],
    required this.createdAt,
    this.isAnonymous = true,
  });

  ReviewSentiment get sentiment =>
      isPositive ? ReviewSentiment.positive : ReviewSentiment.negative;

  /// Compatibility getter for legacy callers
  String get reviewText => description;

  PatientReviewItem toPatientReviewItem({String? patientName}) {
    return PatientReviewItem(
      id: 'rev_user_$psychologistId',
      patientName: patientName ??
          (isAnonymous ? 'Pasien Terverifikasi (Anonim)' : 'Pasien Terverifikasi'),
      sentiment: sentiment,
      label: label,
      description: description,
      rating: rating,
      timeAgo: 'Baru saja',
      date: createdAt,
    );
  }

  PsychologistRatingReview copyWith({
    String? psychologistId,
    double? rating,
    bool? isPositive,
    String? label,
    String? description,
    List<String>? tags,
    DateTime? createdAt,
    bool? isAnonymous,
  }) {
    return PsychologistRatingReview(
      psychologistId: psychologistId ?? this.psychologistId,
      rating: rating ?? this.rating,
      isPositive: isPositive ?? this.isPositive,
      label: label ?? this.label,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      isAnonymous: isAnonymous ?? this.isAnonymous,
    );
  }

  Map<String, dynamic> toJson() => {
    'psychologist_id': psychologistId,
    'rating': rating,
    'is_positive': isPositive,
    'label': label,
    'description': description,
    'tags': tags,
    'created_at': createdAt.toIso8601String(),
    'is_anonymous': isAnonymous,
  };

  factory PsychologistRatingReview.fromJson(Map<String, dynamic> json) {
    return PsychologistRatingReview(
      psychologistId: json['psychologist_id'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      isPositive: json['is_positive'] as bool? ??
          (((json['rating'] as num?)?.toDouble() ?? 5.0) >= 4.0),
      label: json['label'] as String? ?? '',
      description: json['description'] as String? ?? json['review_text'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      isAnonymous: json['is_anonymous'] as bool? ?? true,
    );
  }
}

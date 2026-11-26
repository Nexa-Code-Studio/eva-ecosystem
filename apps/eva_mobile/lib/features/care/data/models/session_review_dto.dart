import '../../domain/entities/psychologist_entity.dart';
import '../../domain/entities/psychologist_rating_review.dart';

class SessionReviewDto {
  final String id;
  final String sessionId;
  final String counselorId;
  final String patientDisplayName;
  final double rating;
  final String highlightLabel;
  final String reviewText;
  final bool isAnonymous;
  final DateTime createdAt;

  const SessionReviewDto({
    required this.id,
    required this.sessionId,
    required this.counselorId,
    required this.patientDisplayName,
    required this.rating,
    required this.highlightLabel,
    required this.reviewText,
    required this.isAnonymous,
    required this.createdAt,
  });

  factory SessionReviewDto.fromJson(
    Map<String, dynamic> json, {
    String? fallbackCounselorId,
  }) {
    final rawCreated = json['created_at']?.toString();
    return SessionReviewDto(
      id: json['id']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      counselorId: json['counselor_id']?.toString() ?? fallbackCounselorId ?? '',
      patientDisplayName: json['patient_display_name']?.toString() ??
          json['patient_name']?.toString() ??
          ((json['is_anonymous'] as bool? ?? false)
              ? 'Pasien Anonim'
              : 'Pasien EVA'),
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      highlightLabel: (json['highlight_label'] as String?) ??
          (json['label'] as String?) ??
          '',
      reviewText: (json['review_text'] as String?) ??
          (json['description'] as String?) ??
          '',
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      createdAt: rawCreated != null
          ? DateTime.tryParse(rawCreated)?.toLocal() ?? DateTime.now()
          : DateTime.now(),
    );
  }

  PatientReviewItem toPatientReviewItem() {
    final isPositive = rating >= 4.0;
    return PatientReviewItem(
      id: id,
      patientName: patientDisplayName,
      sentiment: isPositive ? ReviewSentiment.positive : ReviewSentiment.negative,
      label: highlightLabel,
      description: reviewText,
      rating: rating,
      timeAgo: '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}',
      date: createdAt,
    );
  }

  PsychologistRatingReview toRatingReview({String? overrideCounselorId}) {
    final resolvedLabel = highlightLabel.isNotEmpty ? highlightLabel : 'Ulasan Sesi';
    return PsychologistRatingReview(
      psychologistId: counselorId.isNotEmpty ? counselorId : (overrideCounselorId ?? ''),
      rating: rating,
      isPositive: rating >= 4.0,
      label: resolvedLabel,
      description: reviewText,
      tags: highlightLabel.isNotEmpty ? [highlightLabel] : const [],
      createdAt: createdAt,
      isAnonymous: isAnonymous,
    );
  }
}

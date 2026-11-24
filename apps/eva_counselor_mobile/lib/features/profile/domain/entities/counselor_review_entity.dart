import 'package:flutter/foundation.dart';

@immutable
class CounselorReviewEntity {
  final String id;
  final String sessionId;
  final String patientName;
  final double rating;
  final String? label;
  final String? reviewText;
  final bool isAnonymous;
  final DateTime createdAt;

  const CounselorReviewEntity({
    required this.id,
    required this.sessionId,
    required this.patientName,
    required this.rating,
    this.label,
    this.reviewText,
    this.isAnonymous = true,
    required this.createdAt,
  });

  factory CounselorReviewEntity.fromJson(Map<String, dynamic> json) {
    return CounselorReviewEntity(
      id: json['id'] as String? ?? '',
      sessionId: json['session_id'] as String? ?? '',
      patientName: json['patient_display_name'] as String? ?? json['patient_name'] as String? ?? 'Pasien Terverifikasi',
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      label: json['highlight_label'] as String? ?? json['label'] as String?,
      reviewText: json['review_text'] as String?,
      isAnonymous: json['is_anonymous'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

@immutable
class CounselorReviewsListEntity {
  final String counselorId;
  final List<CounselorReviewEntity> items;
  final int total;
  final double averageRating;

  const CounselorReviewsListEntity({
    required this.counselorId,
    required this.items,
    required this.total,
    required this.averageRating,
  });

  factory CounselorReviewsListEntity.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return CounselorReviewsListEntity(
      counselorId: json['counselor_id'] as String? ?? '',
      items: rawItems
          .map((e) => CounselorReviewEntity.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? rawItems.length,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 5.0,
    );
  }

  factory CounselorReviewsListEntity.fromResponse(dynamic data, {String counselorId = ''}) {
    if (data is List) {
      final items = data
          .map((e) => CounselorReviewEntity.fromJson(e as Map<String, dynamic>))
          .toList();
      final total = items.length;
      final avg = total > 0
          ? items.map((e) => e.rating).reduce((a, b) => a + b) / total
          : 5.0;
      return CounselorReviewsListEntity(
        counselorId: counselorId,
        items: items,
        total: total,
        averageRating: avg,
      );
    } else if (data is Map<String, dynamic>) {
      return CounselorReviewsListEntity.fromJson(data);
    }
    return CounselorReviewsListEntity(
      counselorId: counselorId,
      items: const [],
      total: 0,
      averageRating: 5.0,
    );
  }
}

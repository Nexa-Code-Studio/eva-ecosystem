import '../../domain/entities/psychologist_entity.dart';

class PsychologistModel extends PsychologistEntity {
  const PsychologistModel({
    required super.id,
    required super.name,
    required super.title,
    required super.registrationNumber,
    required super.avatarUrl,
    required super.rating,
    required super.reviewCount,
    required super.experienceYears,
    required super.specialties,
    required super.feePerSession,
    super.durationMinutes = 50,
    super.availableOnline = true,
    super.clinicAffiliation,
    required super.bio,
  });

  factory PsychologistModel.fromJson(Map<String, dynamic> json) {
    return PsychologistModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      registrationNumber: json['registration_number'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      experienceYears: (json['experience_years'] as num?)?.toInt() ?? 1,
      specialties: (json['specialties'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      feePerSession: (json['fee_per_session'] as num?)?.toInt() ?? 100000,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 50,
      availableOnline: json['available_online'] as bool? ?? true,
      clinicAffiliation: json['clinic_affiliation'] as String?,
      bio: json['bio'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'title': title,
      'registration_number': registrationNumber,
      'avatar_url': avatarUrl,
      'rating': rating,
      'review_count': reviewCount,
      'experience_years': experienceYears,
      'specialties': specialties,
      'fee_per_session': feePerSession,
      'duration_minutes': durationMinutes,
      'available_online': availableOnline,
      'clinic_affiliation': clinicAffiliation,
      'bio': bio,
    };
  }
}

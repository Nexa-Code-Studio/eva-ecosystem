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
    super.patientReviewTags = const [],
    super.patientReviews = const [],
    super.reviewTags = const [],
    super.testimonials = const [],
    super.patientStats = const PatientStatsEntity(),
    super.certifications = const [],
    super.certificateItems = const [],
    super.coinsPerSession = 50,
    super.durationMinutes = 50,
    super.availableOnline = true,
    super.clinicAffiliation,
    required super.bio,
    super.practitionerType = PractitionerType.professional,
    super.hasPsychologistCertificate = true,
    super.isVolunteerRole = false,
  });

  factory PsychologistModel.fromJson(Map<String, dynamic> json) {
    PractitionerType parseType(String? typeStr) {
      if (typeStr == 'volunteer') return PractitionerType.volunteer;
      if (typeStr == 'freelance') return PractitionerType.freelance;
      return PractitionerType.professional;
    }

    final parsedType = parseType(json['practitioner_type'] as String?);
    final hasCert = json['has_psychologist_certificate'] as bool? ??
        (parsedType != PractitionerType.volunteer);
    final isVol = json['is_volunteer'] as bool? ??
        (parsedType == PractitionerType.volunteer);

    final rawReviewTags = json['review_tags'];
    List<PatientReviewTag> parsedReviewTags = [];
    if (rawReviewTags is List) {
      parsedReviewTags = rawReviewTags
          .map((e) => e is Map<String, dynamic>
              ? PatientReviewTag.fromJson(e)
              : PatientReviewTag(label: e.toString(), sentiment: ReviewSentiment.positive))
          .toList();
    } else if (json['patient_review_tags'] is List) {
      parsedReviewTags = (json['patient_review_tags'] as List<dynamic>)
          .map((e) => PatientReviewTag(label: e.toString(), sentiment: ReviewSentiment.positive))
          .toList();
    }

    final rawTestimonials = json['testimonials'];
    List<PatientReviewItem> parsedTestimonials = [];
    if (rawTestimonials is List) {
      parsedTestimonials = rawTestimonials
          .map((e) => e is Map<String, dynamic>
              ? PatientReviewItem.fromJson(e)
              : PatientReviewItem(
                  id: 'rev_gen',
                  label: 'Konseling Membantu',
                  description: e.toString(),
                ))
          .toList();
    } else if (json['patient_reviews'] is List) {
      parsedTestimonials = (json['patient_reviews'] as List<dynamic>)
          .asMap()
          .entries
          .map((entry) => PatientReviewItem(
                id: 'rev_${entry.key}',
                label: 'Konseling Membantu',
                sentiment: ReviewSentiment.positive,
                description: entry.value.toString(),
              ))
          .toList();
    }

    PatientStatsEntity parsedStats = const PatientStatsEntity();
    if (json['patient_stats'] is Map<String, dynamic>) {
      parsedStats = PatientStatsEntity.fromJson(json['patient_stats'] as Map<String, dynamic>);
    }

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
      patientReviewTags: (json['patient_review_tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          parsedReviewTags.map((e) => e.label).toList(),
      patientReviews: (json['patient_reviews'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          parsedTestimonials.map((e) => e.description).toList(),
      reviewTags: parsedReviewTags,
      testimonials: parsedTestimonials,
      patientStats: parsedStats,
      certifications: (json['certifications'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      certificateItems: (json['certificate_items'] as List<dynamic>?)
              ?.map((e) => CertificateItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      coinsPerSession: (json['coins_per_session'] as num?)?.toInt() ??
          (json['fee_per_session'] as num?)?.toInt() ??
          50,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 50,
      availableOnline: json['available_online'] as bool? ?? true,
      clinicAffiliation: json['clinic_affiliation'] as String?,
      bio: json['bio'] as String? ?? '',
      practitionerType: parsedType,
      hasPsychologistCertificate: hasCert,
      isVolunteerRole: isVol,
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
      'patient_review_tags': patientReviewTags,
      'patient_reviews': patientReviews,
      'review_tags': reviewTags.map((e) => e.toJson()).toList(),
      'testimonials': testimonials.map((e) => e.toJson()).toList(),
      'patient_stats': patientStats.toJson(),
      'certifications': certifications,
      'certificate_items': certificateItems.map((e) => e.toJson()).toList(),
      'coins_per_session': coinsPerSession,
      'fee_per_session': coinsPerSession,
      'duration_minutes': durationMinutes,
      'available_online': availableOnline,
      'clinic_affiliation': clinicAffiliation,
      'bio': bio,
      'practitioner_type': practitionerType.name,
      'has_psychologist_certificate': hasPsychologistCertificate,
      'is_volunteer': isVolunteer,
    };
  }
}

import 'package:flutter/foundation.dart';

enum PractitionerType {
  professional, // Psikolog Profesional Independen
  freelance,    // Psikolog Freelance
  volunteer,    // Volunteer / Relawan Konselor Sebaya
}

enum ReviewSentiment {
  positive,
  negative,
}

@immutable
class PatientReviewTag {
  final String label;
  final ReviewSentiment sentiment;
  final DateTime? createdAt;

  const PatientReviewTag({
    required this.label,
    this.sentiment = ReviewSentiment.positive,
    this.createdAt,
  });

  bool get isPositive => sentiment == ReviewSentiment.positive;
  bool get isNegative => sentiment == ReviewSentiment.negative;

  factory PatientReviewTag.fromJson(Map<String, dynamic> json) {
    return PatientReviewTag(
      label: json['label'] as String? ?? '',
      sentiment: (json['sentiment'] as String?) == 'negative'
          ? ReviewSentiment.negative
          : ReviewSentiment.positive,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'sentiment': sentiment == ReviewSentiment.negative ? 'negative' : 'positive',
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
  };
}

@immutable
class PatientReviewItem {
  final String id;
  final String patientName;
  final ReviewSentiment sentiment;
  final String label; // ulasan singkat / tag label
  final String description; // deskripsi lengkap
  final double rating;
  final String timeAgo;
  final DateTime? date;

  const PatientReviewItem({
    required this.id,
    this.patientName = 'Pasien Terverifikasi (Anonim)',
    this.sentiment = ReviewSentiment.positive,
    required this.label,
    required this.description,
    this.rating = 5.0,
    this.timeAgo = 'Baru saja',
    this.date,
  });

  bool get isPositive => sentiment == ReviewSentiment.positive;
  bool get isNegative => sentiment == ReviewSentiment.negative;

  factory PatientReviewItem.fromJson(Map<String, dynamic> json) {
    return PatientReviewItem(
      id: json['id'] as String? ?? '',
      patientName: json['patient_name'] as String? ?? 'Pasien Terverifikasi (Anonim)',
      sentiment: (json['sentiment'] as String?) == 'negative'
          ? ReviewSentiment.negative
          : ReviewSentiment.positive,
      label: json['label'] as String? ?? '',
      description: json['description'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      timeAgo: json['time_ago'] as String? ?? 'Baru saja',
      date: json['date'] != null ? DateTime.tryParse(json['date'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'patient_name': patientName,
    'sentiment': sentiment == ReviewSentiment.negative ? 'negative' : 'positive',
    'label': label,
    'description': description,
    'rating': rating,
    'time_ago': timeAgo,
    if (date != null) 'date': date!.toIso8601String(),
  };
}

@immutable
class PatientStatsEntity {
  final int totalPatientsTreated;
  final int totalSessionsCompleted;
  final double satisfactionRate; // e.g. 98.4%
  final double positiveReviewRate; // e.g. 96.0%
  final double recoveryRate; // e.g. 93.5%
  final double avgRecoverySessions; // e.g. 3.8 sesi
  final String recoveryDescription;

  const PatientStatsEntity({
    this.totalPatientsTreated = 180,
    this.totalSessionsCompleted = 320,
    this.satisfactionRate = 98.0,
    this.positiveReviewRate = 96.0,
    this.recoveryRate = 93.0,
    this.avgRecoverySessions = 3.6,
    this.recoveryDescription = 'Melaporkan perbaikan emosi & penurunan kecemasan',
  });

  double get negativeReviewRate => (100.0 - positiveReviewRate).clamp(0.0, 100.0);

  factory PatientStatsEntity.fromJson(Map<String, dynamic> json) {
    return PatientStatsEntity(
      totalPatientsTreated: (json['total_patients_treated'] as num?)?.toInt() ?? 180,
      totalSessionsCompleted: (json['total_sessions_completed'] as num?)?.toInt() ?? 320,
      satisfactionRate: (json['satisfaction_rate'] as num?)?.toDouble() ?? 98.0,
      positiveReviewRate: (json['positive_review_rate'] as num?)?.toDouble() ?? 96.0,
      recoveryRate: (json['recovery_rate'] as num?)?.toDouble() ?? 93.0,
      avgRecoverySessions: (json['avg_recovery_sessions'] as num?)?.toDouble() ?? 3.6,
      recoveryDescription: json['recovery_description'] as String? ??
          'Melaporkan perbaikan emosi & penurunan kecemasan',
    );
  }

  Map<String, dynamic> toJson() => {
    'total_patients_treated': totalPatientsTreated,
    'total_sessions_completed': totalSessionsCompleted,
    'satisfaction_rate': satisfactionRate,
    'positive_review_rate': positiveReviewRate,
    'recovery_rate': recoveryRate,
    'avg_recovery_sessions': avgRecoverySessions,
    'recovery_description': recoveryDescription,
  };
}

@immutable
class CertificateItem {
  final String title;
  final String imageUrl;

  const CertificateItem({
    required this.title,
    required this.imageUrl,
  });

  factory CertificateItem.fromJson(Map<String, dynamic> json) {
    return CertificateItem(
      title: json['title'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'image_url': imageUrl,
  };
}

@immutable
class PsychologistEntity {
  final String id;
  final String name;
  final String title;
  final String registrationNumber; // STR or SIPP or Sertifikasi
  final String avatarUrl;
  final double rating;
  final int reviewCount;
  final int experienceYears;
  final List<String> specialties;
  final List<String> patientReviewTags;
  final List<String> patientReviews;
  final List<PatientReviewTag> reviewTags;
  final List<PatientReviewItem> testimonials;
  final PatientStatsEntity patientStats;
  final List<String> certifications;
  final List<CertificateItem> certificateItems;
  final int coinsPerSession; // Coin charge per session (0 = Gratis)
  final int durationMinutes;
  final bool availableOnline;
  final String? clinicAffiliation;
  final String bio;
  final PractitionerType practitionerType;
  final bool hasPsychologistCertificate;
  final bool isVolunteerRole;

  const PsychologistEntity({
    required this.id,
    required this.name,
    required this.title,
    required this.registrationNumber,
    required this.avatarUrl,
    required this.rating,
    required this.reviewCount,
    required this.experienceYears,
    required this.specialties,
    this.patientReviewTags = const [],
    this.patientReviews = const [],
    this.reviewTags = const [],
    this.testimonials = const [],
    this.patientStats = const PatientStatsEntity(),
    this.certifications = const [],
    this.certificateItems = const [],
    this.coinsPerSession = 50,
    this.durationMinutes = 50,
    this.availableOnline = true,
    this.clinicAffiliation,
    required this.bio,
    this.practitionerType = PractitionerType.professional,
    this.hasPsychologistCertificate = true,
    this.isVolunteerRole = false,
  });

  /// Effective certifications falling back to registration credentials if empty
  List<String> get effectiveCertifications {
    if (certifications.isNotEmpty) return certifications;
    final list = <String>[];
    if (hasPsychologistCertificate) {
      list.add('Surat Izin Praktik Psikologi ($registrationNumber)');
      list.add('Magister Profesi Psikologi Klinis (S2)');
      list.add('Sertifikasi Kode Etik Profesi HIMPSI');
    }
    if (isVolunteer) {
      list.add('Sertifikat Psychological First Aid (PFA)');
      list.add('Pelatihan Pendampingan Konseling Sebaya');
    }
    return list;
  }

  /// Effective certificate items with photo URLs and clean titles
  List<CertificateItem> get effectiveCertificateItems {
    if (certificateItems.isNotEmpty) return certificateItems;
    return effectiveCertifications.map((title) {
      final lower = title.toLowerCase();
      String url;
      if (lower.contains('sipp')) {
        url = 'https://images.unsplash.com/photo-1614036417651-efe5912149d8?w=800&auto=format&fit=crop&q=80';
      } else if (lower.contains('magister') || lower.contains('s2')) {
        url = 'https://images.unsplash.com/photo-1659080928170-b9924d616f04?w=800&auto=format&fit=crop&q=80';
      } else if (lower.contains('cbt') || lower.contains('sfbt') || lower.contains('mbsr')) {
        url = 'https://images.unsplash.com/photo-1659080907100-23f0dac0fe27?w=800&auto=format&fit=crop&q=80';
      } else if (lower.contains('pfa') || lower.contains('first aid')) {
        url = 'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?w=800&auto=format&fit=crop&q=80';
      } else if (lower.contains('peer') || lower.contains('sebaya') || lower.contains('safe space')) {
        url = 'https://images.unsplash.com/photo-1450133064473-71024230f91b?w=800&auto=format&fit=crop&q=80';
      } else {
        url = 'https://images.unsplash.com/photo-1523240795612-9a054b0db644?w=800&auto=format&fit=crop&q=80';
      }
      return CertificateItem(title: title, imageUrl: url);
    }).toList();
  }

  /// Effective review tags falling back to patientReviewTags if reviewTags is empty
  List<PatientReviewTag> get effectiveReviewTags {
    if (reviewTags.isNotEmpty) return reviewTags;
    return patientReviewTags
        .map((tag) => PatientReviewTag(label: tag, sentiment: ReviewSentiment.positive))
        .toList();
  }

  /// Effective testimonials falling back to patientReviews if testimonials is empty
  List<PatientReviewItem> get effectiveTestimonials {
    if (testimonials.isNotEmpty) return testimonials;
    return patientReviews.asMap().entries.map((entry) {
      return PatientReviewItem(
        id: 'rev_${entry.key}',
        patientName: 'Pasien Terverifikasi (Anonim)',
        sentiment: ReviewSentiment.positive,
        label: 'Konseling Membantu',
        description: entry.value,
        rating: 5.0,
        timeAgo: '${entry.key + 1} minggu lalu',
      );
    }).toList();
  }

  /// Backwards compatibility getter
  int get feePerSession => coinsPerSession;

  bool get isVolunteer => isVolunteerRole || practitionerType == PractitionerType.volunteer;
  bool get isFreelance => practitionerType == PractitionerType.freelance;
  bool get isProfessional => practitionerType == PractitionerType.professional;
  bool get hasBothBadges => hasPsychologistCertificate && isVolunteer;

  String get badgeHeaderTitle {
    if (hasBothBadges) {
      return 'Relawan & Profesional';
    } else if (hasPsychologistCertificate) {
      return 'Profesional';
    } else if (isVolunteer) {
      return 'Relawan';
    } else {
      return 'Profesional';
    }
  }

  String get typeLabel {
    if (hasBothBadges) {
      return 'Relawan & Profesional';
    } else if (isVolunteer) {
      return 'Relawan';
    } else {
      return 'Profesional';
    }
  }

  bool get isPsychiatrist =>
      title.toLowerCase().contains('sp.kj') ||
      title.toLowerCase().contains('kedokteran jiwa') ||
      title.toLowerCase().contains('psikiater') ||
      name.toLowerCase().contains('sp.kj');
}

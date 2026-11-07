import 'package:flutter/foundation.dart';

@immutable
class PsychologistEntity {
  final String id;
  final String name;
  final String title;
  final String registrationNumber; // STR or SIPP
  final String avatarUrl;
  final double rating;
  final int reviewCount;
  final int experienceYears;
  final List<String> specialties;
  final int feePerSession; // in IDR
  final int durationMinutes;
  final bool availableOnline;
  final String? clinicAffiliation;
  final String bio;

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
    required this.feePerSession,
    this.durationMinutes = 50,
    this.availableOnline = true,
    this.clinicAffiliation,
    required this.bio,
  });

  bool get isPsychiatrist =>
      title.toLowerCase().contains('sp.kj') ||
      title.toLowerCase().contains('kedokteran jiwa') ||
      title.toLowerCase().contains('psikiater') ||
      name.toLowerCase().contains('sp.kj');
}

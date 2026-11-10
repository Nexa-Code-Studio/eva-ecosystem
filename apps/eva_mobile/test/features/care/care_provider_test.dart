import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eva_mobile/config/app_config.dart';
import 'package:eva_mobile/core/network/api_client.dart';
import 'package:eva_mobile/features/care/data/models/psychologist_model.dart';
import 'package:eva_mobile/features/care/data/models/clinic_model.dart';
import 'package:eva_mobile/features/care/data/models/community_status_model.dart';
import 'package:eva_mobile/features/care/data/models/consultation_session_model.dart';
import 'package:eva_mobile/features/care/data/datasources/mock_care_datasource.dart';
import 'package:eva_mobile/features/care/data/repositories/care_repository_impl.dart';
import 'package:eva_mobile/features/care/data/repositories/fallback_care_repository.dart';
import 'package:eva_mobile/features/care/domain/entities/clinic_entity.dart';
import 'package:eva_mobile/features/care/domain/entities/community_status_entity.dart';
import 'package:eva_mobile/features/care/domain/entities/consultation_session_entity.dart';
import 'package:eva_mobile/features/care/domain/entities/psychologist_entity.dart';
import 'package:eva_mobile/features/care/domain/repositories/care_repository.dart';
import 'package:eva_mobile/features/care/presentation/providers/care_provider.dart';

void main() {
  group('Care Domain & Model Unit Tests', () {
    test('PsychologistModel correctly serializes and deserializes', () {
      final json = {
        'id': 'psy_test',
        'name': 'Test Psychologist, M.Psi.',
        'title': 'Psikolog Klinis',
        'registration_number': 'SIPP: 1234',
        'avatar_url': 'https://example.com/avatar.png',
        'rating': 4.9,
        'review_count': 25,
        'experience_years': 4,
        'specialties': ['Kecemasan', 'Stres'],
        'coins_per_session': 50,
        'duration_minutes': 50,
        'available_online': true,
        'clinic_affiliation': 'Klinik Sehat',
        'bio': 'Test bio description',
        'review_tags': [
          {'label': 'Sangat Sabar & Empati', 'sentiment': 'positive'},
          {'label': 'Slot Sesi Cepat Penuh', 'sentiment': 'negative'},
        ],
        'testimonials': [
          {
            'id': 'rev_test_1',
            'patient_name': 'Pasien Terverifikasi (A.B.)',
            'sentiment': 'positive',
            'label': 'Sangat Sabar & Empati',
            'description': 'Konselingnya sangat membantu meredakan overthinking.',
            'rating': 5.0,
            'time_ago': '2 hari lalu',
          },
        ],
        'patient_stats': {
          'total_patients_treated': 320,
          'total_sessions_completed': 580,
          'satisfaction_rate': 98.7,
          'positive_review_rate': 96.0,
          'recovery_rate': 94.0,
          'avg_recovery_sessions': 3.7,
          'recovery_description': '94% pasien merasakan perbaikan kecemasan signifikan',
        },
      };

      final model = PsychologistModel.fromJson(json);
      expect(model.id, 'psy_test');
      expect(model.name, 'Test Psychologist, M.Psi.');
      expect(model.isPsychiatrist, isFalse);
      expect(model.specialties.length, 2);
      expect(model.coinsPerSession, 50);
      expect(model.feePerSession, 50);
      expect(model.effectiveReviewTags.length, 2);
      expect(model.effectiveReviewTags[0].isPositive, isTrue);
      expect(model.effectiveReviewTags[1].isNegative, isTrue);
      expect(model.effectiveTestimonials.length, 1);
      expect(model.effectiveTestimonials[0].label, 'Sangat Sabar & Empati');
      expect(model.patientStats.totalPatientsTreated, 320);
      expect(model.patientStats.positiveReviewRate, 96.0);
      expect(model.patientStats.negativeReviewRate, 4.0);

      final outJson = model.toJson();
      expect(outJson['registration_number'], 'SIPP: 1234');
      expect(outJson['coins_per_session'], 50);
      expect(outJson['fee_per_session'], 50);
      expect(outJson['patient_stats']['total_patients_treated'], 320);
    });

    test('Psychiatrist detection via title', () {
      const psikiater = PsychologistModel(
        id: 'dr_1',
        name: 'dr. Budi, Sp.KJ',
        title: 'Dokter Spesialis Kedokteran Jiwa',
        registrationNumber: 'STR: 9876',
        avatarUrl: '',
        rating: 5.0,
        reviewCount: 10,
        experienceYears: 8,
        specialties: ['Bipolar'],
        coinsPerSession: 60,
        bio: 'Bio psikiater',
      );

      expect(psikiater.isPsychiatrist, isTrue);
      expect(psikiater.coinsPerSession, 60);
    });

    test('ClinicModel correctly deserializes from JSON', () {
      final json = {
        'id': 'clinic_test',
        'name': 'Klinik Mitra Sehat',
        'address': 'Jl. Sudirman No. 1',
        'city': 'Jakarta Selatan',
        'distance_km': 1.8,
        'photo_url': 'https://example.com/clinic.png',
        'phone': '021-123456',
        'facilities': ['Ruang Konseling', 'Apotek'],
        'rating': 4.85,
      };

      final clinic = ClinicModel.fromJson(json);
      expect(clinic.name, 'Klinik Mitra Sehat');
      expect(clinic.distanceKm, 1.8);
      expect(clinic.facilities.contains('Apotek'), isTrue);
    });

    test('CommunityStatusModel correctly handles state mutations', () {
      final status = const CommunityStatusModel(
        isMember: false,
        isVipActive: false,
        vipRemainingDays: 0,
      );

      final upgraded = status.copyWith(
        isMember: true,
        isVipActive: true,
        vipRemainingDays: 30,
      );

      expect(upgraded.isMember, isTrue);
      expect(upgraded.isVipActive, isTrue);
      expect(upgraded.vipRemainingDays, 30);
    });

    test('Psychologist and Volunteer badges combination logic', () {
      // 1. Volunteer without certificate (free)
      const volunteer = PsychologistModel(
        id: 'vol_1',
        name: 'Bayu Aditya',
        title: 'Relawan Sebaya',
        registrationNumber: 'Cert PFA',
        avatarUrl: '',
        rating: 4.8,
        reviewCount: 10,
        experienceYears: 1,
        specialties: ['Curhat'],
        coinsPerSession: 0,
        bio: 'Bio',
        practitionerType: PractitionerType.volunteer,
        hasPsychologistCertificate: false,
        isVolunteerRole: true,
      );
      expect(volunteer.isVolunteer, isTrue);
      expect(volunteer.hasPsychologistCertificate, isFalse);
      expect(volunteer.hasBothBadges, isFalse);
      expect(volunteer.badgeHeaderTitle, 'Relawan');

      // 2. Psychologist with certificate only
      const pro = PsychologistModel(
        id: 'pro_1',
        name: 'Dimas Wicaksono',
        title: 'Psikolog Klinis',
        registrationNumber: 'SIPP: 1234',
        avatarUrl: '',
        rating: 4.9,
        reviewCount: 20,
        experienceYears: 5,
        specialties: ['Karir'],
        coinsPerSession: 60,
        bio: 'Bio',
        practitionerType: PractitionerType.professional,
        hasPsychologistCertificate: true,
        isVolunteerRole: false,
      );
      expect(pro.isVolunteer, isFalse);
      expect(pro.hasPsychologistCertificate, isTrue);
      expect(pro.hasBothBadges, isFalse);
      expect(pro.badgeHeaderTitle, 'Profesional');

      // 3. User with BOTH badges: Psychologist AND Volunteer
      const both = PsychologistModel(
        id: 'both_1',
        name: 'Amanda Zahra',
        title: 'Psikolog & Relawan',
        registrationNumber: 'SIPP: 5678',
        avatarUrl: '',
        rating: 5.0,
        reviewCount: 50,
        experienceYears: 6,
        specialties: ['Kecemasan'],
        coinsPerSession: 50,
        bio: 'Bio',
        practitionerType: PractitionerType.professional,
        hasPsychologistCertificate: true,
        isVolunteerRole: true,
      );
      expect(both.isVolunteer, isTrue);
      expect(both.hasPsychologistCertificate, isTrue);
      expect(both.hasBothBadges, isTrue);
      expect(both.badgeHeaderTitle, 'Relawan & Profesional');
    });
  });

  group('MockCareDataSource Functional Tests', () {
    late MockCareDataSource dataSource;

    setUp(() {
      dataSource = MockCareDataSource();
    });

    test('Fetches default psychologists list', () async {
      final list = await dataSource.getPsychologists();
      expect(list.isNotEmpty, isTrue);
      expect(list.length, greaterThanOrEqualTo(3));
    });

    test('Filters psychologists by practitioner category', () async {
      final professionals = await dataSource.getPsychologists(category: 'professional');
      expect(professionals.isNotEmpty, isTrue);
      for (final p in professionals) {
        expect(p.isProfessional, isTrue);
      }

      final volunteers = await dataSource.getPsychologists(category: 'volunteer');
      expect(volunteers.isNotEmpty, isTrue);
      for (final p in volunteers) {
        expect(p.isVolunteer, isTrue);
      }
    });

    test('Filters psychologists by search query', () async {
      final results = await dataSource.getPsychologists(query: 'Amanda');
      expect(results.length, 1);
      expect(results.first.name, contains('Amanda'));
    });

    test('Fetches clinics and filters by query', () async {
      final clinics = await dataSource.getClinics();
      expect(clinics.isNotEmpty, isTrue);

      final bandungClinics = await dataSource.getClinics(query: 'Bandung');
      expect(bandungClinics.length, 1);
      expect(bandungClinics.first.city, 'Bandung');
    });

    test('Simulates joining Discord community with 1-month VIP trial', () async {
      final initial = await dataSource.getCommunityStatus();
      expect(initial.isMember, isFalse);
      expect(initial.isVipActive, isFalse);

      final joined = await dataSource.joinCommunityWithVipTrial();
      expect(joined.isMember, isTrue);
      expect(joined.isVipActive, isTrue);
      expect(joined.vipRemainingDays, 30);
    });

    test('Books a new consultation session and updates history', () async {
      final initialSessions = await dataSource.getConsultationSessions();
      final initialCount = initialSessions.length;

      final newSession = await dataSource.bookConsultation(
        psychologistId: 'psy_1',
        preferredDateTime: DateTime.now().add(const Duration(days: 2)),
        sessionType: ConsultationType.onlineVideo,
        complaints: 'Merasa overthinking saat malam hari',
        shareAiChatHistory: true,
      );

      expect(newSession.id, startsWith('sess_'));
      expect(newSession.psychologist.id, 'psy_1');
      expect(newSession.status, ConsultationStatus.upcoming);
      expect(newSession.type, ConsultationType.onlineVideo);
      expect(newSession.meetingUrl, isNotNull);
      expect(newSession.shareAiChatHistory, isTrue);

      final updatedSessions = await dataSource.getConsultationSessions();
      expect(updatedSessions.length, initialCount + 1);
      expect(updatedSessions.first.id, newSession.id);
      expect(updatedSessions.first.shareAiChatHistory, isTrue);
    });

    test('Serializes and deserializes ConsultationSessionModel with shareAiChatHistory consent', () {
      final json = {
        'id': 'sess_test_consent',
        'psychologist': {
          'id': 'psy_1',
          'name': 'Amanda Zahra',
          'title': 'Psikolog Klinis Dewasa',
          'registration_number': 'SIPP: 1234',
          'avatar_url': 'https://example.com/avatar.jpg',
          'rating': 4.9,
          'review_count': 100,
          'experience_years': 6,
          'specialties': ['Kecemasan'],
          'coins_per_session': 50,
          'bio': 'Test bio',
        },
        'session_datetime': DateTime.now().toIso8601String(),
        'status': 'upcoming',
        'type': 'onlineVideo',
        'notes': 'Test notes',
        'share_ai_chat_history': true,
      };

      final model = ConsultationSessionModel.fromJson(json);
      expect(model.shareAiChatHistory, isTrue);

      final serialized = model.toJson();
      expect(serialized['share_ai_chat_history'], isTrue);

      final copy = model.copyWith(shareAiChatHistory: false);
      expect(copy.shareAiChatHistory, isFalse);
    });
  });

  group('FallbackCareRepository & Mode API vs Fallback Dummy Tests', () {
    late FakeRemoteCareRepository fakeRemote;
    late MockCareDataSource mockDataSource;
    late CareRepository mockRepo;
    late FallbackCareRepository fallbackRepo;

    setUp(() {
      fakeRemote = FakeRemoteCareRepository();
      mockDataSource = MockCareDataSource();
      mockRepo = CareRepositoryImpl(mockDataSource);
      fallbackRepo = FallbackCareRepository(remote: fakeRemote, mock: mockRepo);
    });

    test('Mode API: Returns remote data when remote API endpoint succeeds', () async {
      fakeRemote.shouldThrow404 = false;
      final results = await fallbackRepo.getPsychologists();
      expect(results.length, 1);
      expect(results.first.id, 'remote_psy_1');
      expect(results.first.name, 'Remote Psychologist, M.Psi.');
      expect(results.first.coinsPerSession, 45);
    });

    test('Fallback Dummy: Transparently falls back to mock data on 404 (Endpoint not yet implemented)', () async {
      fakeRemote.shouldThrow404 = true;
      final results = await fallbackRepo.getPsychologists();
      expect(results.isNotEmpty, isTrue);
      expect(results.any((p) => p.name.contains('Amanda')), isTrue);
    });

    test('Fallback Dummy: Transparently falls back to mock data on network error / connection refused (Offline)', () async {
      fakeRemote.shouldThrowSocket = true;
      final results = await fallbackRepo.getPsychologists();
      expect(results.isNotEmpty, isTrue);
      expect(results.any((p) => p.name.contains('Amanda')), isTrue);
    });

    test('Mode API: Propagates non-fallback server errors (HTTP 500) without masking backend bugs', () async {
      fakeRemote.shouldThrow500 = true;
      expect(
        () async => fallbackRepo.getPsychologists(),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('Fallback Dummy: Falls back to mock data for clinics on 404', () async {
      fakeRemote.shouldThrow404 = true;
      final clinics = await fallbackRepo.getClinics();
      expect(clinics.isNotEmpty, isTrue);
    });

    test('Fallback Dummy: Falls back to mock data for community status on 404', () async {
      fakeRemote.shouldThrow404 = true;
      final status = await fallbackRepo.getCommunityStatus();
      expect(status.isMember, isFalse);
    });
  });

  group('careRepositoryProvider DI Switching Tests', () {
    test('Resolves to CareRepositoryImpl when useMockData is true', () {
      AppConfig.useMockData = true;
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repo = container.read(careRepositoryProvider);
      expect(repo, isA<CareRepositoryImpl>());
    });
  });
}

class FakeRemoteCareRepository implements CareRepository {
  bool shouldThrow404 = false;
  bool shouldThrow500 = false;
  bool shouldThrowSocket = false;

  final List<PsychologistEntity> remotePsychologists = [
    const PsychologistModel(
      id: 'remote_psy_1',
      name: 'Remote Psychologist, M.Psi.',
      title: 'Psikolog Klinis Remote',
      registrationNumber: 'SIPP: 9999',
      avatarUrl: '',
      rating: 5.0,
      reviewCount: 1,
      experienceYears: 1,
      specialties: ['Remote Test'],
      bio: 'Remote bio test',
      coinsPerSession: 45,
    ),
  ];

  @override
  Future<List<PsychologistEntity>> getPsychologists({String? category, String? query}) async {
    if (shouldThrow404) throw ApiException('Not Found', statusCode: 404);
    if (shouldThrow500) throw ApiException('Internal Error', statusCode: 500);
    if (shouldThrowSocket) throw const SocketException('Connection refused');
    return remotePsychologists;
  }

  @override
  Future<List<ClinicEntity>> getClinics({String? query}) async {
    if (shouldThrow404) throw ApiException('Not Found', statusCode: 404);
    return [];
  }

  @override
  Future<CommunityStatusEntity> getCommunityStatus() async {
    if (shouldThrow404) throw ApiException('Not Found', statusCode: 404);
    return const CommunityStatusModel(isMember: true, isVipActive: false);
  }

  @override
  Future<CommunityStatusEntity> joinCommunityWithVipTrial() async {
    if (shouldThrow404) throw ApiException('Not Found', statusCode: 404);
    return const CommunityStatusModel(isMember: true, isVipActive: true, vipRemainingDays: 30);
  }

  @override
  Future<List<ConsultationSessionEntity>> getConsultationSessions() async {
    if (shouldThrow404) throw ApiException('Not Found', statusCode: 404);
    return [];
  }

  @override
  Future<ConsultationSessionEntity> bookConsultation({
    required String psychologistId,
    required DateTime preferredDateTime,
    required ConsultationType sessionType,
    String? complaints,
    bool shareAiChatHistory = true,
  }) async {
    if (shouldThrow404) throw ApiException('Not Found', statusCode: 404);
    throw UnimplementedError();
  }
}

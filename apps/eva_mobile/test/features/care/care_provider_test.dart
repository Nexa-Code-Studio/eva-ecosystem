import 'package:flutter_test/flutter_test.dart';
import 'package:eva_mobile/features/care/data/models/psychologist_model.dart';
import 'package:eva_mobile/features/care/data/models/clinic_model.dart';
import 'package:eva_mobile/features/care/data/models/community_status_model.dart';
import 'package:eva_mobile/features/care/data/datasources/mock_care_datasource.dart';
import 'package:eva_mobile/features/care/domain/entities/consultation_session_entity.dart';

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
        'fee_per_session': 150000,
        'duration_minutes': 50,
        'available_online': true,
        'clinic_affiliation': 'Klinik Sehat',
        'bio': 'Test bio description',
      };

      final model = PsychologistModel.fromJson(json);
      expect(model.id, 'psy_test');
      expect(model.name, 'Test Psychologist, M.Psi.');
      expect(model.isPsychiatrist, isFalse);
      expect(model.specialties.length, 2);
      expect(model.feePerSession, 150000);

      final outJson = model.toJson();
      expect(outJson['registration_number'], 'SIPP: 1234');
      expect(outJson['fee_per_session'], 150000);
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
        feePerSession: 250000,
        bio: 'Bio psikiater',
      );

      expect(psikiater.isPsychiatrist, isTrue);
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

    test('Filters psychologists by psychiatrist category', () async {
      final psychiatrists = await dataSource.getPsychologists(category: 'psychiatrist');
      expect(psychiatrists.isNotEmpty, isTrue);
      for (final p in psychiatrists) {
        expect(p.isPsychiatrist, isTrue);
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
      );

      expect(newSession.id, startsWith('sess_'));
      expect(newSession.psychologist.id, 'psy_1');
      expect(newSession.status, ConsultationStatus.upcoming);
      expect(newSession.type, ConsultationType.onlineVideo);
      expect(newSession.meetingUrl, isNotNull);

      final updatedSessions = await dataSource.getConsultationSessions();
      expect(updatedSessions.length, initialCount + 1);
      expect(updatedSessions.first.id, newSession.id);
    });
  });
}

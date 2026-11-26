import 'package:eva_mobile/features/care/data/models/community_status_model.dart';
import 'package:eva_mobile/features/care/data/models/psychologist_model.dart';
import 'package:eva_mobile/features/care/domain/entities/community_status_entity.dart';
import 'package:eva_mobile/features/care/domain/entities/consultation_session_entity.dart';
import 'package:eva_mobile/features/care/domain/entities/counselor_timeline_entity.dart';
import 'package:eva_mobile/features/care/domain/entities/psychologist_entity.dart';
import 'package:eva_mobile/features/care/domain/entities/psychologist_rating_review.dart';
import 'package:eva_mobile/features/care/domain/repositories/care_repository.dart';
import 'package:eva_mobile/features/care/presentation/providers/care_provider.dart';
import 'package:eva_mobile/features/care/presentation/screens/care_screen.dart';
import 'package:eva_mobile/features/care/presentation/widgets/psychologist_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestCareRepository implements CareRepository {
  final List<PsychologistEntity> items;
  String? lastAvailability;
  int? lastLevelTier;
  String? lastSortBy;
  String? lastQuery;

  _TestCareRepository(this.items);

  @override
  Future<List<PsychologistEntity>> getPsychologists({
    String? availability,
    int? levelTier,
    String? sortBy,
    String? query,
  }) async {
    lastAvailability = availability;
    lastLevelTier = levelTier;
    lastSortBy = sortBy;
    lastQuery = query;

    var res = List<PsychologistEntity>.from(items);
    if (availability == 'available_now') {
      res = res.where((p) => p.isAvailableNow).toList();
    } else if (availability == 'available_today') {
      res = res.where((p) => p.isAvailableToday).toList();
    } else if (availability == 'available_tomorrow') {
      res = res.where((p) => p.hasSlotsTomorrow).toList();
    }
    if (levelTier != null) {
      res = res.where((p) => p.levelTier == levelTier).toList();
    }
    if (sortBy == 'rating') {
      res.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return res;
  }

  @override
  Future<List<ConsultationSessionEntity>> getConsultationSessions() async => const [];

  @override
  Future<CommunityStatusEntity> getCommunityStatus() async =>
      const CommunityStatusModel(isMember: false, isVipActive: false);

  @override
  Future<CommunityStatusEntity> joinCommunityWithVipTrial() async =>
      const CommunityStatusModel(isMember: true, isVipActive: true);

  @override
  Future<PsychologistEntity> getCounselorDetail(String counselorId) async => items.first;

  @override
  Future<List<PatientReviewItem>> getCounselorReviews(String counselorId) async => const [];

  @override
  Future<CounselorTimelineEntity> getCounselorTimeline({
    required String counselorId,
    required DateTime date,
  }) async =>
      CounselorTimelineEntity(
        counselorId: counselorId,
        date: date,
        operatingHours: const OperatingHoursEntity(
          start: TimeOfDay(hour: 8, minute: 0),
          end: TimeOfDay(hour: 17, minute: 0),
        ),
      );

  @override
  Future<ConsultationSessionEntity> bookConsultation({
    required String psychologistId,
    required DateTime preferredDateTime,
    required ConsultationType sessionType,
    int sessionCount = 1,
    int durationMinutes = 30,
    String? complaints,
    bool shareAiChatHistory = false,
  }) async =>
      throw UnimplementedError();

  @override
  Future<PsychologistRatingReview> submitSessionReview({
    required String sessionId,
    required String psychologistId,
    required double rating,
    String? highlightLabel,
    String? reviewText,
    bool isAnonymous = true,
  }) async =>
      throw UnimplementedError();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final samplePsychologists = [
    const PsychologistModel(
      id: 'p1',
      name: 'Amanda Zahra, M.Psi., Psikolog',
      title: 'Psikolog Klinis Dewasa',
      registrationNumber: 'SIPP: 1111',
      avatarUrl: '',
      rating: 4.8,
      reviewCount: 40,
      experienceYears: 5,
      specialties: ['Kecemasan'],
      bio: 'Bio 1',
      levelTier: 3,
      levelName: 'Senior Specialist',
      levelBadgeIcon: 'star',
      availabilityStatus: CounselorAvailabilityStatus.availableNow,
      nextAvailableSlot: '14:00',
      remainingSlotsToday: 5,
      hasSlotsTomorrow: true,
      nextSlotTomorrow: '08:00',
    ),
    const PsychologistModel(
      id: 'p2',
      name: 'Dimas Wicaksono, M.Psi., Psikolog',
      title: 'Psikolog Klinis Karir',
      registrationNumber: 'SIPP: 2222',
      avatarUrl: '',
      rating: 4.95,
      reviewCount: 80,
      experienceYears: 8,
      specialties: ['Burnout'],
      bio: 'Bio 2',
      levelTier: 4,
      levelName: 'Master Expert',
      levelBadgeIcon: 'crown',
      availabilityStatus: CounselorAvailabilityStatus.availableTomorrow,
      nextAvailableSlot: '09:00',
      remainingSlotsToday: 0,
      hasSlotsTomorrow: true,
      nextSlotTomorrow: '09:00',
    ),
  ];

  testWidgets('CareScreen shows availability, rating, level filters and hides Relawan',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _TestCareRepository(samplePsychologists);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          careRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: CareScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Temukan Psikolog'), findsOneWidget);
    expect(find.text('Relawan'), findsNothing);
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Saat Ini'), findsOneWidget);
    expect(find.text('Hari Ini'), findsOneWidget);
    expect(find.text('Besok'), findsOneWidget);
    expect(find.text('Rating Terbaik'), findsOneWidget);
    expect(find.text('Level'), findsOneWidget);

    // Card availability tags above name + avatar level badges
    expect(find.text('Tersedia Sekarang'), findsOneWidget);
    expect(find.text('5 Slot Hari Ini'), findsOneWidget);
    expect(find.text('Besok • 09:00'), findsOneWidget);
    expect(find.text('Lv.3'), findsOneWidget);
    expect(find.text('Lv.4'), findsOneWidget);

    // Tap 'Saat Ini' + 'Rating Terbaik' combinable filters
    await tester.tap(find.text('Saat Ini'));
    await tester.pumpAndSettle();
    expect(repo.lastAvailability, 'available_now');
    expect(find.text('Amanda Zahra, M.Psi., Psikolog'), findsOneWidget);
    expect(find.text('Dimas Wicaksono, M.Psi., Psikolog'), findsNothing);

    await tester.tap(find.text('Rating Terbaik'));
    await tester.pumpAndSettle();
    expect(repo.lastAvailability, 'available_now');
    expect(repo.lastSortBy, 'rating');

    // Open Level picker sheet and choose Tier 4
    await tester.tap(find.text('Semua'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Level'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Level'));
    await tester.pumpAndSettle();
    expect(find.text('Filter Level Psikolog'), findsOneWidget);
    await tester.tap(find.text('Master Expert'));
    await tester.pumpAndSettle();
    expect(repo.lastLevelTier, 4);
    expect(find.text('Dimas Wicaksono, M.Psi., Psikolog'), findsOneWidget);
    expect(find.text('Amanda Zahra, M.Psi., Psikolog'), findsNothing);
  });

  testWidgets('PsychologistCard renders Hari Ini tag and Lv badge cleanly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PsychologistCard(
            psychologist: const PsychologistModel(
              id: 'p3',
              name: 'Rian Pratama, M.Psi., Psikolog',
              title: 'Psikolog Klinis',
              registrationNumber: 'SIPP: 3333',
              avatarUrl: '',
              rating: 4.9,
              reviewCount: 30,
              experienceYears: 4,
              specialties: ['Relasi'],
              bio: 'Bio',
              levelTier: 2,
              levelName: 'Registered Counselor',
              levelBadgeIcon: 'shield-check',
              availabilityStatus: CounselorAvailabilityStatus.availableToday,
              nextAvailableSlot: '15:30',
              remainingSlotsToday: 2,
            ),
            onBookTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hari Ini • 15:30'), findsOneWidget);
    expect(find.text('2 Slot Tersisa'), findsOneWidget);
    expect(find.text('Lv.2'), findsOneWidget);
    expect(find.text('Profesional'), findsNothing);
    expect(find.text('Relawan'), findsNothing);
  });
}

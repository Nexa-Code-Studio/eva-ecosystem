import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eva_mobile/config/app_config.dart';
import 'package:eva_mobile/core/network/api_client.dart';
import 'package:eva_mobile/features/care/domain/entities/community_status_entity.dart';
import 'package:eva_mobile/features/care/domain/entities/consultation_session_entity.dart';
import 'package:eva_mobile/features/care/domain/entities/counselor_timeline_entity.dart';
import 'package:eva_mobile/features/care/domain/entities/psychologist_entity.dart';
import 'package:eva_mobile/features/care/domain/entities/psychologist_rating_review.dart';
import 'package:eva_mobile/features/care/domain/repositories/care_repository.dart';
import 'package:eva_mobile/features/care/presentation/providers/care_provider.dart';
import 'package:eva_mobile/features/care/presentation/screens/consultation_rating_screen.dart';
import 'package:eva_mobile/features/care/presentation/screens/consultation_schedule_screen.dart';
import 'package:eva_mobile/features/care/presentation/screens/psychologist_detail_screen.dart';
import 'package:eva_mobile/features/care/presentation/screens/booking_consultation_screen.dart';
import 'package:eva_mobile/features/care/presentation/widgets/consultation_result_bottom_sheet.dart';
import 'package:eva_mobile/features/care/presentation/widgets/psychologist_card.dart';
import 'package:eva_mobile/features/care/presentation/widgets/psychologist_certificate_carousel.dart';
import '../../test_helpers/mock_image_http.dart';

class _ConfigurableCareRepository implements CareRepository {
  bool failSessions = false;
  int getSessionsCalls = 0;
  int submitReviewCalls = 0;
  String? lastSubmittedSessionId;
  List<ConsultationSessionEntity> sessions = const [];
  List<PatientReviewItem> reviews = const [];
  PsychologistEntity? detail;
  DateTime? lastTimelineDate;

  @override
  Future<List<ConsultationSessionEntity>> getConsultationSessions() async {
    getSessionsCalls++;
    if (failSessions) {
      throw ApiException('Backend unavailable', statusCode: 503);
    }
    return sessions;
  }

  @override
  Future<PsychologistEntity> getCounselorDetail(String counselorId) async {
    return detail!;
  }

  @override
  Future<List<PatientReviewItem>> getCounselorReviews(String counselorId) async {
    return reviews;
  }

  @override
  Future<PsychologistRatingReview> submitSessionReview({
    required String sessionId,
    required String psychologistId,
    required double rating,
    String? highlightLabel,
    String? reviewText,
    bool isAnonymous = true,
  }) async {
    submitReviewCalls++;
    lastSubmittedSessionId = sessionId;
    return PsychologistRatingReview(
      psychologistId: psychologistId,
      rating: rating,
      isPositive: rating >= 4.0,
      label: highlightLabel ?? 'Ulasan Sesi',
      description: reviewText ?? '',
      createdAt: DateTime.now(),
      isAnonymous: isAnonymous,
    );
  }

  @override
  Future<List<PsychologistEntity>> getPsychologists({
    String? availability,
    int? levelTier,
    String? sortBy,
    String? query,
  }) async =>
      detail != null ? [detail!] : const [];

  @override
  Future<CommunityStatusEntity> getCommunityStatus() async =>
      const CommunityStatusEntity(isMember: false, isVipActive: false);

  @override
  Future<CommunityStatusEntity> joinCommunityWithVipTrial() async =>
      const CommunityStatusEntity(isMember: true, isVipActive: true, vipRemainingDays: 30);

  @override
  Future<CounselorTimelineEntity> getCounselorTimeline({
    required String counselorId,
    required DateTime date,
  }) async {
    lastTimelineDate = date;
    return CounselorTimelineEntity(
      counselorId: counselorId,
      date: date,
      operatingHours: const OperatingHoursEntity(
        start: TimeOfDay(hour: 8, minute: 0),
        end: TimeOfDay(hour: 17, minute: 0),
      ),
    );
  }

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
}

void main() {
  setUpAll(() {
    HttpOverrides.global = TestHttpOverrides();
  });

  setUp(() {
    AppConfig.useMockData = false;
  });

  const liveCounselor = PsychologistEntity(
    id: 'psy-live-1',
    name: 'Dr. Nadya Kusuma, M.Psi.',
    title: 'Psikolog Klinis',
    registrationNumber: 'SIP-2026-01',
    avatarUrl: '',
    rating: 4.8,
    reviewCount: 15,
    experienceYears: 6,
    specialties: ['Kecemasan'],
    certifications: ['STR: STR-001', 'SIP/SIPP: SIP-2026-01'],
    coinsPerSession: 120,
    durationMinutes: 30,
    bio: 'Psikolog klinis berlisensi.',
    levelTier: 2,
    levelName: 'Senior Specialist',
  );

  testWidgets('ConsultationScheduleScreen shows API error + retry and filters missed vs upcoming',
      (tester) async {
    final repo = _ConfigurableCareRepository()
      ..failSessions = true
      ..detail = liveCounselor;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [careRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ConsultationScheduleScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gagal Memuat Jadwal Sesi'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);

    // Recover API and retry
    repo.failSessions = false;
    repo.sessions = [
      ConsultationSessionEntity(
        id: 'sess-upcoming',
        psychologist: liveCounselor,
        sessionDateTime: DateTime.now().add(const Duration(days: 1)),
        status: ConsultationStatus.upcoming,
      ),
      ConsultationSessionEntity(
        id: 'sess-missed',
        psychologist: liveCounselor,
        sessionDateTime: DateTime.now().subtract(const Duration(days: 1)),
        status: ConsultationStatus.missed,
      ),
    ];

    await tester.tap(find.text('Coba Lagi'));
    await tester.pumpAndSettle();

    expect(find.text('Sesi Aktif (1)'), findsOneWidget);
    expect(find.text('Semua (2)'), findsOneWidget);

    // Locked upcoming dialog in live mode must NOT show simulation bypass button
    await tester.tap(find.text('Belum Waktunya'));
    await tester.pumpAndSettle();
    expect(find.text('Masuk Sekarang (Simulasi/Test)'), findsNothing);
    await tester.tap(find.text('Mengerti'));
    await tester.pumpAndSettle();

    // Switch to 'Semua (2)' tab and verify 'Terlewat' badge for missed session
    await tester.tap(find.text('Semua (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Terlewat'), findsOneWidget);
  });

  testWidgets('PsychologistCard shows dynamic level badge and DetailScreen shows live reviews empty state',
      (tester) async {
    final repo = _ConfigurableCareRepository()
      ..detail = liveCounselor
      ..reviews = const [];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [careRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Scaffold(
            body: PsychologistCard(
              psychologist: liveCounselor,
              onBookTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lv.2'), findsOneWidget);
    expect(find.byTooltip('Senior Specialist'), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [careRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: PsychologistDetailScreen(psychologist: liveCounselor),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Senior Specialist'), findsOneWidget);
    expect(find.text('Belum ada ulasan pasien terverifikasi untuk konselor ini.'), findsOneWidget);
    expect(find.byType(PsychologistCertificateCarousel), findsNothing);
    expect(find.text('STR: STR-001'), findsOneWidget);
  });

  testWidgets('ConsultationResultBottomSheet shows honest empty SOAP state in live mode',
      (tester) async {
    final emptySession = ConsultationSessionEntity(
      id: 'sess-empty-soap',
      psychologist: liveCounselor,
      sessionDateTime: DateTime(2026, 11, 25, 10, 0),
      status: ConsultationStatus.completed,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConsultationResultBottomSheet(session: emptySession),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Catatan klinis / SOAP untuk sesi ini belum ditambahkan oleh konselor.'),
      findsOneWidget,
    );
    expect(find.text('Sesi konsultasi tatap muka selesai dilaksanakan'), findsNothing);
  });

  testWidgets('ConsultationRatingScreen submits per-session review to backend repository',
      (tester) async {
    final repo = _ConfigurableCareRepository()..detail = liveCounselor;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [careRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: ConsultationRatingScreen(
            psychologist: liveCounselor,
            sessionId: 'sess-rate-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Sangat Empatik');
    await tester.tap(find.text('Kirim Penilaian & Ulasan'));
    await tester.pumpAndSettle();

    expect(repo.submitReviewCalls, 1);
    expect(repo.lastSubmittedSessionId, 'sess-rate-1');
  });

  testWidgets('BookingConsultationScreen uses date picker defaulting to today without fixed day chips',
      (tester) async {
    final repo = _ConfigurableCareRepository()..detail = liveCounselor;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [careRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: BookingConsultationScreen(psychologist: liveCounselor),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pilih Tanggal'), findsOneWidget);
    expect(find.textContaining('Hari Ini •'), findsOneWidget);
    expect(find.text('Besok'), findsNothing);
    expect(find.text('Lusa'), findsNothing);
    expect(find.text('3 Hari Lagi'), findsNothing);
    expect(repo.lastTimelineDate, today);

    await tester.tap(find.byKey(const Key('booking_date_picker_field')));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
  });
}

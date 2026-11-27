import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eva_counselor_mobile/features/auth/domain/entities/psychologist_user_entity.dart';
import 'package:eva_counselor_mobile/features/profile/data/datasources/counselor_profile_remote_data_source.dart';
import 'package:eva_counselor_mobile/features/profile/domain/entities/counselor_level_metrics_entity.dart';
import 'package:eva_counselor_mobile/features/profile/domain/entities/counselor_review_entity.dart';
import 'package:eva_counselor_mobile/features/profile/domain/entities/counselor_schedule_config_entity.dart';
import 'package:eva_counselor_mobile/features/profile/presentation/providers/counselor_level_metrics_provider.dart';
import 'package:eva_counselor_mobile/features/profile/presentation/widgets/counselor_level_progress_modal.dart';
import 'package:eva_counselor_mobile/features/profile/presentation/widgets/counselor_profile_header_card.dart';
import 'package:eva_counselor_mobile/features/profile/presentation/widgets/counselor_rate_modal.dart';
import 'package:eva_counselor_mobile/features/profile/presentation/widgets/counselor_reviews_modal.dart';

class _FakeCounselorProfileDataSource implements ICounselorProfileDataSource {
  final CounselorLevelMetricsEntity metrics;
  final CounselorReviewsListEntity reviews;

  _FakeCounselorProfileDataSource({
    required this.metrics,
    required this.reviews,
  });

  @override
  Future<CounselorLevelMetricsEntity> fetchLevelMetrics() async => metrics;

  @override
  Future<CounselorReviewsListEntity> fetchReviews({String? counselorId}) async =>
      reviews;

  @override
  Future<CounselorLevelMetricsEntity> updateCustomPrice(double customPrice) async {
    return metrics.copyWith(
      customPricePerSession: customPrice,
      activeSessionPrice: customPrice,
    );
  }

  @override
  Future<CounselorScheduleConfigEntity> fetchScheduleConfig() async =>
      CounselorScheduleConfigEntity.defaults(counselorId: metrics.counselorId);

  @override
  Future<CounselorScheduleConfigEntity> updateScheduleConfig({
    required Map<String, dynamic> scheduleConfig,
    required int bufferTimeMinutes,
  }) async =>
      CounselorScheduleConfigEntity.fromJson({
        'counselor_id': metrics.counselorId,
        'buffer_time_minutes': bufferTimeMinutes,
        'schedule_config': scheduleConfig,
      });

  @override
  Future<CounselorDailyTimelineEntity> fetchMyDailyTimeline(
          DateTime date) async =>
      CounselorDailyTimelineEntity.empty(
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        counselorId: metrics.counselorId,
      );
}

void main() {
  const sampleMetrics = CounselorLevelMetricsEntity(
    counselorId: 'counselor-123',
    levelTier: 2,
    levelName: 'Advanced Counselor',
    badgeIcon: 'star',
    totalCompletedSessions: 24,
    totalConsultationHours: 12.0,
    averageRating: 4.9,
    ratingCount: 18,
    activeSessionPrice: 75000.0,
    platformFeePercentage: 20.0,
    allowCustomPrice: false,
    nextLevel: NextLevelTargetEntity(
      levelTier: 3,
      levelName: 'Senior Specialist',
      badgeIcon: 'military_tech',
      targetSessions: 30,
      targetRating: 4.7,
      targetHours: 15.0,
      sessionsRemaining: 6,
      hoursRemaining: 3.0,
      ratingAchieved: true,
    ),
  );

  const sampleMasterMetrics = CounselorLevelMetricsEntity(
    counselorId: 'counselor-master',
    levelTier: 4,
    levelName: 'Master Expert',
    badgeIcon: 'workspace_premium',
    totalCompletedSessions: 80,
    totalConsultationHours: 40.0,
    averageRating: 4.95,
    ratingCount: 45,
    activeSessionPrice: 150000.0,
    platformFeePercentage: 20.0,
    allowCustomPrice: true,
    customPricePerSession: 150000.0,
    minCustomPrice: 100000.0,
    maxCustomPrice: 500000.0,
    nextLevel: null,
  );

  final sampleReviews = CounselorReviewsListEntity(
    counselorId: 'counselor-123',
    total: 2,
    averageRating: 4.9,
    items: [
      CounselorReviewEntity(
        id: 'rev-1',
        sessionId: 'sess-101',
        patientName: 'Pasien Terverifikasi (Anonim)',
        rating: 5.0,
        label: 'Sangat Sabar & Empati',
        reviewText: 'Konseling berjalan sangat menenangkan dan membantu kecemasan saya.',
        isAnonymous: true,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      CounselorReviewEntity(
        id: 'rev-2',
        sessionId: 'sess-102',
        patientName: 'Budi Santoso',
        rating: 4.8,
        label: 'Solutif & Praktis',
        reviewText: 'Latihan mindfulness yang diajarkan sangat aplikatif.',
        isAnonymous: false,
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ],
  );

  const sampleUser = PsychologistUserEntity(
    id: 'counselor-123',
    fullName: 'Dr. Sarah Anindya',
    titleDegree: 'M.Psi., Psikolog',
    email: 'sarah@psikolog.eva.id',
    strNumber: 'STR-PK-198827364-2026',
    association: 'HIMPSI',
    specializations: ['Kecemasan Dewasa'],
    yearsOfExperience: 5,
    consultationRatePerHour: 50000,
    verificationStatus: VerificationStatus.verified,
    role: CounselorRole.professionalIndependent,
    isOnline: true,
    coinBalance: 50,
  );

  group('Counselor Level Metrics & Reviews Domain Tests', () {
    test('Entity calculates progress fraction and fee breakdown accurately', () {
      expect(sampleMetrics.progressFraction, 24 / 30);
      expect(sampleMetrics.platformFeeAmount, 15000.0);
      expect(sampleMetrics.netCounselorEarning, 60000.0);

      expect(sampleMasterMetrics.progressFraction, 1.0);
      expect(sampleMasterMetrics.platformFeeAmount, 30000.0);
      expect(sampleMasterMetrics.netCounselorEarning, 120000.0);
    });

    test('Entity deserialization from backend JSON structure', () {
      final json = {
        'counselor_id': 'c-1',
        'level_tier': 3,
        'level_name': 'Senior Specialist',
        'badge_icon': 'military_tech',
        'total_completed_sessions': 35,
        'total_consultation_hours': 17.5,
        'average_rating': 4.88,
        'rating_count': 22,
        'active_session_price': 100000.0,
        'platform_fee_percentage': 20.0,
        'allow_custom_price': false,
        'next_level': {
          'level_tier': 4,
          'level_name': 'Master Expert',
          'badge_icon': 'workspace_premium',
          'target_sessions': 60,
          'target_rating': 4.85,
          'target_hours': 30.0,
          'sessions_remaining': 25,
          'hours_remaining': 12.5,
          'rating_achieved': true,
        },
      };

      final parsed = CounselorLevelMetricsEntity.fromJson(json);
      expect(parsed.levelTier, 3);
      expect(parsed.totalCompletedSessions, 35);
      expect(parsed.nextLevel?.sessionsRemaining, 25);
    });
  });

  group('Counselor Profile Header & Level Widgets Tests', () {
    testWidgets('Header card displays live rating, sessions, and consultation hours', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            counselorProfileDataSourceProvider.overrideWithValue(
              _FakeCounselorProfileDataSource(
                metrics: sampleMetrics,
                reviews: sampleReviews,
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CounselorProfileHeaderCard(user: sampleUser),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify 3 Stats from Live Server
      expect(find.text('4.9 / 5.0'), findsOneWidget);
      expect(find.text('18 Ulasan >'), findsOneWidget);
      expect(find.text('24 Sesi'), findsOneWidget);
      expect(find.text('12.0 Jam'), findsOneWidget);
      expect(find.text('Jam Terbang'), findsOneWidget);

      // Verify Level Badge
      expect(find.text('Lvl 2 • Advanced Counselor'), findsOneWidget);
    });

    testWidgets('CounselorLevelProgressModal renders progress bar and target checklist', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            counselorProfileDataSourceProvider.overrideWithValue(
              _FakeCounselorProfileDataSource(
                metrics: sampleMetrics,
                reviews: sampleReviews,
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => CounselorLevelProgressModal.show(ctx),
                  child: const Text('Open Level Modal'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Level Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Level 2: Advanced Counselor'), findsOneWidget);
      expect(find.text('Target Senior Specialist'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);
      expect(find.text('Jumlah Sesi Selesai'), findsOneWidget);
      expect(find.text('Akumulasi Jam Terbang'), findsOneWidget);
    });

    testWidgets('CounselorRateModal allows custom pricing input for Master Level', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            counselorProfileDataSourceProvider.overrideWithValue(
              _FakeCounselorProfileDataSource(
                metrics: sampleMasterMetrics,
                reviews: sampleReviews,
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => CounselorRateModal.show(
                    context: ctx,
                    user: sampleUser,
                    onSave: (_) {},
                  ),
                  child: const Text('Open Rate Modal'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Rate Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Atur Tarif Mandiri (Master Tier)'), findsOneWidget);
      expect(find.text('Simpan Tarif Baru ke Server'), findsOneWidget);
      expect(find.text('Bagi Hasil Bersih Anda'), findsOneWidget);
    });

    testWidgets('CounselorReviewsModal displays live per-session reviews', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            counselorProfileDataSourceProvider.overrideWithValue(
              _FakeCounselorProfileDataSource(
                metrics: sampleMetrics,
                reviews: sampleReviews,
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => CounselorReviewsModal.show(ctx, totalSessions: 24),
                  child: const Text('Open Reviews Modal'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Reviews Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Ulasan & Penilaian Pasien'), findsOneWidget);
      expect(find.text('4.9'), findsOneWidget);
      expect(find.text('2 Ulasan'), findsOneWidget);
      expect(find.text('Pasien Terverifikasi (Anonim)'), findsOneWidget);
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('Sangat Sabar & Empati'), findsOneWidget);
    });
  });
}

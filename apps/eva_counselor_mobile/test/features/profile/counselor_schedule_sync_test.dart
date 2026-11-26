import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eva_counselor_mobile/core/config/app_config.dart';
import 'package:eva_counselor_mobile/features/auth/domain/entities/psychologist_user_entity.dart';
import 'package:eva_counselor_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:eva_counselor_mobile/features/dashboard/presentation/providers/counselor_notification_provider.dart';
import 'package:eva_counselor_mobile/features/dashboard/presentation/screens/counselor_home_screen.dart';
import 'package:eva_counselor_mobile/features/finances/domain/entities/transaction_entity.dart';
import 'package:eva_counselor_mobile/features/finances/presentation/providers/finance_provider.dart';
import 'package:eva_counselor_mobile/features/patients/presentation/providers/patient_provider.dart';
import 'package:eva_counselor_mobile/features/profile/data/datasources/counselor_profile_remote_data_source.dart';
import 'package:eva_counselor_mobile/features/profile/domain/entities/counselor_level_metrics_entity.dart';
import 'package:eva_counselor_mobile/features/profile/domain/entities/counselor_review_entity.dart';
import 'package:eva_counselor_mobile/features/profile/domain/entities/counselor_schedule_config_entity.dart';
import 'package:eva_counselor_mobile/features/profile/presentation/providers/counselor_level_metrics_provider.dart';
import 'package:eva_counselor_mobile/features/profile/presentation/screens/counselor_schedule_settings_screen.dart';

class _FakeScheduleProfileDataSource implements ICounselorProfileDataSource {
  CounselorScheduleConfigEntity scheduleConfig;
  CounselorDailyTimelineEntity timeline;
  bool shouldFailOnSave;
  bool availabilityUpdatedTo = true;
  int fetchScheduleCount = 0;
  int saveScheduleCount = 0;
  int fetchTimelineCount = 0;

  _FakeScheduleProfileDataSource({
    required this.scheduleConfig,
    required this.timeline,
    this.shouldFailOnSave = false,
  });

  @override
  Future<CounselorLevelMetricsEntity> fetchLevelMetrics() async =>
      const CounselorLevelMetricsEntity(
        counselorId: 'c-sync-1',
        levelTier: 1,
        levelName: 'Junior',
        badgeIcon: 'seedling',
        totalCompletedSessions: 0,
        totalConsultationHours: 0,
        averageRating: 0,
        ratingCount: 0,
        activeSessionPrice: 50000,
        platformFeePercentage: 20,
        allowCustomPrice: false,
      );

  @override
  Future<CounselorReviewsListEntity> fetchReviews({String? counselorId}) async =>
      const CounselorReviewsListEntity(
        counselorId: 'c-sync-1',
        items: [],
        total: 0,
        averageRating: 0,
      );

  @override
  Future<CounselorLevelMetricsEntity> updateCustomPrice(double customPrice) =>
      fetchLevelMetrics();

  @override
  Future<CounselorScheduleConfigEntity> fetchScheduleConfig() async {
    fetchScheduleCount++;
    return scheduleConfig;
  }

  @override
  Future<CounselorScheduleConfigEntity> updateScheduleConfig({
    required Map<String, dynamic> scheduleConfig,
    required int bufferTimeMinutes,
  }) async {
    saveScheduleCount++;
    if (shouldFailOnSave) {
      throw Exception('Simulasi server gagal menyimpan');
    }
    this.scheduleConfig = CounselorScheduleConfigEntity.fromJson({
      'counselor_id': this.scheduleConfig.counselorId,
      'buffer_time_minutes': bufferTimeMinutes,
      'schedule_config': scheduleConfig,
    });
    return this.scheduleConfig;
  }

  @override
  Future<CounselorDailyTimelineEntity> fetchMyDailyTimeline(
      DateTime date) async {
    fetchTimelineCount++;
    return timeline;
  }
}

class _FakeSyncAuthNotifier
    extends StateNotifier<AsyncValue<PsychologistUserEntity?>>
    implements AuthStateNotifier {
  final List<bool> availabilityUpdates = [];
  Map<String, dynamic>? lastAppliedScheduleConfig;
  int? lastAppliedBufferMinutes;
  bool? lastAppliedOnline;

  _FakeSyncAuthNotifier(PsychologistUserEntity user)
      : super(AsyncValue.data(user));

  @override
  Future<void> applyScheduleConfig({
    required Map<String, dynamic> scheduleConfig,
    required int bufferTimeMinutes,
    required bool isOnline,
  }) async {
    lastAppliedScheduleConfig = scheduleConfig;
    lastAppliedBufferMinutes = bufferTimeMinutes;
    lastAppliedOnline = isOnline;
    final current = state.value;
    if (current != null) {
      state = AsyncValue.data(
        current.copyWith(
          scheduleConfig: scheduleConfig,
          bufferTimeMinutes: bufferTimeMinutes,
          isOnline: isOnline,
          isScheduleConfigured: true,
        ),
      );
    }
  }

  @override
  Future<void> updateAvailability(bool isOnline) async {
    availabilityUpdates.add(isOnline);
    final current = state.value;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(isOnline: isOnline));
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    AppConfig.useMockData = false;
  });

  tearDown(() {
    AppConfig.useMockData = false;
  });

  const testUser = PsychologistUserEntity(
    id: 'c-sync-1',
    fullName: 'Dr. Maya Putri',
    titleDegree: 'M.Psi., Psikolog',
    email: 'maya@eva.id',
    strNumber: 'STR-1234',
    association: 'HIMPSI',
    specializations: ['Klinis'],
    yearsOfExperience: 5,
    consultationRatePerHour: 100000,
    role: CounselorRole.professionalIndependent,
    verificationStatus: VerificationStatus.verified,
    isOnline: true,
    isScheduleConfigured: true,
    bufferTimeMinutes: 10,
  );

  CounselorScheduleConfigEntity buildCustomScheduleConfig() {
    return CounselorScheduleConfigEntity.fromJson({
      'counselor_id': 'c-sync-1',
      'buffer_time_minutes': 15,
      'schedule_config': {
        'monday': {
          'is_active': true,
          'operating_hours': {'start': '10:00', 'end': '16:00'},
          'breaks': [],
        },
        'tuesday': {
          'is_active': true,
          'operating_hours': {'start': '09:00', 'end': '17:00'},
          'breaks': [
            {'start': '12:00', 'end': '13:00', 'label': 'Istirahat Siang'}
          ],
        },
      },
    });
  }

  group('CounselorScheduleSettingsScreen sync & error handling', () {
    testWidgets(
      'loads remote schedule_config on init and blocks pop when save fails',
      (WidgetTester tester) async {
        final fakeDs = _FakeScheduleProfileDataSource(
          scheduleConfig: buildCustomScheduleConfig(),
          timeline: CounselorDailyTimelineEntity.empty('2026-11-23'),
          shouldFailOnSave: true,
        );
        final fakeAuth = _FakeSyncAuthNotifier(testUser);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              counselorProfileDataSourceProvider.overrideWithValue(fakeDs),
              authStateProvider.overrideWith((ref) => fakeAuth),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CounselorScheduleSettingsScreen(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(fakeDs.fetchScheduleCount, 1);
        expect(find.text('10:00'), findsOneWidget);
        expect(find.text('16:00'), findsOneWidget);
        expect(find.text('15 Menit'), findsOneWidget);

        await tester.ensureVisible(find.text('Simpan Jadwal Praktik'));
        await tester.tap(find.text('Simpan Jadwal Praktik'));
        await tester.pump();

        expect(fakeDs.saveScheduleCount, 1);
        expect(find.text('Gagal Menyimpan Jadwal'), findsOneWidget);
        expect(find.text('Jadwal & Multi Jam Istirahat'), findsOneWidget);

        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'persists vacation mode isOnline=false cleanly without resetting availability',
      (WidgetTester tester) async {
        final fakeDs = _FakeScheduleProfileDataSource(
          scheduleConfig: buildCustomScheduleConfig(),
          timeline: CounselorDailyTimelineEntity.empty('2026-11-23'),
        );
        final fakeAuth = _FakeSyncAuthNotifier(testUser);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              counselorProfileDataSourceProvider.overrideWithValue(fakeDs),
              authStateProvider.overrideWith((ref) => fakeAuth),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const CounselorScheduleSettingsScreen(),
                          ),
                        );
                      },
                      child: const Text('Buka Pengaturan'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Buka Pengaturan'));
        await tester.pumpAndSettle();

        final vacationSwitch = find.byType(Switch);
        await tester.ensureVisible(vacationSwitch.last);
        await tester.tap(vacationSwitch.last);
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Simpan Jadwal Praktik'));
        await tester.tap(find.text('Simpan Jadwal Praktik'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();

        expect(fakeDs.saveScheduleCount, 1);
        expect(fakeAuth.availabilityUpdates, [false]);
        expect(fakeAuth.lastAppliedOnline, isFalse);
        expect(fakeAuth.state.value?.isOnline, isFalse);
        expect(find.text('Buka Pengaturan'), findsOneWidget);
      },
    );
  });

  group('CounselorHomeScreen direct timeline & booked patient display', () {
    testWidgets(
      'fetches counselor/me/timeline directly and shows who booked that day',
      (WidgetTester tester) async {
        const timeline = CounselorDailyTimelineEntity(
          counselorId: 'c-sync-1',
          date: '2026-11-23',
          isActive: true,
          isOnline: true,
          operatingStart: '10:00',
          operatingEnd: '16:00',
          bufferTimeMinutes: 15,
          blockedRanges: [
            CounselorBlockedRangeEntity(
              start: '09:00',
              end: '09:30',
              type: 'booked',
              label: 'Terbooking',
            ),
          ],
          availableWindows: [
            CounselorTimeRangeEntity(start: '10:00', end: '16:00'),
          ],
          bookedSessions: [
            CounselorBookedSessionEntity(
              sessionId: 'sess-book-1',
              sessionCode: 'EVA-BOOK-1',
              patientId: 'pat-1',
              patientName: 'Rina Kartika',
              start: '09:00',
              end: '09:30',
              durationMinutes: 30,
              status: 'scheduled',
              complaints: 'Sulit tidur seminggu terakhir',
            ),
          ],
        );

        final fakeDs = _FakeScheduleProfileDataSource(
          scheduleConfig: buildCustomScheduleConfig(),
          timeline: timeline,
        );
        final fakeAuth = _FakeSyncAuthNotifier(testUser);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              counselorProfileDataSourceProvider.overrideWithValue(fakeDs),
              authStateProvider.overrideWith((ref) => fakeAuth),
              patientsListProvider.overrideWith((ref) async => const []),
              financialSummaryProvider.overrideWith(
                (ref) async => const FinancialSummaryEntity(
                  availableBalance: 0,
                  pendingClearingBalance: 0,
                  lockedWithdrawalBalance: 0,
                  totalEarningsThisMonth: 0,
                  totalWithdrawn: 0,
                ),
              ),
              unreadNotificationsCountProvider.overrideWithValue(0),
            ],
            child: const MaterialApp(
              home: CounselorHomeScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(fakeDs.fetchTimelineCount, greaterThanOrEqualTo(1));
        expect(find.text('10:00 - 16:00 WIB'), findsOneWidget);
        expect(find.text('Aktif • Tanpa Jam Istirahat'), findsOneWidget);
        expect(find.text('Rina Kartika'), findsOneWidget);
        expect(find.text('09:00 - 09:30'), findsOneWidget);
        expect(find.text('Sulit tidur seminggu terakhir'), findsOneWidget);
      },
    );
  });
}

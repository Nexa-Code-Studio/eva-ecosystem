import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eva_counselor_mobile/features/auth/domain/entities/psychologist_user_entity.dart';
import 'package:eva_counselor_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:eva_counselor_mobile/features/profile/presentation/screens/counselor_profile_screen.dart';
import 'package:eva_counselor_mobile/features/profile/presentation/screens/counselor_schedule_settings_screen.dart';
import 'package:eva_counselor_mobile/features/profile/presentation/widgets/counselor_profile_schedule_card.dart';
import 'package:eva_counselor_mobile/features/profile/presentation/widgets/counselor_external_api_key_modal.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('Psychologist Schedule & External API Key Tests', () {
    test('Peer Volunteer role cannot configure offline practice or use API Key', () {
      const volunteer = PsychologistUserEntity(
        id: 'vol-001',
        fullName: 'Budi Volunteer',
        titleDegree: 'Relawan Sebaya',
        email: 'budi@volunteer.eva.id',
        strNumber: 'VOL-PEER',
        association: 'Teman Curhat',
        specializations: ['Curhat Teman'],
        yearsOfExperience: 1,
        consultationRatePerHour: 0,
        verificationStatus: VerificationStatus.verified,
        role: CounselorRole.peerVolunteer,
        isOnlinePracticeEnabled: true,
        isOfflinePracticeEnabled: false,
        employeeNip: 'VOL-2026-001',
        externalApiKey: null,
      );

      expect(volunteer.isVolunteer, isTrue);
      expect(volunteer.canConfigureOffline, isFalse);
      expect(volunteer.isOfflinePracticeEnabled, isFalse);
      expect(volunteer.externalApiKey, isNull);
    });

    test('Partner psychologist offline practice is managed by partner via web', () {
      const partner = PsychologistUserEntity(
        id: 'partner-001',
        fullName: 'dr. Sarah Jenkins',
        titleDegree: 'M.Psi., Psikolog',
        email: 'sarah@mitra.eva.id',
        strNumber: 'STR-MITRA-99',
        association: 'HIMPSI',
        specializations: ['Klinis'],
        yearsOfExperience: 5,
        consultationRatePerHour: 180000,
        verificationStatus: VerificationStatus.verified,
        role: CounselorRole.professionalPartner,
        partnerName: 'RS Mitra Sehati',
        isOnlinePracticeEnabled: true,
        isOfflinePracticeEnabled: true,
        offlinePlaceName: 'RS Mitra Sehati - Unit Poliklinik Jiwa & Psikologi',
        offlineAddress: 'Jl. Gatot Subroto No. 128, Lt. 3',
        offlineCity: 'Jakarta Selatan',
        employeeNip: '198507202015022003',
        externalApiKey: 'eva_pat_live_partner_token_xyz',
      );

      expect(partner.isPartner, isTrue);
      expect(partner.canConfigureOffline, isTrue);
      expect(partner.isOfflineManagedByPartner, isTrue);
      expect(partner.offlinePlaceName, contains('RS Mitra Sehati'));
      expect(partner.employeeNip, equals('198507202015022003'));
      expect(partner.externalApiKey, isNotNull);
    });

    test('Independent psychologist can toggle offline, update address & manage API Key', () {
      PsychologistUserEntity user = const PsychologistUserEntity(
        id: 'ind-001',
        fullName: 'Sarah Anindya',
        titleDegree: 'M.Psi., Psikolog Klinis',
        email: 'sarah@psikolog.eva.id',
        strNumber: 'STR-PK-12345',
        association: 'HIMPSI',
        specializations: ['Kecemasan'],
        yearsOfExperience: 6,
        consultationRatePerHour: 200000,
        verificationStatus: VerificationStatus.verified,
        role: CounselorRole.professionalIndependent,
        isOnlinePracticeEnabled: true,
        isOfflinePracticeEnabled: false,
        employeeNip: '198804122019032001',
      );

      expect(user.isIndependent, isTrue);
      expect(user.canConfigureOffline, isTrue);
      expect(user.isOfflineManagedByPartner, isFalse);
      expect(user.isOfflinePracticeEnabled, isFalse);

      // 1. Toggle offline practice to true
      user = user.copyWith(isOfflinePracticeEnabled: true);
      expect(user.isOfflinePracticeEnabled, isTrue);

      // 2. Set practice address
      user = user.copyWith(
        offlinePlaceName: 'Biro Psikologi Mandiri Anindya',
        offlineAddress: 'Jl. Menteng Raya No. 42',
        offlineCity: 'Jakarta Pusat',
        offlineNotes: 'Lantai 2, Ruang Melati',
      );
      expect(user.offlinePlaceName, equals('Biro Psikologi Mandiri Anindya'));
      expect(user.offlineCity, equals('Jakarta Pusat'));

      // 3. Set offline schedule days and hours
      user = user.copyWith(
        offlineScheduleDays: ['Sel', 'Kam', 'Sab'],
        offlineStartTime: '10:00',
        offlineEndTime: '16:00',
      );
      expect(user.offlineScheduleDays, contains('Kam'));
      expect(user.offlineStartTime, equals('10:00'));

      // 4. Generate GitHub-style API Key
      final generatedKey = 'eva_pat_live_${DateTime.now().millisecondsSinceEpoch}';
      user = user.copyWith(
        externalApiKey: generatedKey,
        externalApiKeyCreatedAt: DateTime.now(),
      );
      expect(user.externalApiKey, startsWith('eva_pat_live_'));
    });

    test('AuthStateNotifier updates practice modes, address, and API keys correctly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Login to establish session
      await container.read(authStateProvider.notifier).login('sarah@psikolog.eva.id', 'password');
      var state = container.read(authStateProvider).value;
      expect(state, isNotNull);

      // Update practice modes
      container.read(authStateProvider.notifier).updatePracticeModes(
            isOnline: true,
            isOffline: true,
          );
      state = container.read(authStateProvider).value;
      expect(state?.isOnlinePracticeEnabled, isTrue);
      expect(state?.isOfflinePracticeEnabled, isTrue);

      // Update offline address
      container.read(authStateProvider.notifier).updateOfflinePracticeAddress(
            placeName: 'Klinik Mandiri Baru',
            address: 'Jl. Sudirman No. 10',
            city: 'Jakarta Selatan',
            notes: 'Ruang A',
          );
      state = container.read(authStateProvider).value;
      expect(state?.offlinePlaceName, equals('Klinik Mandiri Baru'));
      expect(state?.offlineAddress, equals('Jl. Sudirman No. 10'));

      // Update offline schedule
      container.read(authStateProvider.notifier).updateOfflineSchedule(
            days: ['Sen', 'Rab', 'Jum'],
            startTime: '13:00',
            endTime: '18:00',
          );
      state = container.read(authStateProvider).value;
      expect(state?.offlineScheduleDays, equals(['Sen', 'Rab', 'Jum']));
      expect(state?.offlineStartTime, equals('13:00'));

      // Generate or rotate API key
      container.read(authStateProvider.notifier).generateOrRotateExternalApiKey();
      state = container.read(authStateProvider).value;
      expect(state?.externalApiKey, startsWith('eva_pat_live_'));
      expect(state?.externalApiKeyCreatedAt, isNotNull);

      // Simulate external schedule sync
      final syncCount = await container.read(authStateProvider.notifier).syncExternalSchedules();
      state = container.read(authStateProvider).value;
      expect(syncCount, greaterThan(0));
      expect(state?.externalApiLastSyncAt, isNotNull);
      expect(state?.externalSyncCount, equals(syncCount));

      // Revoke API key
      container.read(authStateProvider.notifier).revokeExternalApiKey();
      state = container.read(authStateProvider).value;
      expect(state?.externalApiKey, isNull);
      expect(state?.externalApiKeyCreatedAt, isNull);
    });

    testWidgets('CounselorProfileScheduleCard renders Online & Offline mode switches', (tester) async {
      const user = PsychologistUserEntity(
        id: 'test-counselor',
        fullName: 'Sarah Anindya',
        titleDegree: 'M.Psi., Psikolog',
        email: 'sarah@psikolog.eva.id',
        strNumber: 'STR-123',
        association: 'HIMPSI',
        specializations: ['Klinis'],
        yearsOfExperience: 5,
        consultationRatePerHour: 200000,
        verificationStatus: VerificationStatus.verified,
        role: CounselorRole.professionalIndependent,
        isOnlinePracticeEnabled: true,
        isOfflinePracticeEnabled: true,
        offlinePlaceName: 'Biro Psikologi Mandiri Anindya',
        offlineAddress: 'Jl. Menteng Raya No. 42',
        offlineCity: 'Jakarta Pusat',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CounselorProfileScheduleCard(
                days: const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'],
                activeDays: const {'Sen', 'Sel', 'Rab'},
                startTime: const TimeOfDay(hour: 9, minute: 0),
                endTime: const TimeOfDay(hour: 17, minute: 0),
                workingHours: '09:00 - 17:00 WIB',
                sessionDuration: 50,
                bufferTime: 15,
                isVacationMode: false,
                user: user,
                onDaysChanged: (_) {},
                onHoursChanged: (_, _) {},
                onDurationBufferChanged: (_, _) {},
                onVacationModeChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Mode Layanan Praktik'), findsOneWidget);
      expect(find.text('Telekonseling Online'), findsOneWidget);
      expect(find.text('Praktik Tatap Muka'), findsOneWidget);
      expect(find.text('Opsional'), findsOneWidget);
      expect(find.text('Alamat Praktik Tatap Muka'), findsOneWidget);
      expect(find.text('Biro Psikologi Mandiri Anindya'), findsOneWidget);
      expect(find.text('Ubah Alamat'), findsOneWidget);
    });

    testWidgets('CounselorProfileScheduleCard for volunteer shows clean info card without offline options', (tester) async {
      const volunteer = PsychologistUserEntity(
        id: 'vol-test',
        fullName: 'Raka Sebaya',
        titleDegree: 'Relawan Sebaya',
        email: 'raka@volunteer.eva.id',
        strNumber: 'VOL-PEER',
        association: 'Teman Curhat',
        specializations: ['Curhat'],
        yearsOfExperience: 1,
        consultationRatePerHour: 0,
        verificationStatus: VerificationStatus.verified,
        role: CounselorRole.peerVolunteer,
        isOnlinePracticeEnabled: true,
        isOfflinePracticeEnabled: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CounselorProfileScheduleCard(
                days: const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'],
                activeDays: const {'Sen', 'Sel', 'Rab'},
                startTime: const TimeOfDay(hour: 9, minute: 0),
                endTime: const TimeOfDay(hour: 17, minute: 0),
                workingHours: '09:00 - 17:00 WIB',
                sessionDuration: 50,
                bufferTime: 15,
                isVacationMode: false,
                user: volunteer,
                onDaysChanged: (_) {},
                onHoursChanged: (_, _) {},
                onDurationBufferChanged: (_, _) {},
                onVacationModeChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Relawan Teman Sebaya • Khusus Daring'), findsOneWidget);
      expect(find.text('Mode Layanan Praktik'), findsNothing);
      expect(find.text('Praktik Tatap Muka'), findsNothing);
      expect(find.text('Alamat Praktik Tatap Muka'), findsNothing);
    });

    testWidgets('CounselorScheduleSettingsScreen renders dedicated page with practice address & online schedule', (tester) async {
      const user = PsychologistUserEntity(
        id: 'test-counselor',
        fullName: 'Sarah Anindya',
        titleDegree: 'M.Psi., Psikolog',
        email: 'sarah@psikolog.eva.id',
        strNumber: 'STR-123',
        association: 'HIMPSI',
        specializations: ['Klinis'],
        yearsOfExperience: 5,
        consultationRatePerHour: 200000,
        verificationStatus: VerificationStatus.verified,
        role: CounselorRole.professionalIndependent,
        isOnlinePracticeEnabled: true,
        isOfflinePracticeEnabled: true,
        offlinePlaceName: 'Biro Psikologi Mandiri Anindya',
        offlineAddress: 'Jl. Menteng Raya No. 42',
        offlineCity: 'Jakarta Pusat',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => _MockAuthStateNotifier(user)),
          ],
          child: const MaterialApp(
            home: CounselorScheduleSettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Jadwal & Lokasi Praktik'), findsOneWidget);
      expect(find.text('Pilih Mode Layanan Konseling'), findsOneWidget);
      expect(find.text('Telekonseling Online'), findsOneWidget);
      expect(find.text('Praktik Tatap Muka'), findsOneWidget);
      expect(find.text('Opsional'), findsOneWidget);
      expect(find.text('Hari Praktik Daring Aktif:'), findsOneWidget);
      expect(find.text('Hari Praktik Offline Aktif:'), findsOneWidget);
      // Day chips do not use checkmark icons in both online & offline
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(find.text('Alamat & Lokasi Praktik Offline'), findsOneWidget);
      expect(find.text('Nama Tempat / Fasilitas Praktik'), findsOneWidget);
      expect(find.text('Simpan Perubahan Jadwal'), findsOneWidget);
    });

    testWidgets('CounselorProfileScreen renders clean menu card with calendar icon and no inner arrow in badge', (tester) async {
      const user = PsychologistUserEntity(
        id: 'test-counselor',
        fullName: 'Sarah Anindya',
        titleDegree: 'M.Psi., Psikolog',
        email: 'sarah@psikolog.eva.id',
        strNumber: 'STR-123',
        association: 'HIMPSI',
        specializations: ['Klinis'],
        yearsOfExperience: 5,
        consultationRatePerHour: 200000,
        verificationStatus: VerificationStatus.verified,
        role: CounselorRole.professionalIndependent,
        isOnlinePracticeEnabled: true,
        isOfflinePracticeEnabled: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => _MockAuthStateNotifier(user)),
          ],
          child: const MaterialApp(
            home: CounselorProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Jadwal & Lokasi Praktik'), findsNWidgets(2)); // section header + menu title
      expect(find.byIcon(Icons.calendar_month_rounded), findsNWidgets(2)); // section header + card icon
      // Inner arrow in badge is removed; only menu card trailing chevron remains
      expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsNothing);
    });

    testWidgets('CounselorExternalApiKeyModal renders NIP Pegawai and API Key options', (tester) async {
      const user = PsychologistUserEntity(
        id: 'test-counselor',
        fullName: 'Sarah Anindya',
        titleDegree: 'M.Psi., Psikolog',
        email: 'sarah@psikolog.eva.id',
        strNumber: 'STR-123',
        association: 'HIMPSI',
        specializations: ['Klinis'],
        yearsOfExperience: 5,
        consultationRatePerHour: 200000,
        verificationStatus: VerificationStatus.verified,
        role: CounselorRole.professionalIndependent,
        employeeNip: '198804122019032001',
        externalApiKey: 'eva_pat_live_9c82df09a12e557b4412',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Consumer(
                  builder: (context, ref, _) => ElevatedButton(
                    onPressed: () => CounselorExternalApiKeyModal.show(
                      context,
                      user: user,
                      ref: ref,
                    ),
                    child: const Text('Buka Modal API Key'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Buka Modal API Key'));
      await tester.pumpAndSettle();

      expect(find.text('Integrasi API Jadwal Eksternal'), findsOneWidget);
      expect(find.text('IDENTIFIER PEGAWAI (X-EMPLOYEE-NIP)'), findsOneWidget);
      expect(find.text('198804122019032001'), findsOneWidget);
      expect(find.text('Salin NIP'), findsOneWidget);
      expect(find.text('PERSONAL ACCESS TOKEN (API KEY)'), findsOneWidget);
      expect(find.text('CUPLIKAN INTEGRASI cURL'), findsOneWidget);
      expect(find.text('Uji Sinkronisasi'), findsOneWidget);
      expect(find.text('Selesai'), findsOneWidget);
    });
  });
}

class _MockAuthStateNotifier extends StateNotifier<AsyncValue<PsychologistUserEntity?>>
    implements AuthStateNotifier {
  _MockAuthStateNotifier(PsychologistUserEntity user) : super(AsyncValue.data(user));

  @override
  Future<void> checkAuthSession() async {}

  @override
  Future<void> login(String email, String password) async {}

  @override
  Future<void> register({
    required String fullName,
    required String titleDegree,
    required String email,
    required String password,
    required String strNumber,
    required String association,
    required List<String> specializations,
    required int yearsOfExperience,
    required int consultationRate,
    required String certificateDocFileName,
    String counselorRole = 'professional_independent',
    String? partnerName,
    int sessionDurationMinutes = 50,
    int coinsPerSession = 150,
  }) async {}

  @override
  Future<void> activatePartnerAccount({
    required String email,
    required String password,
    required String partnerName,
    required String fullName,
    String? strNumber,
  }) async {}

  @override
  void switchRole(CounselorRole newRole, {String? partnerName}) {}

  @override
  void updatePracticeModes({required bool isOnline, required bool isOffline}) {}

  @override
  void updateOfflinePracticeAddress({
    required String placeName,
    required String address,
    required String city,
    String? notes,
  }) {}

  @override
  void updateOfflineSchedule({
    required List<String> days,
    required String startTime,
    required String endTime,
  }) {}

  @override
  void generateOrRotateExternalApiKey() {}

  @override
  void revokeExternalApiKey() {}

  @override
  Future<int> syncExternalSchedules() async => 2;

  @override
  void updateSessionSettings({
    required int sessionDurationMinutes,
    required int coinsPerSession,
  }) {}

  @override
  void upgradeToProfessional({
    required String strNumber,
    required String association,
    required String certificateDocFileName,
    required CounselorRole newRole,
    String? partnerName,
    int sessionDurationMinutes = 50,
    int coinsPerSession = 150,
  }) {}

  @override
  void syncDriveBackup({required String email, required String frequency}) {}

  @override
  void redeemCoins(int coins) {}

  @override
  Future<void> toggleAvailability(bool isOnline) async {}

  @override
  Future<void> logout() async {}
}

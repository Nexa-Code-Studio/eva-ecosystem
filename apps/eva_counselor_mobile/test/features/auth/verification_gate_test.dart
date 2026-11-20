import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eva_counselor_mobile/features/auth/data/datasources/mock_auth_datasource.dart';
import 'package:eva_counselor_mobile/features/auth/data/models/psychologist_auth_dto.dart';
import 'package:eva_counselor_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:eva_counselor_mobile/features/auth/domain/entities/psychologist_user_entity.dart';
import 'package:eva_counselor_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:eva_counselor_mobile/features/auth/presentation/screens/verification_pending_screen.dart';
import 'package:eva_counselor_mobile/features/auth/presentation/screens/verification_rejected_screen.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('Psychologist Verification Gate & Onboarding Tests', () {
    test('MockAuthDataSource registers individual professional with pending verification', () async {
      final dataSource = MockAuthDataSource();

      const registerDto = PsychologistRegisterRequestDto(
        fullName: 'Dr. Sarah Lestari, M.Psi., Psikolog',
        titleDegree: 'M.Psi., Psikolog Klinis',
        email: 'sarah.lestari@gmail.com',
        password: 'securePassword123',
        strNumber: 'STR-PK-2026-123456',
        association: 'HIMPSI',
        specializations: ['Kecemasan Dewasa', 'Burnout'],
        yearsOfExperience: 5,
        consultationRate: 150000,
        certificateDocFileName: 'STR_Sarah_Verified.pdf',
        counselorRole: 'professional_independent',
        sessionDurationMinutes: 30,
        coinsPerSession: 150,
      );

      final registered = await dataSource.register(registerDto);
      expect(registered.verificationStatus, equals('pending'));
      expect(registered.counselorRole, equals('professional_independent'));
      expect(registered.email, equals('sarah.lestari@gmail.com'));
    });

    test('AuthStateNotifier uploadCertificate updates certificate and resets to pending', () async {
      final dataSource = MockAuthDataSource();
      final repository = AuthRepositoryImpl(dataSource: dataSource);
      final notifier = AuthStateNotifier(repository);

      // Log in as psychologist to establish session
      await notifier.login('sarah@psikolog.eva.id', 'password123');

      await notifier.uploadCertificate('STR_Revisi_2026.pdf');
      final updated = notifier.state.value;
      expect(updated, isNotNull);
      expect(updated!.certificateDocUrl, equals('STR_Revisi_2026.pdf'));
      expect(updated.verificationStatus, equals(VerificationStatus.pending));
    });

    testWidgets('VerificationPendingScreen displays pending verification status and info', (tester) async {
      const pendingUser = PsychologistUserEntity(
        id: 'counselor-pending-1',
        fullName: 'Dr. Budi Santoso',
        titleDegree: 'M.Psi., Psikolog',
        email: 'budi.santoso@gmail.com',
        strNumber: 'STR-PK-998877',
        association: 'HIMPSI',
        specializations: ['Keluarga & Pernikahan'],
        yearsOfExperience: 4,
        consultationRatePerHour: 150000,
        verificationStatus: VerificationStatus.pending,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => _TestAuthStateNotifier(pendingUser)),
          ],
          child: const MaterialApp(
            home: VerificationPendingScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Dokumen Sedang Ditinjau'), findsOneWidget);
      expect(find.text('Dr. Budi Santoso'), findsOneWidget);
      expect(find.text('STR-PK-998877'), findsOneWidget);
      expect(find.text('Periksa Status Verifikasi'), findsOneWidget);
    });

    testWidgets('VerificationRejectedScreen displays rejection info and revision upload button', (tester) async {
      const rejectedUser = PsychologistUserEntity(
        id: 'counselor-rejected-1',
        fullName: 'Dr. Maya Putri',
        titleDegree: 'M.Psi., Psikolog',
        email: 'maya.putri@gmail.com',
        strNumber: 'STR-PK-112233',
        association: 'HIMPSI',
        specializations: ['Trauma & PTSD'],
        yearsOfExperience: 6,
        consultationRatePerHour: 150000,
        verificationStatus: VerificationStatus.rejected,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => _TestAuthStateNotifier(rejectedUser)),
          ],
          child: const MaterialApp(
            home: VerificationRejectedScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Verifikasi Perlu Perbaikan'), findsOneWidget);
      expect(find.text('Unggah Dokumen Perbaikan'), findsOneWidget);
      expect(find.text('Pilih Dokumen Scan STR/SIPP Baru (PDF/JPG)'), findsOneWidget);
      expect(find.text('Kirim Dokumen Perbaikan'), findsOneWidget);
    });
  });
}

class _TestAuthStateNotifier extends StateNotifier<AsyncValue<PsychologistUserEntity?>>
    implements AuthStateNotifier {
  _TestAuthStateNotifier(PsychologistUserEntity user) : super(AsyncValue.data(user));

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
    String strNumber = '',
    String? sipNumber,
    String documentType = 'str',
    String issuingInstitution = 'Kemenkes RI',
    String documentExpiryDate = 'Seumur Hidup',
    String lastEducation = 'S2 Magister Psikologi Profesi',
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
  void addCoins(int coins) {}

  @override
  void setVerificationStatus(VerificationStatus status) {}

  @override
  Future<void> updateProfile({
    String? fullName,
    String? titleDegree,
    String? profilePhotoUrl,
  }) async {}

  @override
  Future<void> updateBankDetails({
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  }) async {}

  @override
  Future<void> toggleAvailability(bool isOnline) async {}

  @override
  Future<void> loadProfile() async {}

  @override
  Future<void> uploadCertificate(String newCertificateFileName) async {}

  @override
  Future<void> updateAvailability(bool isOnline) async {}

  @override
  Future<void> logout() async {}
}

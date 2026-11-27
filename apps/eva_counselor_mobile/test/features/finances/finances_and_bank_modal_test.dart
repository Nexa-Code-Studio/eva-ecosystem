import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eva_counselor_mobile/core/theme/app_theme.dart';
import 'package:eva_counselor_mobile/features/auth/domain/entities/psychologist_user_entity.dart';
import 'package:eva_counselor_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:eva_counselor_mobile/features/finances/domain/entities/bank_account_entity.dart';
import 'package:eva_counselor_mobile/features/finances/domain/entities/transaction_entity.dart';
import 'package:eva_counselor_mobile/features/finances/presentation/providers/finance_provider.dart';
import 'package:eva_counselor_mobile/features/finances/presentation/screens/transaction_history_screen.dart';
import 'package:eva_counselor_mobile/features/profile/presentation/widgets/counselor_bank_account_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const mockUser = PsychologistUserEntity(
    id: 'counselor-1',
    fullName: 'dr. Sarah Amelia, Sp.KJ',
    titleDegree: 'Sp.KJ',
    email: 'sarah.amelia@eva.id',
    strNumber: 'STR-12345678',
    association: 'HIMPSI',
    specializations: ['CBT', 'Anxiety'],
    yearsOfExperience: 5,
    consultationRatePerHour: 150000,
    role: CounselorRole.professionalIndependent,
    verificationStatus: VerificationStatus.verified,
    coinBalance: 850,
    coinsPerSession: 150,
    sessionDurationMinutes: 30,
    bankName: 'Bank Mandiri',
    bankAccountNumber: '1234567890',
    bankAccountHolder: 'dr. Sarah Amelia',
  );

  Widget createTestWidget({required Widget child}) {
    return ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => _FakeAuthStateNotifier(mockUser)),
        financialSummaryProvider.overrideWith((ref) async {
          return const FinancialSummaryEntity(
            availableBalance: 850000,
            pendingClearingBalance: 127500,
            lockedWithdrawalBalance: 0,
            totalEarningsThisMonth: 977500,
            totalWithdrawn: 0,
          );
        }),
        currentBankAccountProvider.overrideWith((ref) async {
          return const BankAccountEntity(
            id: 'bank-acc-1',
            bankCode: 'mandiri',
            bankName: 'Bank Mandiri',
            accountNumberMasked: '****3333',
            accountHolderName: 'dr. Sarah Amelia',
            verificationStatus: 'verified',
            isActive: true,
          );
        }),
        transactionsListProvider.overrideWith((ref) async {
          return [
            TransactionEntity(
              id: 'TRX-1',
              patientName: 'Rian Pratama',
              sessionType: 'Telekonsultasi Video (30 Menit)',
              date: DateTime(2026, 11, 25, 10, 0),
              amount: 150000,
              adminFee: 30000,
              netEarnings: 120000,
              status: TransactionStatus.completed,
            ),
            TransactionEntity(
              id: 'TRX-2',
              patientName: 'Pencairan Honorarium (Mandiri ****3333)',
              sessionType: 'Transfer Bank Pencairan Honorarium',
              date: DateTime(2026, 11, 24, 14, 0),
              amount: 250000,
              adminFee: 5000,
              netEarnings: 245000,
              status: TransactionStatus.payoutRequested,
              bankAccountInfo: 'Bank Mandiri • ****3333',
            ),
          ];
        }),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: child,
      ),
    );
  }

  group('TransactionHistoryScreen Widget Tests', () {
    testWidgets('renders balance overview card with IDR hierarchy and breakdown', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const TransactionHistoryScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Saldo Honorarium Konselor'), findsOneWidget);
      expect(find.text('Saldo Siap Tarik'), findsOneWidget);
      expect(find.text('850.000'), findsOneWidget);
      expect(find.text('Menunggu Kliring'), findsOneWidget);
      expect(find.text('Rp 127.500'), findsOneWidget);
      expect(find.text('Dalam Pencairan'), findsOneWidget);
      expect(find.text('Rp 0'), findsOneWidget);
      expect(find.text('Total Bulan Ini'), findsOneWidget);
      expect(find.text('Rp 977.500'), findsOneWidget);
      expect(find.text('Tarik Dana / Pencairan Honorarium'), findsOneWidget);
    });

    testWidgets('renders filter pills and transactions list with badges', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const TransactionHistoryScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Honorarium Masuk'), findsOneWidget);
      expect(find.text('Pencairan Dana'), findsOneWidget);

      expect(find.text('Rian Pratama'), findsOneWidget);
      expect(find.text('+Rp 120.000'), findsOneWidget);
      expect(find.text('Selesai'), findsOneWidget);

      expect(find.text('Pencairan Honorarium (Mandiri ****3333)'), findsOneWidget);
      expect(find.text('-Rp 250.000'), findsOneWidget);
      expect(find.text('Diproses'), findsOneWidget);
    });

    testWidgets('filtering by Honorarium Masuk shows only completed sessions', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const TransactionHistoryScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Honorarium Masuk'));
      await tester.pumpAndSettle();

      expect(find.text('Rian Pratama'), findsOneWidget);
      expect(find.text('Pencairan Honorarium (Mandiri ****3333)'), findsNothing);
    });
  });

  group('CounselorBankAccountModal Widget Tests', () {
    testWidgets('modal renders verified bank card and edit button', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => CounselorBankAccountModal.show(ctx),
                child: const Text('Buka Modal'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Buka Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Rekening Bank Pencairan'), findsOneWidget);
      expect(find.text('Bank Mandiri'), findsOneWidget);
      expect(find.text('****3333'), findsOneWidget);
      expect(find.text('TERVERIFIKASI ✅'), findsOneWidget);
      expect(find.text('Ubah Rekening Bank'), findsOneWidget);
    });
  });
}

class _FakeAuthStateNotifier extends StateNotifier<AsyncValue<PsychologistUserEntity?>>
    implements AuthStateNotifier {
  _FakeAuthStateNotifier(PsychologistUserEntity user) : super(AsyncValue.data(user));

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
    String? strIssuingInstitution,
    String? strExpiryDate,
    String? strDocFileName,
    String? sipIssuingInstitution,
    String? sipExpiryDate,
    String? sipDocFileName,
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
    String? breakStartTime,
    String? breakEndTime,
  }) {}

  @override
  Future<void> applyScheduleConfig({
    required Map<String, dynamic> scheduleConfig,
    required int bufferTimeMinutes,
    required bool isOnline,
  }) async {}

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
  void syncCoinBalance(int newBalance) {}

  @override
  Future<void> uploadAvatar({required List<int> bytes, required String filename}) async {}

  @override
  void syncVerifiedBankAccount({
    required String bankName,
    required String accountNumberMasked,
    required String accountHolderName,
  }) {}

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

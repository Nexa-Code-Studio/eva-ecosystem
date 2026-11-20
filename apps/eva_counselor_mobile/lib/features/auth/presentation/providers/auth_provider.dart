import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';
import '../../domain/entities/psychologist_user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/datasources/auth_datasource.dart';
import '../../data/datasources/mock_auth_datasource.dart';
import '../../data/datasources/remote_auth_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';

/// Data source provider dynamically switching based on AppConfig.useMockData
final authDataSourceProvider = Provider<AuthDataSource>((ref) {
  if (AppConfig.useMockData) {
    return MockAuthDataSource();
  }
  return RemoteAuthDataSource();
});

/// Repository provider
final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  final dataSource = ref.watch(authDataSourceProvider);
  return AuthRepositoryImpl(dataSource: dataSource);
});

/// Current active psychologist profile state notifier
class AuthStateNotifier extends StateNotifier<AsyncValue<PsychologistUserEntity?>> {
  final IAuthRepository _repository;

  AuthStateNotifier(this._repository) : super(const AsyncValue.loading()) {
    checkAuthSession();
  }

  Future<void> checkAuthSession() async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.getCurrentProfile();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.login(email, password);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

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
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.register(
        fullName: fullName,
        titleDegree: titleDegree,
        email: email,
        password: password,
        strNumber: strNumber,
        sipNumber: sipNumber,
        documentType: documentType,
        issuingInstitution: issuingInstitution,
        documentExpiryDate: documentExpiryDate,
        lastEducation: lastEducation,
        strIssuingInstitution: strIssuingInstitution,
        strExpiryDate: strExpiryDate,
        strDocFileName: strDocFileName,
        sipIssuingInstitution: sipIssuingInstitution,
        sipExpiryDate: sipExpiryDate,
        sipDocFileName: sipDocFileName,
        association: association,
        specializations: specializations,
        yearsOfExperience: yearsOfExperience,
        consultationRate: consultationRate,
        certificateDocFileName: certificateDocFileName,
        counselorRole: counselorRole,
        partnerName: partnerName,
        sessionDurationMinutes: sessionDurationMinutes,
        coinsPerSession: coinsPerSession,
      );
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> activatePartnerAccount({
    required String email,
    required String password,
    required String partnerName,
    required String fullName,
    String? strNumber,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.register(
        fullName: fullName,
        titleDegree: 'M.Psi., Psikolog Klinis',
        email: email,
        password: password,
        strNumber: strNumber ?? 'STR-MITRA-2026-99',
        association: 'Himpunan Psikologi Indonesia (HIMPSI)',
        specializations: [
          'Kecemasan Dewasa',
          'Konseling Hubungan & Keluarga',
          'Manajemen Stres',
        ],
        yearsOfExperience: 4,
        consultationRate: 180000,
        certificateDocFileName: 'STR_Mitra_Verified.pdf',
        counselorRole: 'professional_partner',
        partnerName: partnerName,
        sessionDurationMinutes: 50,
        coinsPerSession: 180,
      );
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void switchRole(CounselorRole newRole, {String? partnerName}) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(
      role: newRole,
      partnerName: partnerName ?? (newRole == CounselorRole.professionalPartner ? 'Klinik Sehati Mitra' : null),
      coinsPerSession: newRole == CounselorRole.peerVolunteer ? 0 : current.coinsPerSession,
      isOfflinePracticeEnabled: newRole == CounselorRole.peerVolunteer
          ? false
          : current.isOfflinePracticeEnabled,
      externalApiKey: newRole == CounselorRole.peerVolunteer
          ? null
          : (current.externalApiKey ?? 'eva_pat_live_9c82df09a12e557b4412'),
      offlinePlaceName: newRole == CounselorRole.professionalPartner
          ? 'RS Mitra Sehati - Unit Poliklinik Jiwa'
          : (newRole == CounselorRole.peerVolunteer ? null : current.offlinePlaceName),
      offlineAddress: newRole == CounselorRole.professionalPartner
          ? 'Jl. Gatot Subroto No. 128, Gedung Poliklinik Lt. 3'
          : (newRole == CounselorRole.peerVolunteer ? null : current.offlineAddress),
    ));
  }

  void updatePracticeModes({
    required bool isOnline,
    required bool isOffline,
  }) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(
      isOnlinePracticeEnabled: isOnline,
      isOfflinePracticeEnabled: isOffline,
    ));
  }

  void updateOfflinePracticeAddress({
    required String placeName,
    required String address,
    required String city,
    String? notes,
  }) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(
      offlinePlaceName: placeName,
      offlineAddress: address,
      offlineCity: city,
      offlineNotes: notes,
    ));
  }

  void updateOfflineSchedule({
    required List<String> days,
    required String startTime,
    required String endTime,
  }) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(
      offlineScheduleDays: days,
      offlineStartTime: startTime,
      offlineEndTime: endTime,
    ));
  }

  void generateOrRotateExternalApiKey() {
    final current = state.value;
    if (current == null) return;
    final hex = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    final token = 'eva_pat_live_${hex}9a72b4c10';
    state = AsyncValue.data(current.copyWith(
      externalApiKey: token,
      externalApiKeyCreatedAt: DateTime.now(),
    ));
  }

  void revokeExternalApiKey() {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(
      clearExternalApiKey: true,
    ));
  }

  Future<int> syncExternalSchedules() async {
    final current = state.value;
    if (current == null || current.externalApiKey == null) return 0;
    await Future.delayed(const Duration(milliseconds: 500));
    final newCount = (current.externalSyncCount > 0 ? current.externalSyncCount : 2) + 2;
    state = AsyncValue.data(current.copyWith(
      externalApiLastSyncAt: DateTime.now(),
      externalSyncCount: newCount,
    ));
    return newCount;
  }

  void updateSessionSettings({
    required int sessionDurationMinutes,
    required int coinsPerSession,
    String? breakStartTime,
    String? breakEndTime,
  }) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(
      sessionDurationMinutes: sessionDurationMinutes,
      coinsPerSession: coinsPerSession,
      isOnlinePracticeEnabled: true,
      isScheduleConfigured: true,
      breakStartTime: breakStartTime ?? current.breakStartTime,
      breakEndTime: breakEndTime ?? current.breakEndTime,
    ));
    _repository.setOnlineAvailability(true);
  }

  void upgradeToProfessional({
    required String strNumber,
    required String association,
    required String certificateDocFileName,
    required CounselorRole newRole,
    String? partnerName,
    int sessionDurationMinutes = 50,
    int coinsPerSession = 150,
  }) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(
      strNumber: strNumber,
      association: association,
      certificateDocUrl: certificateDocFileName,
      role: newRole,
      partnerName: partnerName,
      sessionDurationMinutes: sessionDurationMinutes,
      coinsPerSession: coinsPerSession,
      verificationStatus: VerificationStatus.verified,
    ));
  }

  void syncDriveBackup({
    required String email,
    required String frequency,
  }) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(
      googleDriveEmail: email,
      autoBackupFrequency: frequency,
      lastDriveBackup: DateTime.now(),
    ));
  }

  void redeemCoins(int coins) {
    final current = state.value;
    if (current == null) return;
    final newBalance = (current.coinBalance - coins).clamp(0, 999999);
    state = AsyncValue.data(current.copyWith(coinBalance: newBalance));
  }

  void addCoins(int coins) {
    final current = state.value;
    if (current == null) return;
    final newBalance = current.coinBalance + coins;
    state = AsyncValue.data(current.copyWith(coinBalance: newBalance));
  }

  void setVerificationStatus(VerificationStatus status) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(verificationStatus: status));
  }

  Future<void> updateProfile({
    String? fullName,
    String? titleDegree,
    String? profilePhotoUrl,
  }) async {
    final current = state.value;
    if (current == null) return;
    try {
      final updated = await _repository.updateProfile(
        fullName: fullName,
        titleDegree: titleDegree,
        profilePhotoUrl: profilePhotoUrl,
      );
      state = AsyncValue.data(updated);
    } catch (_) {
      state = AsyncValue.data(current.copyWith(
        fullName: fullName ?? current.fullName,
        titleDegree: titleDegree ?? current.titleDegree,
        profilePhotoUrl: profilePhotoUrl ?? current.profilePhotoUrl,
      ));
    }
  }

  Future<void> updateBankDetails({
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  }) async {
    final current = state.value;
    if (current == null) return;
    try {
      final updated = await _repository.updateBankDetails(
        bankName: bankName,
        accountNumber: accountNumber,
        accountHolder: accountHolder,
      );
      state = AsyncValue.data(updated);
    } catch (_) {
      state = AsyncValue.data(current.copyWith(
        bankName: bankName,
        bankAccountNumber: accountNumber,
        bankAccountHolder: accountHolder,
      ));
    }
  }

  Future<void> loadProfile() async {
    await checkAuthSession();
  }

  Future<void> uploadCertificate(String newCertificateFileName) async {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(
      certificateDocUrl: newCertificateFileName,
      verificationStatus: VerificationStatus.pending,
    ));
  }

  Future<void> updateAvailability(bool isOnline) async {
    await toggleAvailability(isOnline);
  }

  Future<void> toggleAvailability(bool isOnline) async {
    final current = state.value;
    if (current == null) return;
    // Optimistic UI update to ensure instantaneous response
    state = AsyncValue.data(current.copyWith(isOnline: isOnline));
    try {
      await _repository.setOnlineAvailability(isOnline);
    } catch (_) {
      state = AsyncValue.data(current);
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AsyncValue.data(null);
  }
}

final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AsyncValue<PsychologistUserEntity?>>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthStateNotifier(repo);
});

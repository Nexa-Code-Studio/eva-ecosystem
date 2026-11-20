import '../models/psychologist_auth_dto.dart';
import 'auth_datasource.dart';

class MockAuthDataSource implements AuthDataSource {
  bool _mockOnlineState = false;
  final Map<String, PsychologistProfileResponseDto> _registeredAccounts = {};
  static final Set<String> _configuredScheduleEmails = {
    'khoirotunnisa2507@gmail.com',
    'counselor@eva.id',
    'dr.sarah@eva.id',
  };
  PsychologistProfileResponseDto? _currentProfile;

  @override
  Future<PsychologistProfileResponseDto> login(
      PsychologistLoginRequestDto request) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final lowerEmail = request.email.toLowerCase().trim();

    if (_registeredAccounts.containsKey(lowerEmail)) {
      final acc = _registeredAccounts[lowerEmail]!;
      final isConfigured = _configuredScheduleEmails.contains(lowerEmail) || acc.isOnlinePracticeEnabled;
      _currentProfile = acc.copyWith(
        isOnline: _mockOnlineState,
        isOnlinePracticeEnabled: isConfigured,
      );
      return _currentProfile!;
    }

    final isPending = lowerEmail.contains('pending');
    final isRevision = lowerEmail.contains('revisi') || lowerEmail.contains('reject');

    final verificationStatus = isPending
        ? 'pending'
        : (isRevision ? 'need_revision' : 'verified');

    String displayName = 'Psikolog Mandiri';
    String titleDegree = 'S.Psi., M.Psi., Psikolog';
    String strNum = 'STR-PK-19980725-2026-01';

    if (lowerEmail.contains('khoirotun') || lowerEmail.contains('sarah')) {
      displayName = 'dr. Sarah Amelia';
      titleDegree = 'M.Psi., Psikolog';
      strNum = 'STR-PK-19980725-2026-01';
    } else if (isPending) {
      displayName = 'Dimas Wicaksono';
      titleDegree = 'M.Psi., Psikolog Klinis';
      strNum = 'STR-PK-19920115-PENDING';
    } else if (isRevision) {
      displayName = 'Clara Salsabila';
      titleDegree = 'M.Psi., Psikolog Klinis';
      strNum = 'STR-PK-19950310-REVISI';
    }

    _currentProfile = PsychologistProfileResponseDto(
      id: 'counselor-uuid-001',
      fullName: displayName,
      titleDegree: titleDegree,
      email: request.email,
      strNumber: strNum,
      association: 'Himpunan Psikologi Indonesia (HIMPSI)',
      specializations: const [
        'Kecemasan Dewasa & Burnout',
        'Manajemen Stres',
        'Konseling Hubungan & Keluarga',
      ],
      yearsOfExperience: 5,
      consultationRatePerHour: 200000,
      verificationStatus: verificationStatus,
      isOnline: _mockOnlineState,
      profilePhotoUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=400',
      certificateDocUrl: 'https://eva.nexacode.dev/docs/sample_str.pdf',
      token: 'mock-jwt-token-counselor-secret-xyz',
      counselorRole: 'professional_independent',
      partnerName: null,
      sessionDurationMinutes: 30,
      coinsPerSession: 150,
      coinBalance: 0,
      googleDriveEmail: request.email,
      employeeNip: '199807252026012001',
      isOnlinePracticeEnabled: true,
      isOfflinePracticeEnabled: true,
      offlinePlaceName: 'Biro Konsultasi Psikologi Mandiri',
      offlineAddress: 'Jl. Menteng Raya No. 42, RT 02/RW 03',
      offlineCity: 'Jakarta Pusat',
      offlineNotes: 'Lantai 2, Ruang Konseling Melati 1',
      offlineScheduleDays: const ['Sel', 'Kam', 'Sab'],
      offlineStartTime: '10:00',
      offlineEndTime: '16:00',
      externalApiKey: 'eva_pat_live_9c82df09a12e557b4412',
      externalApiKeyCreatedAt: DateTime(2026, 11, 3, 14, 0),
      externalApiLastSyncAt: DateTime(2026, 11, 9, 12, 15),
      externalSyncCount: 4,
      bankName: 'Bank Central Asia (BCA)',
      bankAccountNumber: '8830192831',
      bankAccountHolder: displayName,
    );

    return _currentProfile!;
  }

  @override
  Future<PsychologistProfileResponseDto> register(
      PsychologistRegisterRequestDto request) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final dto = PsychologistProfileResponseDto(
      id: 'counselor-uuid-${DateTime.now().millisecondsSinceEpoch}',
      fullName: request.fullName,
      titleDegree: request.titleDegree,
      email: request.email,
      strNumber: request.strNumber,
      sipNumber: request.sipNumber,
      documentType: request.documentType,
      issuingInstitution: request.issuingInstitution,
      documentExpiryDate: request.documentExpiryDate,
      lastEducation: request.lastEducation,
      association: request.association,
      specializations: request.specializations,
      yearsOfExperience: request.yearsOfExperience,
      consultationRatePerHour: request.consultationRate,
      verificationStatus: 'pending',
      isOnline: false,
      certificateDocUrl: request.certificateDocFileName,
      token: 'mock-jwt-token-active-${DateTime.now().millisecondsSinceEpoch}',
      counselorRole: 'professional_independent',
      partnerName: null,
      sessionDurationMinutes: request.sessionDurationMinutes,
      coinsPerSession: request.coinsPerSession,
      coinBalance: 0,
      googleDriveEmail: request.email,
    );

    _registeredAccounts[request.email.toLowerCase().trim()] = dto;
    _currentProfile = dto;
    return dto;
  }

  @override
  Future<PsychologistProfileResponseDto> getProfile() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (_currentProfile != null) {
      return _currentProfile!.copyWith(isOnline: _mockOnlineState);
    }
    _currentProfile = PsychologistProfileResponseDto(
      id: 'counselor-uuid-001',
      fullName: 'dr. Sarah Amelia',
      titleDegree: 'M.Psi., Psikolog',
      email: 'khoirotunnisa2507@gmail.com',
      strNumber: 'STR-PK-19980725-2026-01',
      association: 'Himpunan Psikologi Indonesia (HIMPSI)',
      specializations: const [
        'Kecemasan Dewasa & Burnout',
        'Manajemen Stres',
        'Konseling Hubungan & Keluarga',
      ],
      yearsOfExperience: 5,
      consultationRatePerHour: 200000,
      verificationStatus: 'verified',
      isOnline: _mockOnlineState,
      profilePhotoUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=400',
      token: 'mock-jwt-token-counselor-secret-xyz',
      counselorRole: 'professional_independent',
      sessionDurationMinutes: 30,
      coinsPerSession: 150,
      coinBalance: 0,
      googleDriveEmail: 'khoirotunnisa2507@gmail.com',
      employeeNip: '199807252026012001',
      isOnlinePracticeEnabled: true,
      isOfflinePracticeEnabled: true,
      offlinePlaceName: 'Biro Konsultasi Psikologi Mandiri',
      offlineAddress: 'Jl. Menteng Raya No. 42, RT 02/RW 03',
      offlineCity: 'Jakarta Pusat',
      offlineNotes: 'Lantai 2, Ruang Konseling Melati 1',
      offlineScheduleDays: const ['Sel', 'Kam', 'Sab'],
      offlineStartTime: '10:00',
      offlineEndTime: '16:00',
      externalApiKey: 'eva_pat_live_9c82df09a12e557b4412',
      externalApiKeyCreatedAt: DateTime(2026, 11, 3, 14, 0),
      externalApiLastSyncAt: DateTime(2026, 11, 9, 12, 15),
      externalSyncCount: 4,
      bankName: 'Bank Central Asia (BCA)',
      bankAccountNumber: '8830192831',
      bankAccountHolder: 'dr. Sarah Amelia',
    );
    return _currentProfile!;
  }

  @override
  Future<PsychologistProfileResponseDto> updateProfile({
    String? fullName,
    String? titleDegree,
    String? profilePhotoUrl,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final base = _currentProfile ?? await getProfile();
    _currentProfile = base.copyWith(
      fullName: fullName ?? base.fullName,
      titleDegree: titleDegree ?? base.titleDegree,
      profilePhotoUrl: profilePhotoUrl ?? base.profilePhotoUrl,
    );
    return _currentProfile!;
  }

  @override
  Future<PsychologistProfileResponseDto> updateBankDetails({
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final base = _currentProfile ?? await getProfile();
    _currentProfile = base.copyWith(
      bankName: bankName,
      bankAccountNumber: accountNumber,
      bankAccountHolder: accountHolder,
    );
    return _currentProfile!;
  }

  @override
  Future<bool> updateAvailability(bool isOnline) async {
    _mockOnlineState = isOnline;
    if (_currentProfile != null) {
      _configuredScheduleEmails.add(_currentProfile!.email.toLowerCase().trim());
      _currentProfile = _currentProfile!.copyWith(
        isOnline: isOnline,
        isOnlinePracticeEnabled: true,
      );
    }
    return true;
  }
}

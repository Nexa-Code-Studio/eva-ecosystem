import '../models/psychologist_auth_dto.dart';
import 'auth_datasource.dart';

class MockAuthDataSource implements AuthDataSource {
  bool _mockOnlineState = true;
  final Map<String, PsychologistProfileResponseDto> _registeredAccounts = {};

  @override
  Future<PsychologistProfileResponseDto> login(
      PsychologistLoginRequestDto request) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final lowerEmail = request.email.toLowerCase().trim();

    if (_registeredAccounts.containsKey(lowerEmail)) {
      return _registeredAccounts[lowerEmail]!.copyWith(isOnline: _mockOnlineState);
    }

    final isPending = lowerEmail.contains('pending');
    final isRevision = lowerEmail.contains('revisi') || lowerEmail.contains('reject');

    final verificationStatus = isPending
        ? 'pending'
        : (isRevision ? 'need_revision' : 'verified');

    String displayName = 'Khoirotun Nisa';
    String titleDegree = 'S.Psi., M.Psi., Psikolog';
    String strNum = 'STR-PK-19980725-2026-01';
    if (isPending) {
      displayName = 'Dimas Wicaksono';
      titleDegree = 'M.Psi., Psikolog Klinis';
      strNum = 'STR-PK-19920115-PENDING';
    } else if (isRevision) {
      displayName = 'Clara Salsabila';
      titleDegree = 'M.Psi., Psikolog Klinis';
      strNum = 'STR-PK-19950310-REVISI';
    }

    return PsychologistProfileResponseDto(
      id: 'counselor-uuid-001',
      fullName: displayName,
      titleDegree: titleDegree,
      email: request.email,
      strNumber: strNum,
      association: 'Himpunan Psikologi Indonesia (HIMPSI)',
      specializations: [
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
      token: 'mock-jwt-token-nisa-counselor-secret-xyz',
      counselorRole: 'professional_independent',
      partnerName: null,
      sessionDurationMinutes: 30,
      coinsPerSession: 150,
      coinBalance: 1250,
      googleDriveEmail: request.email.contains('@') ? request.email : 'khoirotunnisa2507@gmail.com',
      employeeNip: '199807252026012001',
      isOnlinePracticeEnabled: true,
      isOfflinePracticeEnabled: true,
      offlinePlaceName: 'Biro Psikologi Mandiri Khoirotun Nisa',
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
    );
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
      coinBalance: 1250,
      googleDriveEmail: request.email,
    );

    _registeredAccounts[request.email.toLowerCase().trim()] = dto;
    return dto;
  }

  @override
  Future<PsychologistProfileResponseDto> getProfile() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return PsychologistProfileResponseDto(
      id: 'counselor-uuid-001',
      fullName: 'Khoirotun Nisa',
      titleDegree: 'S.Psi., M.Psi., Psikolog',
      email: 'khoirotunnisa2507@gmail.com',
      strNumber: 'STR-PK-19980725-2026-01',
      association: 'Himpunan Psikologi Indonesia (HIMPSI)',
      specializations: [
        'Kecemasan Dewasa & Burnout',
        'Manajemen Stres',
        'Konseling Hubungan & Keluarga',
      ],
      yearsOfExperience: 5,
      consultationRatePerHour: 200000,
      verificationStatus: 'verified',
      isOnline: _mockOnlineState,
      profilePhotoUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=400',
      token: 'mock-jwt-token-nisa-counselor-secret-xyz',
      counselorRole: 'professional_independent',
      sessionDurationMinutes: 50,
      coinsPerSession: 150,
      coinBalance: 1250,
      googleDriveEmail: 'khoirotunnisa2507@gmail.com',
      employeeNip: '199807252026012001',
      isOnlinePracticeEnabled: true,
      isOfflinePracticeEnabled: true,
      offlinePlaceName: 'Biro Psikologi Mandiri Khoirotun Nisa',
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
    );
  }

  @override
  Future<bool> updateAvailability(bool isOnline) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mockOnlineState = isOnline;
    return true;
  }
}

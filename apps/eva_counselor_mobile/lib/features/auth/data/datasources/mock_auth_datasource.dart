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

    final isVolunteer = lowerEmail.contains('volunteer') || lowerEmail.contains('relawan');
    final isPartner = lowerEmail.contains('mitra') || lowerEmail.contains('klinik');

    return PsychologistProfileResponseDto(
      id: 'counselor-uuid-001',
      fullName: isVolunteer ? 'Raka Danendra (Relawan Sebaya)' : 'Sarah Anindya',
      titleDegree: isVolunteer ? 'Relawan Teman Sebaya' : 'M.Psi., Psikolog Klinis',
      email: request.email,
      strNumber: isVolunteer ? 'VOLUNTEER-PEER' : 'STR-PK-198827364-2024',
      association: isVolunteer ? 'Komunitas Teman Curhat' : 'Himpunan Psikologi Indonesia (HIMPSI)',
      specializations: [
        'Kecemasan Dewasa & Burnout',
        'Manajemen Stres',
        'Konseling Hubungan & Keluarga',
      ],
      yearsOfExperience: isVolunteer ? 1 : 5,
      consultationRatePerHour: isVolunteer ? 0 : 200000,
      verificationStatus: 'verified',
      isOnline: _mockOnlineState,
      profilePhotoUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=400',
      certificateDocUrl: isVolunteer ? null : 'https://eva.nexacode.dev/docs/sample_str.pdf',
      token: 'mock-jwt-token-sarah-counselor-secret-xyz',
      counselorRole: isVolunteer
          ? 'peer_volunteer'
          : isPartner
              ? 'professional_partner'
              : 'professional_independent',
      partnerName: isPartner ? 'Klinik Sehati Sejahtera' : null,
      sessionDurationMinutes: 50,
      coinsPerSession: isVolunteer ? 0 : (isPartner ? 180 : 150),
      coinBalance: isVolunteer ? 0 : 1250,
      googleDriveEmail: request.email,
      employeeNip: isVolunteer
          ? 'VOL-PEER-2026-081'
          : (isPartner ? '198507202015022003' : '198804122019032001'),
      isOnlinePracticeEnabled: true,
      isOfflinePracticeEnabled: isVolunteer ? false : true,
      offlinePlaceName: isVolunteer
          ? null
          : (isPartner
              ? 'RS Mitra Sehati - Unit Poliklinik Jiwa & Psikologi'
              : 'Biro Konsultasi Psikologi Mandiri Anindya'),
      offlineAddress: isVolunteer
          ? null
          : (isPartner
              ? 'Jl. Gatot Subroto No. 128, Gedung Poliklinik Lt. 3'
              : 'Jl. Menteng Raya No. 42, RT 02/RW 03'),
      offlineCity: isVolunteer ? null : (isPartner ? 'Jakarta Selatan' : 'Jakarta Pusat'),
      offlineNotes: isVolunteer
          ? null
          : (isPartner
              ? 'Pasien lapor ke bagian pendaftaran poli psikologi sebelum masuk'
              : 'Lantai 2, Ruang Konseling Melati 1'),
      offlineScheduleDays: const ['Sel', 'Kam', 'Sab'],
      offlineStartTime: '10:00',
      offlineEndTime: '16:00',
      externalApiKey: isVolunteer
          ? null
          : (isPartner
              ? 'eva_pat_live_8f39b1a09d72e44189ac'
              : 'eva_pat_live_9c82df09a12e557b4412'),
      externalApiKeyCreatedAt: isVolunteer ? null : DateTime(2026, 11, 3, 14, 0),
      externalApiLastSyncAt: isVolunteer ? null : DateTime(2026, 11, 9, 12, 15),
      externalSyncCount: isVolunteer ? 0 : (isPartner ? 6 : 4),
    );
  }

  @override
  Future<PsychologistProfileResponseDto> register(
      PsychologistRegisterRequestDto request) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final isVerified = request.counselorRole == 'peer_volunteer' ||
        request.counselorRole == 'professional_partner';

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
      verificationStatus: isVerified ? 'verified' : 'pending',
      isOnline: false,
      certificateDocUrl: request.certificateDocFileName,
      token: 'mock-jwt-token-active-${DateTime.now().millisecondsSinceEpoch}',
      counselorRole: request.counselorRole,
      partnerName: request.partnerName,
      sessionDurationMinutes: request.sessionDurationMinutes,
      coinsPerSession: request.coinsPerSession,
      coinBalance: request.counselorRole == 'peer_volunteer' ? 0 : 1250,
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
      fullName: 'Sarah Anindya',
      titleDegree: 'M.Psi., Psikolog Klinis',
      email: 'sarah.anindya@psikolog.eva.id',
      strNumber: 'STR-PK-198827364-2024',
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
      token: 'mock-jwt-token-sarah-counselor-secret-xyz',
      counselorRole: 'professional_independent',
      sessionDurationMinutes: 50,
      coinsPerSession: 150,
      coinBalance: 1250,
      googleDriveEmail: 'sarah.anindya@gmail.com',
      employeeNip: '198804122019032001',
      isOnlinePracticeEnabled: true,
      isOfflinePracticeEnabled: true,
      offlinePlaceName: 'Biro Konsultasi Psikologi Mandiri Anindya',
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

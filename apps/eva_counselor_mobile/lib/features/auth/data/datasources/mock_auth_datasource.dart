import '../models/psychologist_auth_dto.dart';
import 'auth_datasource.dart';

class MockAuthDataSource implements AuthDataSource {
  bool _mockOnlineState = true;

  @override
  Future<PsychologistProfileResponseDto> login(
      PsychologistLoginRequestDto request) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return PsychologistProfileResponseDto(
      id: 'counselor-uuid-001',
      fullName: 'Sarah Anindya',
      titleDegree: 'M.Psi., Psikolog Klinis',
      email: request.email,
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
      certificateDocUrl: 'https://eva.nexacode.dev/docs/sample_str.pdf',
      token: 'mock-jwt-token-sarah-counselor-secret-xyz',
    );
  }

  @override
  Future<PsychologistProfileResponseDto> register(
      PsychologistRegisterRequestDto request) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return PsychologistProfileResponseDto(
      id: 'counselor-uuid-new',
      fullName: request.fullName,
      titleDegree: request.titleDegree,
      email: request.email,
      strNumber: request.strNumber,
      association: request.association,
      specializations: request.specializations,
      yearsOfExperience: request.yearsOfExperience,
      consultationRatePerHour: request.consultationRate,
      verificationStatus: 'pending', // Freshly uploaded certificate requires review
      isOnline: false,
      certificateDocUrl: request.certificateDocFileName,
      token: 'mock-jwt-pending-verification-token',
    );
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
    );
  }

  @override
  Future<bool> updateAvailability(bool isOnline) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mockOnlineState = isOnline;
    return true;
  }
}

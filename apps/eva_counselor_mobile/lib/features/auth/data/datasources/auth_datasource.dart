import '../models/psychologist_auth_dto.dart';

abstract class AuthDataSource {
  Future<PsychologistProfileResponseDto> login(PsychologistLoginRequestDto request);
  Future<PsychologistProfileResponseDto> register(PsychologistRegisterRequestDto request);
  Future<PsychologistProfileResponseDto> getProfile();
  Future<PsychologistProfileResponseDto> updateProfile({
    String? fullName,
    String? titleDegree,
    String? profilePhotoUrl,
  });
  Future<PsychologistProfileResponseDto> updateBankDetails({
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  });
  Future<bool> updateAvailability(bool isOnline);
}

import '../models/psychologist_auth_dto.dart';

abstract class AuthDataSource {
  Future<PsychologistProfileResponseDto> login(PsychologistLoginRequestDto request);
  Future<PsychologistProfileResponseDto> register(PsychologistRegisterRequestDto request);
  Future<PsychologistProfileResponseDto> getProfile();
  Future<bool> updateAvailability(bool isOnline);
}

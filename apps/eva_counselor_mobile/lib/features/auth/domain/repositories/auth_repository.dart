import '../entities/psychologist_user_entity.dart';

abstract class IAuthRepository {
  Future<PsychologistUserEntity> login(String email, String password);
  Future<PsychologistUserEntity> register({
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
  });
  Future<PsychologistUserEntity?> getCurrentProfile();
  Future<bool> setOnlineAvailability(bool isOnline);
  Future<void> logout();
}

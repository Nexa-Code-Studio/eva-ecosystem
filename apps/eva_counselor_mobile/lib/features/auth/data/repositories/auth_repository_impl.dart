import 'dart:convert';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/psychologist_user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_datasource.dart';
import '../models/psychologist_auth_dto.dart';

class AuthRepositoryImpl implements IAuthRepository {
  final AuthDataSource _dataSource;

  AuthRepositoryImpl({required AuthDataSource dataSource})
      : _dataSource = dataSource;

  @override
  Future<PsychologistUserEntity> login(String email, String password) async {
    final dto = await _dataSource.login(
      PsychologistLoginRequestDto(email: email, password: password),
    );
    if (dto.token != null) {
      await TokenStorage.saveToken(dto.token!);
    }
    await TokenStorage.saveUserId(dto.id);
    await TokenStorage.saveProfileJson(jsonEncode(dto.toJson()));
    return dto.toEntity();
  }

  @override
  Future<PsychologistUserEntity> register({
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
    final request = PsychologistRegisterRequestDto(
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
    final dto = await _dataSource.register(request);
    if (dto.token != null) {
      await TokenStorage.saveToken(dto.token!);
    }
    await TokenStorage.saveUserId(dto.id);
    await TokenStorage.saveProfileJson(jsonEncode(dto.toJson()));
    return dto.toEntity();
  }

  @override
  Future<PsychologistUserEntity?> getCurrentProfile() async {
    try {
      final token = await TokenStorage.getToken();
      if (token != null && token.isNotEmpty) {
        try {
          final dto = await _dataSource.getProfile();
          await TokenStorage.saveProfileJson(jsonEncode(dto.toJson()));
          return dto.toEntity();
        } catch (_) {
          // Offline/transient fallback to last cached profile below
        }
      }
      final cachedJson = await TokenStorage.getProfileJson();
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
        return PsychologistProfileResponseDto.fromJson(decoded).toEntity();
      }
      final dto = await _dataSource.getProfile();
      await TokenStorage.saveProfileJson(jsonEncode(dto.toJson()));
      return dto.toEntity();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PsychologistUserEntity> updateProfile({
    String? fullName,
    String? titleDegree,
    String? profilePhotoUrl,
  }) async {
    final dto = await _dataSource.updateProfile(
      fullName: fullName,
      titleDegree: titleDegree,
      profilePhotoUrl: profilePhotoUrl,
    );
    await TokenStorage.saveProfileJson(jsonEncode(dto.toJson()));
    return dto.toEntity();
  }

  @override
  Future<PsychologistUserEntity> uploadAvatar({
    required List<int> bytes,
    required String filename,
  }) async {
    final dto = await _dataSource.uploadAvatar(bytes: bytes, filename: filename);
    await TokenStorage.saveProfileJson(jsonEncode(dto.toJson()));
    return dto.toEntity();
  }

  @override
  Future<PsychologistUserEntity> updateBankDetails({
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  }) async {
    final dto = await _dataSource.updateBankDetails(
      bankName: bankName,
      accountNumber: accountNumber,
      accountHolder: accountHolder,
    );
    await TokenStorage.saveProfileJson(jsonEncode(dto.toJson()));
    return dto.toEntity();
  }

  @override
  Future<bool> setOnlineAvailability(bool isOnline) async {
    return await _dataSource.updateAvailability(isOnline);
  }

  @override
  Future<void> logout() async {
    await TokenStorage.clear();
  }
}

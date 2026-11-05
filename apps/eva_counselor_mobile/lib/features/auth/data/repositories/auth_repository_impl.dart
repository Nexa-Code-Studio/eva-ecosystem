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
    required String strNumber,
    required String association,
    required List<String> specializations,
    required int yearsOfExperience,
    required int consultationRate,
    required String certificateDocFileName,
  }) async {
    final request = PsychologistRegisterRequestDto(
      fullName: fullName,
      titleDegree: titleDegree,
      email: email,
      password: password,
      strNumber: strNumber,
      association: association,
      specializations: specializations,
      yearsOfExperience: yearsOfExperience,
      consultationRate: consultationRate,
      certificateDocFileName: certificateDocFileName,
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
      final cachedJson = await TokenStorage.getProfileJson();
      if (cachedJson != null && cachedJson.isNotEmpty) {
        final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
        return PsychologistProfileResponseDto.fromJson(decoded).toEntity();
      }
      final dto = await _dataSource.getProfile();
      return dto.toEntity();
    } catch (_) {
      return null;
    }
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

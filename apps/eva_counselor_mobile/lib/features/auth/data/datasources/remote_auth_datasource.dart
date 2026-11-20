import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/storage/token_storage.dart';
import '../models/psychologist_auth_dto.dart';
import 'auth_datasource.dart';

class RemoteAuthDataSource implements AuthDataSource {
  final ApiClient _client;

  RemoteAuthDataSource({ApiClient? client}) : _client = client ?? ApiClient();

  @override
  Future<PsychologistProfileResponseDto> login(
      PsychologistLoginRequestDto request) async {
    // 1. Authenticate with FastAPI auth route
    final response = await _client.post(ApiEndpoints.login, body: request.toJson());
    final data = response as Map<String, dynamic>;
    final accessToken = data['access_token']?.toString() ?? '';
    final userMap = data['user'] as Map<String, dynamic>?;
    final userId = userMap?['id']?.toString() ?? '';

    // 2. Persist access token in local secure storage
    if (accessToken.isNotEmpty) {
      await TokenStorage.saveToken(accessToken);
    }
    if (userId.isNotEmpty) {
      await TokenStorage.saveUserId(userId);
    }

    // 3. Retrieve detailed psychologist profile from backend
    final profile = await getProfile();
    return profile.copyWith(
      token: accessToken,
      email: userMap?['email']?.toString() ?? profile.email,
    );
  }

  @override
  Future<PsychologistProfileResponseDto> register(
      PsychologistRegisterRequestDto request) async {
    // 1. Submit psychologist registration to backend
    await _client.post(ApiEndpoints.register, body: request.toJson());

    // 2. Perform direct login to establish session and obtain tokens
    return await login(PsychologistLoginRequestDto(
      email: request.email,
      password: request.password,
    ));
  }

  @override
  Future<PsychologistProfileResponseDto> getProfile() async {
    final response = await _client.get(ApiEndpoints.profile);
    return PsychologistProfileResponseDto.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<PsychologistProfileResponseDto> updateProfile({
    String? fullName,
    String? titleDegree,
    String? profilePhotoUrl,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName;
    if (titleDegree != null) body['title_degree'] = titleDegree;
    if (profilePhotoUrl != null) body['profile_photo_url'] = profilePhotoUrl;

    final response = await _client.put(ApiEndpoints.updateProfile, body: body);
    return PsychologistProfileResponseDto.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<PsychologistProfileResponseDto> updateBankDetails({
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  }) async {
    final response = await _client.put(
      ApiEndpoints.bankDetails,
      body: {
        'bank_name': bankName,
        'bank_account_number': accountNumber,
        'bank_account_holder': accountHolder,
      },
    );
    return PsychologistProfileResponseDto.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<bool> updateAvailability(bool isOnline) async {
    final response = await _client.patch(
      ApiEndpoints.availability,
      body: {'is_online': isOnline},
    );
    return (response as Map<String, dynamic>?)?['is_online'] as bool? ?? isOnline;
  }
}

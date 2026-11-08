import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/psychologist_auth_dto.dart';
import 'auth_datasource.dart';

class RemoteAuthDataSource implements AuthDataSource {
  final ApiClient _client;

  RemoteAuthDataSource({ApiClient? client}) : _client = client ?? ApiClient();

  @override
  Future<PsychologistProfileResponseDto> login(
      PsychologistLoginRequestDto request) async {
    final response = await _client.post(ApiEndpoints.login, body: request.toJson());
    return PsychologistProfileResponseDto.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<PsychologistProfileResponseDto> register(
      PsychologistRegisterRequestDto request) async {
    final response = await _client.post(ApiEndpoints.register, body: request.toJson());
    return PsychologistProfileResponseDto.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<PsychologistProfileResponseDto> getProfile() async {
    final response = await _client.get(ApiEndpoints.profile);
    return PsychologistProfileResponseDto.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<bool> updateAvailability(bool isOnline) async {
    final response = await _client.post(
      ApiEndpoints.availability,
      body: {'is_online': isOnline},
    );
    return (response as Map<String, dynamic>?)?['success'] as bool? ?? true;
  }
}

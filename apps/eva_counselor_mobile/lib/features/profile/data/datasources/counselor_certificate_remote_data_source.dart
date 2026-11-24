import 'dart:typed_data';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/eva_certificate_entity.dart';

abstract class ICounselorCertificateDataSource {
  Future<List<EvaCertificateEntity>> fetchCertificates();
  Future<Uint8List> downloadCertificatePdf(String certificateId);
  Future<String> getCertificateDownloadUrl(String certificateId);
}

class CounselorCertificateRemoteDataSource implements ICounselorCertificateDataSource {
  final ApiClient _apiClient;

  CounselorCertificateRemoteDataSource({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  @override
  Future<List<EvaCertificateEntity>> fetchCertificates() async {
    final response = await _apiClient.get(ApiEndpoints.counselorCertificates);
    if (response is List) {
      return response
          .map((e) => EvaCertificateEntity.fromJson(e as Map<String, dynamic>))
          .where((cert) => cert.status == 'active') // Filter revoked certificates
          .toList();
    }
    return [];
  }

  @override
  Future<Uint8List> downloadCertificatePdf(String certificateId) async {
    final bytes = await _apiClient.getRawBytes(
      ApiEndpoints.downloadCertificatePdf(certificateId),
    );
    return Uint8List.fromList(bytes);
  }

  @override
  Future<String> getCertificateDownloadUrl(String certificateId) async {
    final token = await TokenStorage.getToken() ?? '';
    final base = AppConfig.apiBaseUrl;
    final path = ApiEndpoints.downloadCertificatePdf(certificateId);
    if (token.isNotEmpty) {
      return '$base$path?token=$token';
    }
    return '$base$path';
  }
}

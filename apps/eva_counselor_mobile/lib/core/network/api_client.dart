import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../storage/token_storage.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? errorCode;
  final dynamic details;

  ApiException({
    required this.statusCode,
    required this.message,
    this.errorCode,
    this.details,
  });

  @override
  String toString() => 'ApiException [$statusCode${errorCode != null ? ' - $errorCode' : ''}]: $message';
}

/// Centralized HTTP client managing auth header injection and status validation.
class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, String>> _buildHeaders({Map<String, String>? extra}) async {
    final token = await TokenStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      ...?extra,
    };
  }

  Uri _buildUri(String path, [Map<String, dynamic>? queryParams]) {
    final base = AppConfig.apiBaseUrl;
    final fullUrl = '$base$path';
    return Uri.parse(fullUrl).replace(
      queryParameters: queryParams?.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? queryParams}) async {
    final uri = _buildUri(path, queryParams);
    final headers = await _buildHeaders();
    final response = await _client.get(uri, headers: headers).timeout(AppConfig.connectTimeout);
    return _handleResponse(response);
  }

  Future<dynamic> post(String path, {dynamic body, Map<String, String>? extraHeaders}) async {
    final uri = _buildUri(path);
    final headers = await _buildHeaders(extra: extraHeaders);
    final response = await _client
        .post(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
        .timeout(AppConfig.connectTimeout);
    return _handleResponse(response);
  }

  Future<dynamic> put(String path, {dynamic body, Map<String, String>? extraHeaders}) async {
    final uri = _buildUri(path);
    final headers = await _buildHeaders(extra: extraHeaders);
    final response = await _client
        .put(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
        .timeout(AppConfig.connectTimeout);
    return _handleResponse(response);
  }

  Future<dynamic> patch(String path, {dynamic body}) async {
    final uri = _buildUri(path);
    final headers = await _buildHeaders();
    final response = await _client
        .patch(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
        .timeout(AppConfig.connectTimeout);
    return _handleResponse(response);
  }

  Future<dynamic> delete(String path) async {
    final uri = _buildUri(path);
    final headers = await _buildHeaders();
    final response = await _client.delete(uri, headers: headers).timeout(AppConfig.connectTimeout);
    return _handleResponse(response);
  }

  Future<List<int>> getRawBytes(String path, {Map<String, dynamic>? queryParams}) async {
    final uri = _buildUri(path, queryParams);
    final headers = await _buildHeaders(extra: {'Accept': 'application/pdf, application/octet-stream, */*'});
    final response = await _client.get(uri, headers: headers).timeout(AppConfig.connectTimeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Gagal mengunduh berkas (${response.statusCode})',
      details: response.body,
    );
  }

  dynamic _handleResponse(http.Response res) {
    dynamic decoded;
    try {
      decoded = res.body.isNotEmpty ? jsonDecode(res.body) : null;
    } catch (_) {
      decoded = res.body;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded;
    }

    String message = 'Terjadi kesalahan sistem (${res.statusCode})';
    String? errorCode;
    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail'];
      if (detail is Map<String, dynamic>) {
        errorCode = detail['code']?.toString();
        message = detail['message']?.toString() ?? errorCode ?? message;
      } else if (detail is String) {
        message = detail;
      } else if (decoded['message'] != null) {
        message = decoded['message'].toString();
      }
      if (errorCode == null && decoded['code'] != null) {
        errorCode = decoded['code']?.toString();
      }
    }

    throw ApiException(
      statusCode: res.statusCode,
      message: message,
      errorCode: errorCode,
      details: decoded,
    );
  }
}

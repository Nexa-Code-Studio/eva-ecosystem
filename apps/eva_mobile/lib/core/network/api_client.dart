import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:eva_mobile/config/app_config.dart';
import 'package:eva_mobile/core/routes/app_router.dart';

/// Custom Exception for API Errors
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException: $message (StatusCode: $statusCode)';
}

/// Generic HTTP Client abstraction for Remote DataSources with Transparent Silent Token Refresh
class ApiClient {
  final http.Client _client;
  static Completer<bool>? _refreshCompleter;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Duration get _effectiveTimeout =>
      AppConfig.useHybridFallback ? AppConfig.hybridTimeout : const Duration(seconds: 10);

  /// Single-flight refresh mechanism to avoid multiple concurrent refresh calls
  Future<bool> _performSingleFlightRefresh() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }
    _refreshCompleter = Completer<bool>();
    try {
      final success = await AppConfig.refreshAccessToken(client: _client);
      _refreshCompleter!.complete(success);
      return success;
    } catch (e) {
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  /// Execute an HTTP request with automatic 401 refresh & retry
  Future<http.Response> _executeWithRefreshRetry(
    Future<http.Response> Function(Map<String, String> headers) requestCall,
    String path,
  ) async {
    final headers = await AppConfig.getAuthHeaders();
    final response = await requestCall(headers).timeout(_effectiveTimeout);

    final isAuthEndpoint = path.contains('/auth/login') ||
        path.contains('/auth/register') ||
        path.contains('/auth/refresh');

    if (response.statusCode == 401 && !isAuthEndpoint) {
      debugPrint('⚠️ [AUTH INTERCEPTOR] 401 Unauthorized terdeteksi pada $path. Mencoba silent refresh token...');
      final refreshed = await _performSingleFlightRefresh();
      if (refreshed) {
        debugPrint('✅ [AUTH INTERCEPTOR] Token berhasil diperbarui. Mengulang request $path...');
        final retryHeaders = await AppConfig.getAuthHeaders();
        return await requestCall(retryHeaders).timeout(_effectiveTimeout);
      } else {
        debugPrint('❌ [AUTH INTERCEPTOR] Refresh token gagal atau kedaluwarsa. Membersihkan sesi...');
        await AppConfig.clearToken();
        AppRouter.forceLogoutToLogin();
      }
    }

    return response;
  }

  Future<dynamic> get(String path, {Map<String, String>? queryParams}) async {
    try {
      final cleanPath = path.startsWith('/') ? path : '/$path';
      final uri = Uri.parse('${AppConfig.baseUrl}$cleanPath').replace(queryParameters: queryParams);
      final response = await _executeWithRefreshRetry(
        (headers) => _client.get(uri, headers: headers),
        cleanPath,
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to connect to backend: $e');
    }
  }

  Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    try {
      final cleanPath = path.startsWith('/') ? path : '/$path';
      final uri = Uri.parse('${AppConfig.baseUrl}$cleanPath');
      final response = await _executeWithRefreshRetry(
        (headers) => _client.post(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        ),
        cleanPath,
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to send data to backend: $e');
    }
  }

  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    try {
      final cleanPath = path.startsWith('/') ? path : '/$path';
      final uri = Uri.parse('${AppConfig.baseUrl}$cleanPath');
      final response = await _executeWithRefreshRetry(
        (headers) => _client.put(
          uri,
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        ),
        cleanPath,
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to update data on backend: $e');
    }
  }

  Future<dynamic> delete(String path) async {
    try {
      final cleanPath = path.startsWith('/') ? path : '/$path';
      final uri = Uri.parse('${AppConfig.baseUrl}$cleanPath');
      final response = await _executeWithRefreshRetry(
        (headers) => _client.delete(uri, headers: headers),
        cleanPath,
      );
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to delete resource on backend: $e');
    }
  }

  dynamic _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else {
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      final message = body['detail'] ?? body['message'] ?? 'HTTP Error ${response.statusCode}';
      throw ApiException(message.toString(), statusCode: response.statusCode);
    }
  }
}

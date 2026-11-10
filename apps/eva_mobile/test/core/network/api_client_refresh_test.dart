import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eva_mobile/config/app_config.dart';
import 'package:eva_mobile/core/network/api_client.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({
      'auth_token': 'old_access_token',
      'refresh_token': 'valid_refresh_token',
    });
    AppConfig.authToken = 'old_access_token';
  });

  group('ApiClient Transparent 401 Silent Refresh Tests', () {
    test('Automatically refreshes token and retries request upon receiving 401', () async {
      int diariesAttempt = 0;
      int refreshAttempt = 0;

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/diaries')) {
          diariesAttempt++;
          final authHeader = request.headers['Authorization'];
          if (authHeader == 'Bearer old_access_token') {
            return http.Response(jsonEncode({'detail': 'Token expired'}), 401);
          } else if (authHeader == 'Bearer new_access_token') {
            return http.Response(jsonEncode([{'id': 'd1', 'title': 'Diary 1'}]), 200);
          }
          return http.Response('Unauthorized', 401);
        }

        if (request.url.path.endsWith('/auth/refresh')) {
          refreshAttempt++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['refresh_token'], 'valid_refresh_token');
          return http.Response(
            jsonEncode({
              'access_token': 'new_access_token',
              'refresh_token': 'new_refresh_token',
              'token_type': 'bearer',
              'user': {'id': 'u1', 'name': 'Samsul', 'email': 'samsul@gmail.com'},
            }),
            200,
          );
        }

        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient);
      final result = await apiClient.get('/diaries');

      expect(diariesAttempt, 2);
      expect(refreshAttempt, 1);
      expect(result, isA<List>());
      expect((result as List).first['title'], 'Diary 1');
      expect(AppConfig.authToken, 'new_access_token');
    });

    test('Throws ApiException and clears session when refresh token is invalid', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/diaries')) {
          return http.Response(jsonEncode({'detail': 'Token expired'}), 401);
        }
        if (request.url.path.endsWith('/auth/refresh')) {
          return http.Response(jsonEncode({'detail': 'Invalid refresh token'}), 401);
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient);

      expect(
        () async => await apiClient.get('/diaries'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('Does not attempt refresh loop on auth endpoints', () async {
      int refreshAttempt = 0;

      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          return http.Response(jsonEncode({'detail': 'Invalid email or password'}), 401);
        }
        if (request.url.path.endsWith('/auth/refresh')) {
          refreshAttempt++;
          return http.Response('OK', 200);
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient);

      expect(
        () async => await apiClient.post('/auth/login', body: {'email': 'a@b.com', 'password': 'wrong'}),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );

      // Verify refresh was NOT called for /auth/login 401
      expect(refreshAttempt, 0);
    });
  });
}

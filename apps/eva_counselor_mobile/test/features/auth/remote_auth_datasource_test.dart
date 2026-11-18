import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eva_counselor_mobile/core/network/api_client.dart';
import 'package:eva_counselor_mobile/core/storage/token_storage.dart';
import 'package:eva_counselor_mobile/features/auth/data/datasources/remote_auth_datasource.dart';
import 'package:eva_counselor_mobile/features/auth/data/models/psychologist_auth_dto.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RemoteAuthDataSource Tests', () {
    test('login authenticates via backend, saves token, and fetches counselor profile', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/auth/login')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['email'], 'psikolog@eva.id');
          expect(body['password'], 'secret123');
          return http.Response(
            jsonEncode({
              'access_token': 'jwt-access-token-123',
              'refresh_token': 'jwt-refresh-token-456',
              'token_type': 'bearer',
              'user': {
                'id': 'user-uuid-1',
                'name': 'Dr. Sarah Anindya',
                'email': 'psikolog@eva.id',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.url.path.endsWith('/counselors/me')) {
          expect(request.headers['authorization'], 'Bearer jwt-access-token-123');
          return http.Response(
            jsonEncode({
              'id': 'counselor-uuid-1',
              'user_id': 'user-uuid-1',
              'full_name': 'Dr. Sarah Anindya',
              'title_degree': 'M.Psi., Psikolog',
              'str_number': 'STR-PK-19950814-2024-02',
              'sip_number': null,
              'association': 'HIMPSI',
              'specializations': ['Kecemasan', 'Manajemen Stres'],
              'years_of_experience': 5,
              'bio': 'Psikolog Klinis',
              'profile_photo_url': null,
              'certificate_doc_url': 'https://eva.nexacode.dev/docs/str.pdf',
              'verification_status': 'verified',
              'verification_notes': null,
              'verified_at': null,
              'is_online': true,
              'buffer_time_minutes': 10,
              'bank_name': 'BCA',
              'bank_account_number': '8192039182',
              'bank_account_holder': 'Sarah Anindya',
              'wallet_balance': 1500.0,
              'created_at': DateTime.now().toIso8601String(),
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient);
      final dataSource = RemoteAuthDataSource(client: apiClient);

      final result = await dataSource.login(const PsychologistLoginRequestDto(
        email: 'psikolog@eva.id',
        password: 'secret123',
      ));

      expect(result.id, 'counselor-uuid-1');
      expect(result.fullName, 'Dr. Sarah Anindya');
      expect(result.strNumber, 'STR-PK-19950814-2024-02');
      expect(result.verificationStatus, 'verified');
      expect(result.token, 'jwt-access-token-123');

      // Verify token is stored in TokenStorage
      final savedToken = await TokenStorage.getToken();
      expect(savedToken, 'jwt-access-token-123');
      final savedUserId = await TokenStorage.getUserId();
      expect(savedUserId, 'user-uuid-1');
    });

    test('updateAvailability sends PATCH to /counselors/me/availability', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('/counselors/me/availability')) {
          expect(request.method, 'PATCH');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['is_online'], false);
          return http.Response(
            jsonEncode({
              'id': 'counselor-uuid-1',
              'is_online': false,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final apiClient = ApiClient(client: mockClient);
      final dataSource = RemoteAuthDataSource(client: apiClient);

      final status = await dataSource.updateAvailability(false);
      expect(status, false);
    });
  });
}

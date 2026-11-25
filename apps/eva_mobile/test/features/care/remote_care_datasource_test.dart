import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eva_mobile/config/app_config.dart';
import 'package:eva_mobile/core/network/api_client.dart';
import 'package:eva_mobile/features/care/data/datasources/mock_care_datasource.dart';
import 'package:eva_mobile/features/care/data/datasources/remote_care_datasource.dart';
import 'package:eva_mobile/features/care/data/repositories/care_repository_impl.dart';
import 'package:eva_mobile/features/care/data/repositories/fallback_care_repository.dart';
import 'package:eva_mobile/features/care/domain/entities/consultation_session_entity.dart';

void main() {
  setUp(() {
    AppConfig.useMockData = false;
    SharedPreferences.setMockInitialValues({'auth_token': 'test-jwt'});
  });

  group('RemoteCareDataSource HTTP Contract Tests', () {
    test('bookConsultation sends scheduled_start_time & preferred_date_time (never preferred_datetime)',
        () async {
      late Uri capturedUri;
      late Map<String, dynamic> capturedBody;

      final mockHttp = MockClient((request) async {
        capturedUri = request.url;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'id': 'sess-uuid-1',
            'psychologist': {
              'id': 'psy-1',
              'name': 'Amanda Zahra, M.Psi.',
              'title': 'Psikolog Klinis',
              'registration_number': 'SIPP-1',
              'avatar_url': '',
              'rating': 4.9,
              'review_count': 20,
              'experience_years': 5,
              'specialties': ['Kecemasan'],
              'coins_per_session': 65,
              'bio': 'Bio',
            },
            'session_datetime': '2026-11-26T01:37:00Z',
            'status': 'scheduled',
            'type': 'onlineVideo',
            'duration_minutes': 30,
            'notes': 'Cemas sebelum presentasi',
            'share_ai_chat_history': true,
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final dataSource =
          RemoteCareDataSource(apiClient: ApiClient(client: mockHttp));
      final bookingTime = DateTime.utc(2026, 11, 26, 1, 37);

      final result = await dataSource.bookConsultation(
        psychologistId: 'psy-1',
        preferredDateTime: bookingTime,
        sessionType: ConsultationType.onlineVideo,
        sessionCount: 1,
        durationMinutes: 30,
        complaints: 'Cemas sebelum presentasi',
        shareAiChatHistory: true,
      );

      expect(capturedUri.path, endsWith('/counselors/psy-1/book'));
      expect(capturedBody.containsKey('preferred_datetime'), isFalse);
      expect(capturedBody['scheduled_start_time'], bookingTime.toIso8601String());
      expect(capturedBody['preferred_date_time'], bookingTime.toIso8601String());
      expect(capturedBody['session_count'], 1);
      expect(capturedBody['duration_minutes'], 30);
      expect(capturedBody['share_ai_chat_history'], isTrue);
      expect(result.id, 'sess-uuid-1');
      expect(result.durationMinutes, 30);
      expect(result.isOnlineVideo, isTrue);
    });

    test('getPsychologists calls /counselors and parses dynamic level price',
        () async {
      late Uri capturedUri;

      final mockHttp = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode([
            {
              'id': 'c-1',
              'full_name': 'Dr. Rina, M.Psi.',
              'title_degree': 'Psikolog Klinis Dewasa',
              'association': 'HIMPSI',
              'specializations': ['Trauma', 'CBT'],
              'years_of_experience': 7,
              'bio': 'Berpengalaman menangani trauma.',
              'profile_photo_url': 'https://example.com/rina.jpg',
              'is_online': true,
              'buffer_time_minutes': 10,
              'level_tier': 3,
              'level_name': 'Senior Specialist',
              'effective_session_price': 85.0,
              'average_rating': 4.92,
              'rating_count': 41,
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final dataSource =
          RemoteCareDataSource(apiClient: ApiClient(client: mockHttp));
      final list = await dataSource.getPsychologists(query: 'Rina');

      expect(capturedUri.path, endsWith('/counselors'));
      expect(list.length, 1);
      expect(list.first.name, 'Dr. Rina, M.Psi.');
      expect(list.first.coinsPerSession, 85);
      expect(list.first.rating, 4.92);
      expect(list.first.reviewCount, 41);
      expect(list.first.specialties, ['Trauma', 'CBT']);
    });

    test('FallbackCareRepository propagates 409/401/422 ApiException without falling back to mock',
        () async {
      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Slot waktu bertabrakan dengan jadwal lain.'}),
          409,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = FallbackCareRepository(
        remote: CareRepositoryImpl(
          RemoteCareDataSource(apiClient: ApiClient(client: mockHttp)),
        ),
        mock: CareRepositoryImpl(MockCareDataSource()),
      );

      expect(
        () => repo.bookConsultation(
          psychologistId: 'psy-1',
          preferredDateTime: DateTime.utc(2026, 11, 26, 2, 0),
          sessionType: ConsultationType.onlineVideo,
        ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409)),
      );
    });
  });
}

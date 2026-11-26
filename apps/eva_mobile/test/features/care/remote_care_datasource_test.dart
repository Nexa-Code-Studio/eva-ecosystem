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

    test('getPsychologists calls /counselors with availability, level, sort, and parses fields',
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
              'level_badge_icon': 'star',
              'effective_session_price': 85.0,
              'average_rating': 4.92,
              'rating_count': 41,
              'availability_status': 'available_now',
              'next_available_slot': '14:30',
              'next_available_date': '2026-11-26',
              'remaining_slots_today': 4,
              'has_slots_tomorrow': true,
              'next_slot_tomorrow': '09:00',
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final dataSource =
          RemoteCareDataSource(apiClient: ApiClient(client: mockHttp));
      final list = await dataSource.getPsychologists(
        availability: 'available_now',
        levelTier: 3,
        sortBy: 'rating',
        query: 'Rina',
      );

      expect(capturedUri.path, endsWith('/counselors'));
      expect(capturedUri.queryParameters['availability'], 'available_now');
      expect(capturedUri.queryParameters['level_tier'], '3');
      expect(capturedUri.queryParameters['sort_by'], 'rating');
      expect(capturedUri.queryParameters['search'], 'Rina');
      expect(list.length, 1);
      expect(list.first.name, 'Dr. Rina, M.Psi.');
      expect(list.first.coinsPerSession, 85);
      expect(list.first.levelTier, 3);
      expect(list.first.levelName, 'Senior Specialist');
      expect(list.first.rating, 4.92);
      expect(list.first.reviewCount, 41);
      expect(list.first.specialties, ['Trauma', 'CBT']);
      expect(list.first.isAvailableNow, isTrue);
      expect(list.first.nextAvailableSlot, '14:30');
      expect(list.first.remainingSlotsToday, 4);
      expect(list.first.hasSlotsTomorrow, isTrue);
      expect(list.first.nextSlotTomorrow, '09:00');
    });

    test('AppConfig.useHybridFallback defaults to false so live mode never hides errors', () {
      expect(AppConfig.useHybridFallback, isFalse);
    });

    test('getConsultationSessions maps missed status and parses my_review', () async {
      final mockHttp = MockClient((request) async {
        expect(request.url.path, endsWith('/care/sessions'));
        return http.Response(
          jsonEncode([
            {
              'id': 'sess-missed',
              'psychologist': {
                'id': 'psy-1',
                'name': 'Dr. Rina, M.Psi.',
                'title': 'Psikolog Klinis',
                'registration_number': 'STR-1',
                'avatar_url': '',
                'rating': 0.0,
                'review_count': 0,
                'experience_years': 5,
                'specialties': const <String>[],
                'coins_per_session': 120,
                'bio': '',
              },
              'session_datetime': '2026-11-20T09:00:00Z',
              'status': 'missed',
              'duration_minutes': 30,
              'session_number': 1,
              'has_review': false,
            },
            {
              'id': 'sess-done',
              'psychologist': {
                'id': 'psy-1',
                'name': 'Dr. Rina, M.Psi.',
                'title': 'Psikolog Klinis',
                'registration_number': 'STR-1',
                'avatar_url': '',
                'rating': 4.8,
                'review_count': 2,
                'experience_years': 5,
                'specialties': const <String>[],
                'coins_per_session': 120,
                'level_name': 'Senior Specialist',
                'bio': '',
              },
              'session_datetime': '2026-11-22T09:00:00Z',
              'status': 'completed',
              'duration_minutes': 30,
              'session_number': 2,
              'has_review': true,
              'my_review': {
                'id': 'rev-1',
                'session_id': 'sess-done',
                'rating': 5.0,
                'highlight_label': 'Sangat Empatik',
                'review_text': 'Membantu sekali',
                'is_anonymous': true,
                'created_at': '2026-11-22T10:00:00Z',
              },
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final dataSource =
          RemoteCareDataSource(apiClient: ApiClient(client: mockHttp));
      final sessions = await dataSource.getConsultationSessions();

      expect(sessions.length, 2);
      expect(sessions[0].status, ConsultationStatus.missed);
      expect(sessions[0].isMissed, isTrue);
      expect(sessions[0].psychologist.rating, 0.0);
      expect(sessions[1].status, ConsultationStatus.completed);
      expect(sessions[1].sessionNumber, 2);
      expect(sessions[1].hasReview, isTrue);
      expect(sessions[1].myReview?.label, 'Sangat Empatik');
      expect(sessions[1].psychologist.levelName, 'Senior Specialist');
    });

    test('getCounselorDetail, getCounselorReviews, and submitSessionReview hit expected routes',
        () async {
      late String capturedReviewBody;
      final mockHttp = MockClient((request) async {
        if (request.url.path.endsWith('/counselors/c-1') && request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'id': 'c-1',
              'full_name': 'Dr. Rina, M.Psi.',
              'title_degree': 'Psikolog Klinis',
              'registration_number': 'SIP-777',
              'str_verified': true,
              'sip_verified': true,
              'association': 'HIMPSI',
              'specializations': ['Trauma'],
              'years_of_experience': 7,
              'bio': 'Bio terverifikasi',
              'is_online': true,
              'buffer_time_minutes': 10,
              'level_tier': 3,
              'level_name': 'Senior Specialist',
              'effective_session_price': 180.0,
              'average_rating': 4.85,
              'rating_count': 12,
              'total_completed_sessions': 25,
              'certificate_items': [
                {'title': 'STR: 123 (Terverifikasi)', 'image_url': 'https://cdn.eva/str.png'},
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/counselors/c-1/reviews') && request.method == 'GET') {
          return http.Response(
            jsonEncode([
              {
                'id': 'rev-1',
                'session_id': 'sess-1',
                'counselor_id': 'c-1',
                'patient_id': 'p-1',
                'patient_display_name': 'Pasien Anonim',
                'rating': 5.0,
                'highlight_label': 'Tenang & Jelas',
                'review_text': 'Sesi terarah.',
                'is_anonymous': true,
                'created_at': '2026-11-25T10:00:00Z',
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/sessions/sess-1/reviews') && request.method == 'POST') {
          capturedReviewBody = request.body;
          return http.Response(
            jsonEncode({
              'id': 'rev-new',
              'session_id': 'sess-1',
              'counselor_id': 'c-1',
              'patient_id': 'p-1',
              'patient_display_name': 'Pasien Anonim',
              'rating': 4.5,
              'highlight_label': 'Terstruktur',
              'review_text': 'Sangat membantu',
              'is_anonymous': true,
              'created_at': '2026-11-26T10:00:00Z',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('{}', 404);
      });

      final dataSource =
          RemoteCareDataSource(apiClient: ApiClient(client: mockHttp));

      final detail = await dataSource.getCounselorDetail('c-1');
      expect(detail.levelName, 'Senior Specialist');
      expect(detail.certificateItems.length, 1);
      expect(detail.strVerified, isTrue);

      final reviews = await dataSource.getCounselorReviews('c-1');
      expect(reviews.length, 1);
      expect(reviews.first.patientName, 'Pasien Anonim');
      expect(reviews.first.label, 'Tenang & Jelas');

      final submitted = await dataSource.submitSessionReview(
        sessionId: 'sess-1',
        psychologistId: 'c-1',
        rating: 4.5,
        highlightLabel: 'Terstruktur',
        reviewText: 'Sangat membantu',
        isAnonymous: true,
      );
      final sentJson = jsonDecode(capturedReviewBody) as Map<String, dynamic>;
      expect(sentJson['highlight_label'], 'Terstruktur');
      expect(sentJson['review_text'], 'Sangat membantu');
      expect(submitted.label, 'Terstruktur');
      expect(submitted.rating, 4.5);
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

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eva_mobile/config/app_config.dart';
import 'package:eva_mobile/core/network/api_client.dart';
import 'package:eva_mobile/features/care/data/datasources/remote_video_call_datasource.dart';
import 'package:eva_mobile/features/care/data/repositories/video_call_repository_impl.dart';

void main() {
  setUp(() {
    AppConfig.useMockData = false;
    SharedPreferences.setMockInitialValues({'auth_token': 'test-jwt'});
  });

  group('RemoteVideoCallDataSource HTTP Contract Tests', () {
    test('checkExtensionAvailability parses available slot and extension price',
        () async {
      late Uri capturedUri;
      final mockHttp = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            'session_id': 'sess-123',
            'can_extend': true,
            'extension_duration_minutes': 30,
            'extension_price': 65.0,
            'reason': 'Slot 30 menit berikutnya tersedia.',
            'next_available_slots': [],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = VideoCallRepositoryImpl(
        dataSource:
            RemoteVideoCallDataSource(apiClient: ApiClient(client: mockHttp)),
      );
      final res = await repo.checkExtensionAvailability('sess-123');

      expect(capturedUri.path, endsWith('/sessions/sess-123/extension-availability'));
      expect(res.canExtend, isTrue);
      expect(res.extensionCoins, 65);
      expect(res.extensionDurationMinutes, 30);
    });

    test('checkExtensionAvailability parses busy response with next_available_slots',
        () async {
      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'session_id': 'sess-123',
            'can_extend': false,
            'extension_duration_minutes': 30,
            'extension_price': 65.0,
            'reason': 'Menabrak jam istirahat konselor.',
            'next_available_slots': [
              {
                'start_time': '2026-11-26T06:00:00Z',
                'end_time': '2026-11-26T06:30:00Z',
                'duration_minutes': 30,
                'is_available': true,
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = VideoCallRepositoryImpl(
        dataSource:
            RemoteVideoCallDataSource(apiClient: ApiClient(client: mockHttp)),
      );
      final res = await repo.checkExtensionAvailability('sess-123');

      expect(res.canExtend, isFalse);
      expect(res.reason, contains('istirahat'));
      expect(res.nextAvailableSlots.length, 1);
      expect(res.nextAvailableSlots.first.durationMinutes, 30);
    });

    test('extendSession calls POST /sessions/{id}/extend and returns 60m extended session',
        () async {
      late Uri capturedUri;
      late String capturedMethod;
      final mockHttp = MockClient((request) async {
        capturedUri = request.url;
        capturedMethod = request.method;
        return http.Response(
          jsonEncode({
            'id': 'sess-123',
            'counselor_id': 'psy-1',
            'scheduled_start_time': '2026-11-26T02:00:00Z',
            'duration_minutes': 60,
            'status': 'live',
            'is_extended': true,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = VideoCallRepositoryImpl(
        dataSource:
            RemoteVideoCallDataSource(apiClient: ApiClient(client: mockHttp)),
      );
      final updated = await repo.extendSession('sess-123');

      expect(capturedMethod, 'POST');
      expect(capturedUri.path, endsWith('/sessions/sess-123/extend'));
      expect(updated.durationMinutes, 60);
      expect(updated.isExtended, isTrue);
    });

    test('VideoCallRepositoryImpl propagates 409 conflict without silent mock fallback',
        () async {
      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({'detail': 'Sesi tidak dapat diperpanjang.'}),
          409,
          headers: {'content-type': 'application/json'},
        );
      });

      final repo = VideoCallRepositoryImpl(
        dataSource:
            RemoteVideoCallDataSource(apiClient: ApiClient(client: mockHttp)),
      );

      expect(
        () => repo.extendSession('sess-123'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409)),
      );
    });
  });
}

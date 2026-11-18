import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../config/app_config.dart';
import '../models/video_call_session_dto.dart';
import 'video_call_datasource.dart';
import 'mock_video_call_datasource.dart';

class RemoteVideoCallDataSource implements VideoCallDataSource {
  final http.Client client;
  final MockVideoCallDataSource _fallback = MockVideoCallDataSource();

  RemoteVideoCallDataSource({http.Client? client})
      : client = client ?? http.Client();

  @override
  Future<VideoCallSessionDto> joinRoom(String sessionId) async {
    try {
      final uri = Uri.parse(
          '${AppConfig.baseUrl}/care/sessions/$sessionId/video-token');
      final response = await client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (AppConfig.authToken != null)
            'Authorization': 'Bearer ${AppConfig.authToken}',
        },
      ).timeout(AppConfig.hybridTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return VideoCallSessionDto.fromJson(data);
      }
      return await _fallback.joinRoom(sessionId);
    } catch (_) {
      return await _fallback.joinRoom(sessionId);
    }
  }

  @override
  Future<void> leaveRoom(String sessionId) async {
    try {
      final uri = Uri.parse(
          '${AppConfig.baseUrl}/care/sessions/$sessionId/status');
      await client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (AppConfig.authToken != null)
            'Authorization': 'Bearer ${AppConfig.authToken}',
        },
        body: jsonEncode({'status': 'completed'}),
      ).timeout(AppConfig.hybridTimeout);
    } catch (_) {
      await _fallback.leaveRoom(sessionId);
    }
  }

  @override
  Future<void> updateMediaState({
    required String sessionId,
    required bool isMicMuted,
    required bool isCameraOff,
  }) async {
    try {
      final uri = Uri.parse(
          '${AppConfig.baseUrl}/care/sessions/$sessionId/media-state');
      await client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (AppConfig.authToken != null)
            'Authorization': 'Bearer ${AppConfig.authToken}',
        },
        body: jsonEncode({
          'is_mic_muted': isMicMuted,
          'is_camera_off': isCameraOff,
        }),
      ).timeout(AppConfig.hybridTimeout);
    } catch (_) {
      await _fallback.updateMediaState(
        sessionId: sessionId,
        isMicMuted: isMicMuted,
        isCameraOff: isCameraOff,
      );
    }
  }
}

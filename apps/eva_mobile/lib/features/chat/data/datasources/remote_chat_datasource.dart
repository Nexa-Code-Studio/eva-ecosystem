import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'chat_datasource.dart';
import '../models/conversation_model.dart';
import '../models/chat_message_model.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';

class RemoteChatDataSource implements ChatDataSource {
  final ApiClient _apiClient;

  RemoteChatDataSource({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  @override
  Future<List<ConversationModel>> getConversations() async {
    final response = await _apiClient.get('/conversations');
    final List<dynamic> list;
    if (response is Map && response['items'] is List) {
      list = response['items'] as List;
    } else if (response is List) {
      list = response;
    } else {
      list = [];
    }
    return list.map((e) => ConversationModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<ConversationModel?> getConversationById(String id) async {
    final response = await _apiClient.get('/conversations/$id');
    if (response == null) return null;
    return ConversationModel.fromJson(response);
  }

  @override
  Future<ChatMessageModel> sendMessage(String conversationId, String text) async {
    final response = await _apiClient.post('/conversations/$conversationId/messages', body: {
      'content': text,
      'modality': 'text',
    });
    return ChatMessageModel.fromJson(response);
  }

  @override
  Stream<String> streamConversationSummary(String conversationId) async* {
    final headers = await AppConfig.getAuthHeaders();
    final url = Uri.parse('${AppConfig.baseUrl}/conversations/$conversationId/summary/stream');
    final request = http.Request('GET', url);
    request.headers.addAll(headers);

    final client = http.Client();
    try {
      final streamedResponse = await client.send(request).timeout(const Duration(seconds: 25));
      if (streamedResponse.statusCode != 200) {
        throw ApiException('Failed to stream summary', statusCode: streamedResponse.statusCode);
      }

      final stream = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in stream) {
        final trimmed = line.trim();
        if (trimmed.startsWith('data:')) {
          final jsonStr = trimmed.substring(5).trim();
          if (jsonStr.isEmpty) continue;
          try {
            final payload = jsonDecode(jsonStr);
            if (payload is Map && payload.containsKey('token')) {
              yield payload['token']?.toString() ?? '';
            }
          } catch (_) {}
        }
      }
    } finally {
      client.close();
    }
  }
}

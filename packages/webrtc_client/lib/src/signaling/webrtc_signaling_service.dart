import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/webrtc_signaling_message.dart';

abstract class IWebRtcSignalingService {
  Stream<SignalingMessage> get messageStream;
  bool get isConnected;

  Future<void> connect(String wsUrl);
  void sendMessage(SignalingMessage message);
  Future<void> disconnect();
  void dispose();
}

class WebRtcSignalingService implements IWebRtcSignalingService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _heartbeatTimer;
  bool _isConnected = false;

  final _messageController = StreamController<SignalingMessage>.broadcast();

  @override
  Stream<SignalingMessage> get messageStream => _messageController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> connect(String wsUrl) async {
    await disconnect();

    try {
      final uri = Uri.parse(wsUrl);
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
      _isConnected = true;

      _subscription = _channel!.stream.listen(
        (data) {
          try {
            final jsonMap = jsonDecode(data.toString()) as Map<String, dynamic>;
            final message = SignalingMessage.fromJson(jsonMap);

            if (message.type == 'ping') {
              sendMessage(SignalingMessage.create(type: 'pong'));
              return;
            }

            _messageController.add(message);
          } catch (e) {
            debugPrint('[WebRtcSignalingService] Error decoding message: $e');
          }
        },
        onError: (err) {
          debugPrint('[WebRtcSignalingService] WebSocket error: $err');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('[WebRtcSignalingService] WebSocket connection closed');
          _handleDisconnect();
        },
      );

      _startHeartbeat();
    } catch (e) {
      debugPrint('[WebRtcSignalingService] Connect failed: $e');
      _handleDisconnect();
      rethrow;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (_isConnected) {
        sendMessage(SignalingMessage.create(type: 'ping'));
      }
    });
  }

  void _handleDisconnect() {
    _isConnected = false;
    _heartbeatTimer?.cancel();
  }

  @override
  void sendMessage(SignalingMessage message) {
    if (_channel != null && _isConnected) {
      try {
        final payloadStr = jsonEncode(message.toJson());
        _channel!.sink.add(payloadStr);
      } catch (e) {
        debugPrint('[WebRtcSignalingService] Failed to send message: $e');
      }
    }
  }

  @override
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _isConnected = false;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  @override
  void dispose() {
    disconnect();
    _messageController.close();
  }
}

class MockSignalingService implements IWebRtcSignalingService {
  final _messageController = StreamController<SignalingMessage>.broadcast();
  bool _connected = false;

  @override
  Stream<SignalingMessage> get messageStream => _messageController.stream;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect(String wsUrl) async {
    _connected = true;
  }

  @override
  void sendMessage(SignalingMessage message) {
    // In mock mode, we can loop back or inspect sent messages
  }

  void emitMockMessage(SignalingMessage message) {
    _messageController.add(message);
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  void dispose() {
    _connected = false;
    _messageController.close();
  }
}

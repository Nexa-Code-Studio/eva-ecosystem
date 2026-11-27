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

/// WebSocket signaling client with heartbeat and bounded exponential-backoff
/// auto-reconnect. After a successful automatic reconnect it emits a local
/// `ws_reconnected` message so controllers can trigger an ICE restart.
class WebRtcSignalingService implements IWebRtcSignalingService {
  static const int _maxReconnectAttempts = 6;

  /// Close codes after which reconnecting is pointless (normal close,
  /// superseded by a newer connection, invalid token, forbidden role).
  static const Set<int> _terminalCloseCodes = {1000, 4009, 4401, 4403};

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  bool _manuallyClosed = false;
  bool _isDisposed = false;
  int _reconnectAttempts = 0;
  String? _wsUrl;

  final _messageController = StreamController<SignalingMessage>.broadcast();

  @override
  Stream<SignalingMessage> get messageStream => _messageController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> connect(String wsUrl) async {
    _manuallyClosed = false;
    _wsUrl = wsUrl;
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();

    try {
      await _open(wsUrl);
    } catch (e) {
      debugPrint('[WebRtcSignalingService] Connect failed: $e');
      _scheduleReconnect();
      rethrow;
    }
  }

  Future<void> _open(String wsUrl) async {
    await _teardownChannel();

    final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _channel = channel;
    await channel.ready;
    _isConnected = true;

    _subscription = channel.stream.listen(
      (data) {
        try {
          final jsonMap = jsonDecode(data.toString()) as Map<String, dynamic>;
          final message = SignalingMessage.fromJson(jsonMap);

          if (message.type == 'ping') {
            sendMessage(SignalingMessage.create(type: 'pong'));
            return;
          }

          _emit(message);
        } catch (e) {
          debugPrint('[WebRtcSignalingService] Error decoding message: $e');
        }
      },
      onError: (err) {
        debugPrint('[WebRtcSignalingService] WebSocket error: $err');
        _handleDisconnect(channel);
      },
      onDone: () {
        debugPrint('[WebRtcSignalingService] WebSocket connection closed');
        _handleDisconnect(channel);
      },
    );

    _startHeartbeat();
  }

  void _emit(SignalingMessage message) {
    if (!_messageController.isClosed) {
      _messageController.add(message);
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

  void _handleDisconnect(WebSocketChannel channel) {
    if (!identical(_channel, channel)) return;

    final closeCode = channel.closeCode;
    _isConnected = false;
    _heartbeatTimer?.cancel();

    if (_manuallyClosed || _isDisposed) return;
    if (closeCode != null && _terminalCloseCodes.contains(closeCode)) {
      debugPrint(
          '[WebRtcSignalingService] Terminal close code $closeCode, not reconnecting');
      return;
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_manuallyClosed || _isDisposed || _wsUrl == null) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[WebRtcSignalingService] Reconnect attempts exhausted');
      return;
    }

    _reconnectTimer?.cancel();
    final shift = _reconnectAttempts > 3 ? 3 : _reconnectAttempts;
    final delay = Duration(seconds: 1 << shift);
    _reconnectAttempts++;

    _reconnectTimer = Timer(delay, () async {
      if (_manuallyClosed || _isDisposed || _wsUrl == null) return;
      try {
        await _open(_wsUrl!);
        _reconnectAttempts = 0;
        _emit(SignalingMessage.create(type: 'ws_reconnected'));
      } catch (e) {
        debugPrint('[WebRtcSignalingService] Reconnect failed: $e');
        _scheduleReconnect();
      }
    });
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

  Future<void> _teardownChannel() async {
    _heartbeatTimer?.cancel();
    _isConnected = false;

    final sub = _subscription;
    _subscription = null;
    await sub?.cancel();

    final channel = _channel;
    _channel = null;
    try {
      await channel?.sink.close();
    } catch (_) {}
  }

  @override
  Future<void> disconnect() async {
    _manuallyClosed = true;
    _reconnectTimer?.cancel();
    await _teardownChannel();
  }

  @override
  void dispose() {
    _isDisposed = true;
    disconnect();
    if (!_messageController.isClosed) {
      _messageController.close();
    }
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

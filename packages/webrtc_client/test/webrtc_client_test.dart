import 'package:flutter_test/flutter_test.dart';
import 'package:webrtc_client/webrtc_client.dart';

void main() {
  group('webrtc_client Shared Package Unit Tests', () {
    test('IceServerConfig parses and converts correctly', () {
      final config = IceServerConfig.fromJson({
        'urls': ['stun:stun.cloudflare.com:3478', 'turn:turn.cloudflare.com:3478'],
        'username': 'user123',
        'credential': 'secret-token',
      });

      expect(config.urls.length, 2);
      expect(config.username, 'user123');
      expect(config.credential, 'secret-token');

      final map = config.toMap();
      expect(map['urls'], ['stun:stun.cloudflare.com:3478', 'turn:turn.cloudflare.com:3478']);
      expect(map['username'], 'user123');
      expect(map['credential'], 'secret-token');
    });

    test('VideoQualityPreset dimensions and bitrate constraints match spec', () {
      expect(VideoQualityPreset.hd720p.targetWidth, 1280);
      expect(VideoQualityPreset.hd720p.targetHeight, 720);
      expect(VideoQualityPreset.hd720p.maxBitrateBps, 1500000);

      expect(VideoQualityPreset.sd480p.targetWidth, 640);
      expect(VideoQualityPreset.sd480p.targetHeight, 480);
      expect(VideoQualityPreset.sd480p.maxBitrateBps, 800000);

      expect(VideoQualityPreset.audioOnly.targetWidth, 0);
      expect(VideoQualityPreset.audioOnly.targetHeight, 0);
      expect(VideoQualityPreset.audioOnly.maxBitrateBps, 64000);
    });

    test('SignalingMessage creates standard envelope and round-trips via JSON', () {
      final msg = SignalingMessage.create(
        type: 'room_ready',
        senderRole: 'counselor',
        senderId: 'counselor-01',
        payload: {'session_id': 'session-123', 'is_offerer': true},
      );

      expect(msg.type, 'room_ready');
      expect(msg.senderRole, 'counselor');
      expect(msg.payload['session_id'], 'session-123');

      final json = msg.toJson();
      final parsed = SignalingMessage.fromJson(json);

      expect(parsed.type, 'room_ready');
      expect(parsed.senderRole, 'counselor');
      expect(parsed.payload['is_offerer'], true);
    });

    test('MockSignalingService connects and emits messages', () async {
      final signaling = MockSignalingService();
      await signaling.connect('ws://localhost/api/v1/care/ws/test');
      expect(signaling.isConnected, true);

      final expectation = expectLater(
        signaling.messageStream,
        emits(predicate<SignalingMessage>((m) => m.type == 'offer')),
      );

      signaling.emitMockMessage(SignalingMessage.create(type: 'offer'));
      await expectation;

      await signaling.disconnect();
      expect(signaling.isConnected, false);
      signaling.dispose();
    });

    test('MockWebRtcPeerManager creates mock offers and answers cleanly', () async {
      final peer = MockWebRtcPeerManager();
      await peer.initializeRenderers();
      expect(peer.isInitialized, true);

      final offer = await peer.createOffer();
      expect(offer.type, 'offer');

      final answer = await peer.createAnswer();
      expect(answer.type, 'answer');

      await peer.dispose();
      expect(peer.isInitialized, false);
    });
  });
}

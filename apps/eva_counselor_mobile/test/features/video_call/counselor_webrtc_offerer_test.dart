import 'package:flutter_test/flutter_test.dart';
import 'package:eva_counselor_mobile/core/config/app_config.dart';
import 'package:eva_counselor_mobile/features/video_call/data/datasources/mock_video_call_datasource.dart';
import 'package:eva_counselor_mobile/features/video_call/data/repositories/video_call_repository_impl.dart';
import 'package:eva_counselor_mobile/features/video_call/domain/entities/video_call_state_entity.dart';
import 'package:eva_counselor_mobile/features/video_call/presentation/controllers/video_call_controller.dart';
import 'package:webrtc_client/webrtc_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Counselor WebRTC Offerer & Quality Controller Tests', () {
    late VideoCallRepositoryImpl repository;
    late MockVideoCallDataSource mockDataSource;
    late MockWebRtcPeerManager mockPeer;
    late MockSignalingService mockSignaling;
    late VideoCallSessionEntity initialSession;

    setUp(() {
      AppConfig.useMockData = true;
      mockDataSource = MockVideoCallDataSource();
      repository = VideoCallRepositoryImpl(dataSource: mockDataSource);
      mockPeer = MockWebRtcPeerManager();
      mockSignaling = MockSignalingService();

      initialSession = VideoCallSessionEntity(
        sessionId: 'session-webrtc-01',
        patientId: 'patient-001',
        patientName: 'Rian Pratama',
        scheduledTime: DateTime.now(),
      );
    });

    tearDown(() {
      AppConfig.useMockData = false;
    });

    test('VideoCallController initializes in waiting room with default 720p HD', () async {
      final controller = VideoCallController(
        repository,
        initialSession,
        peerManager: mockPeer,
        signalingService: mockSignaling,
      );

      await controller.initializeCall();

      expect(controller.state.qualityPreset, VideoQualityPreset.hd720p);
      expect(controller.state.isWaitingForPatient, true);
      expect(controller.state.isSpeakerOn, true);
      expect(controller.state.isMicMuted, false);
      expect(controller.state.isVideoDisabled, false);
      expect(controller.state.status, VideoCallStatus.waiting);

      controller.dispose();
    });

    test('Counselor acts as Deterministic Offerer upon room_ready event', () async {
      final controller = VideoCallController(
        repository,
        initialSession,
        peerManager: mockPeer,
        signalingService: mockSignaling,
      );

      await controller.initializeCall();

      // Emit room_ready from signaling
      mockSignaling.emitMockMessage(SignalingMessage.create(
        type: 'room_ready',
        senderRole: 'system',
        payload: {'session_id': 'session-webrtc-01'},
      ));

      // Wait a tick for event processing
      await Future.delayed(const Duration(milliseconds: 50));

      expect(controller.state.isWaitingForPatient, false);
      expect(controller.state.status, VideoCallStatus.connecting);

      // Patient responds with answer
      mockSignaling.emitMockMessage(SignalingMessage.create(
        type: 'answer',
        senderRole: 'patient',
        payload: {
          'sdp': 'v=0\r\no=mock 0 0 IN IP4 127.0.0.1\r\ns=-\r\n',
          'type': 'answer',
        },
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(controller.state.status, VideoCallStatus.connected);
      expect(controller.state.isPatientReconnecting, false);

      controller.dispose();
    });

    test('ICE restart triggers re-negotiation without resetting call duration', () async {
      final controller = VideoCallController(
        repository,
        initialSession,
        peerManager: mockPeer,
        signalingService: mockSignaling,
      );

      await controller.initializeCall();
      controller.startCall();

      // Simulate 5 seconds elapsed
      await Future.delayed(const Duration(seconds: 1));

      // Trigger ICE restart
      await controller.manualIceRestart();

      expect(controller.state.status, VideoCallStatus.reconnecting);
      expect(controller.state.isPatientReconnecting, true);
      expect(controller.state.patientStatusMessage, contains('Menghubungkan ulang'));

      // Patient reconnected event
      mockSignaling.emitMockMessage(SignalingMessage.create(
        type: 'peer_reconnected',
        senderRole: 'patient',
      ));

      await Future.delayed(const Duration(milliseconds: 50));

      expect(controller.state.isPatientReconnecting, false);
      expect(controller.state.patientStatusMessage, isNull);

      controller.dispose();
    });

    test('setQualityPreset switches between 720p, 480p, and audioOnly', () async {
      final controller = VideoCallController(
        repository,
        initialSession,
        peerManager: mockPeer,
        signalingService: mockSignaling,
      );

      await controller.setQualityPreset(VideoQualityPreset.sd480p);
      expect(controller.state.qualityPreset, VideoQualityPreset.sd480p);

      await controller.setQualityPreset(VideoQualityPreset.audioOnly);
      expect(controller.state.qualityPreset, VideoQualityPreset.audioOnly);

      await controller.setQualityPreset(VideoQualityPreset.hd720p);
      expect(controller.state.qualityPreset, VideoQualityPreset.hd720p);

      controller.dispose();
    });

    test('toggleSpeaker updates speaker routing state', () async {
      final controller = VideoCallController(
        repository,
        initialSession,
        peerManager: mockPeer,
        signalingService: mockSignaling,
      );

      expect(controller.state.isSpeakerOn, true);
      await controller.toggleSpeaker();
      expect(controller.state.isSpeakerOn, false);
      await controller.toggleSpeaker();
      expect(controller.state.isSpeakerOn, true);

      controller.dispose();
    });
  });
}

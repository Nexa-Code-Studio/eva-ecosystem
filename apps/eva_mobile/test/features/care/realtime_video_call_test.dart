import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webrtc_client/webrtc_client.dart';

import 'package:eva_mobile/config/app_config.dart';
import 'package:eva_mobile/features/care/domain/entities/consultation_session_entity.dart';
import 'package:eva_mobile/features/care/domain/entities/psychologist_entity.dart';
import 'package:eva_mobile/features/care/domain/entities/video_call_state_entity.dart';
import 'package:eva_mobile/features/care/data/datasources/mock_video_call_datasource.dart';
import 'package:eva_mobile/features/care/data/repositories/video_call_repository_impl.dart';
import 'package:eva_mobile/features/care/presentation/controllers/video_call_controller.dart';
import 'package:eva_mobile/features/care/presentation/screens/psychologist_video_call_screen.dart';
import 'package:eva_mobile/features/care/presentation/widgets/consultation_result_bottom_sheet.dart';

import '../../test_helpers/mock_image_http.dart';

void main() {
  setUp(() {
    AppConfig.useMockData = true;
    SharedPreferences.setMockInitialValues({});
  });

  final dummyPsychologist = const PsychologistEntity(
    id: 'psy-001',
    name: 'Dr. Sarah Wilson, M.Psi',
    title: 'Psikolog Klinis Dewasa',
    registrationNumber: 'STR-PSY-1234',
    specialties: ['Kecemasan & Burnout'],
    avatarUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2',
    rating: 4.9,
    reviewCount: 142,
    experienceYears: 8,
    bio: 'Fokus pada terapi kognitif perilaku (CBT).',
  );

  final dummySession = ConsultationSessionEntity(
    id: 'session-vc-101',
    psychologist: dummyPsychologist,
    sessionDateTime: DateTime.now(),
    status: ConsultationStatus.upcoming,
    sessionNumber: 1,
    durationMinutes: 30,
    adviceList: const ['Latihan pernapasan 4-7-8 setiap pagi.'],
    actionItems: const ['Catat pemicu stres harian di jurnal.'],
  );

  group('VideoCall DataSource & Repository Unit Tests', () {
    test('MockVideoCallDataSource returns valid room session DTO with iceServerConfigs', () async {
      final dataSource = MockVideoCallDataSource();
      final dto = await dataSource.joinRoom('test-session-1');

      expect(dto.sessionId, 'test-session-1');
      expect(dto.roomId, contains('test-session-1'));
      expect(dto.token, contains('mock-webrtc-token'));
      expect(dto.status, 'active');
      expect(dto.iceServers, isNotEmpty);
      expect(dto.iceServerConfigs, isNotEmpty);
      expect(dto.wsUrl, contains('test-session-1'));
    });

    test('VideoCallRepositoryImpl initializes call state with ICE servers', () async {
      final repository =
          VideoCallRepositoryImpl(dataSource: MockVideoCallDataSource());
      final state = await repository.joinCall(dummySession);

      expect(state.connectionState, VideoCallConnectionState.connecting);
      expect(state.isMicMuted, isFalse);
      expect(state.isCameraOff, isFalse);
      expect(state.isSpeakerOn, isTrue);
      expect(state.isFrontCamera, isTrue);
      expect(state.roomId, contains('session-vc-101'));
      expect(state.iceServers, isNotEmpty);
    });
  });

  group('VideoCallController Answerer Logic Tests', () {
    test('Toggles mic, camera, speaker, camera switch and quality presets',
        () async {
      final repository =
          VideoCallRepositoryImpl(dataSource: MockVideoCallDataSource());
      final mockPeer = MockWebRtcPeerManager();
      final mockSignaling = MockSignalingService();

      final controller = VideoCallController(
        repository: repository,
        initialSession: dummySession,
        peerManager: mockPeer,
        signalingService: mockSignaling,
      );

      // Wait initial async join
      await Future.delayed(const Duration(milliseconds: 350));
      expect(controller.state.connectionState, VideoCallConnectionState.connected);

      // Toggle Mic
      controller.toggleMic();
      expect(controller.state.isMicMuted, isTrue);
      controller.toggleMic();
      expect(controller.state.isMicMuted, isFalse);

      // Toggle Camera
      controller.toggleCamera();
      expect(controller.state.isCameraOff, isTrue);
      controller.toggleCamera();
      expect(controller.state.isCameraOff, isFalse);

      // Switch Camera
      await controller.switchCamera();
      expect(controller.state.isFrontCamera, isFalse);
      await controller.switchCamera();
      expect(controller.state.isFrontCamera, isTrue);

      // Toggle Speaker
      await controller.toggleSpeaker();
      expect(controller.state.isSpeakerOn, isFalse);
      await controller.toggleSpeaker();
      expect(controller.state.isSpeakerOn, isTrue);

      // Quality preset change
      await controller.setVideoQualityPreset(VideoQualityPreset.sd480p);
      expect(controller.state.qualityPreset, VideoQualityPreset.sd480p);

      await controller.setVideoQualityPreset(VideoQualityPreset.audioOnly);
      expect(controller.state.qualityPreset, VideoQualityPreset.audioOnly);

      // Manual ICE restart request
      await controller.manualIceRestart();
      expect(controller.state.connectionState, VideoCallConnectionState.reconnecting);

      // End Call
      await controller.endCall();
      expect(controller.state.connectionState, VideoCallConnectionState.ended);
    });

    test('Reacts to Answerer signaling messages (room_ready, offer, reconnect)',
        () async {
      final repository =
          VideoCallRepositoryImpl(dataSource: MockVideoCallDataSource());
      final mockPeer = MockWebRtcPeerManager();
      final mockSignaling = MockSignalingService();

      final controller = VideoCallController(
        repository: repository,
        initialSession: dummySession,
        peerManager: mockPeer,
        signalingService: mockSignaling,
      );

      await Future.delayed(const Duration(milliseconds: 50));

      // 1. Receive room_ready from counselor
      mockSignaling.emitMockMessage(SignalingMessage.create(
        type: 'room_ready',
        senderRole: 'counselor',
      ));
      await Future.delayed(const Duration(milliseconds: 20));
      expect(controller.state.isWaitingForCounselor, isFalse);

      // 2. Receive offer from counselor -> creates answer
      mockSignaling.emitMockMessage(SignalingMessage.create(
        type: 'offer',
        senderRole: 'counselor',
        payload: {
          'sdp': 'v=0\r\no=counselor 0 0 IN IP4 127.0.0.1\r\ns=-\r\n',
          'type': 'offer',
        },
      ));
      await Future.delayed(const Duration(milliseconds: 20));
      expect(controller.state.connectionState, VideoCallConnectionState.connected);

      // 3. Receive peer_reconnecting
      mockSignaling.emitMockMessage(SignalingMessage.create(
        type: 'peer_reconnecting',
        senderRole: 'system',
      ));
      await Future.delayed(const Duration(milliseconds: 20));
      expect(controller.state.connectionState, VideoCallConnectionState.reconnecting);
      expect(controller.state.isCounselorReconnecting, isTrue);

      // 4. Receive peer_reconnected
      mockSignaling.emitMockMessage(SignalingMessage.create(
        type: 'peer_reconnected',
        senderRole: 'system',
      ));
      await Future.delayed(const Duration(milliseconds: 20));
      expect(controller.state.connectionState, VideoCallConnectionState.connected);
      expect(controller.state.isCounselorReconnecting, isFalse);

      await controller.endCall();
    });
  });

  group('PsychologistVideoCallScreen Widget Tests', () {
    testWidgets(
        'Renders video stream, PIP preview, media controls, and handles interaction',
        (tester) async {
      runWithMockImages(() async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(disableAnimations: true),
                child: PsychologistVideoCallScreen(session: dummySession),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // 1. Verify psychologist name & header info
        expect(find.text('Dr. Sarah Wilson, M.Psi'), findsOneWidget);
        expect(find.byType(PsychologistVideoCallScreen), findsOneWidget);

        // 2. Verify interactive media control buttons
        expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
        expect(find.byIcon(Icons.videocam_rounded), findsOneWidget);
        expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
        expect(find.byIcon(Icons.edit_note_rounded), findsOneWidget);
        expect(find.byIcon(Icons.call_end_rounded), findsOneWidget);
        expect(find.byIcon(Icons.tune_rounded), findsOneWidget);

        // 3. Test Mic Mute toggle
        await tester.tap(find.byIcon(Icons.mic_rounded));
        await tester.pump();
        expect(find.byIcon(Icons.mic_off_rounded), findsOneWidget);

        // 4. Test Camera Off toggle
        await tester.tap(find.byIcon(Icons.videocam_rounded));
        await tester.pump();
        expect(find.byIcon(Icons.videocam_off_rounded), findsWidgets);
        expect(find.text('Kamera Mati'), findsOneWidget);

        // 5. Test Speaker toggle
        await tester.tap(find.byIcon(Icons.volume_up_rounded));
        await tester.pump();
        expect(find.byIcon(Icons.volume_down_rounded), findsOneWidget);

        // 6. Test Quality Preset Sheet
        await tester.tap(find.byIcon(Icons.tune_rounded));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Kualitas Video Konsultasi'), findsOneWidget);
        expect(find.text('720p HD (Rekomendasi)'), findsOneWidget);
        expect(find.text('480p Hemat Data'), findsOneWidget);
        expect(find.text('Audio-Only (Kamera Mati)'), findsOneWidget);

        // Select 480p
        await tester.tap(find.text('480p Hemat Data'));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('480p'), findsOneWidget);

        // 7. Test End Call Confirmation & Result Bottom Sheet Navigation
        await tester.tap(find.byIcon(Icons.call_end_rounded));
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Akhiri Sesi Konsultasi?'), findsOneWidget);
        expect(find.text('Ya, Selesaikan'), findsOneWidget);

        await tester.tap(find.text('Ya, Selesaikan'));
        await tester.pumpAndSettle();

        // Verify ConsultationResultBottomSheet displays advice & action items
        expect(find.byType(ConsultationResultBottomSheet), findsOneWidget);
        expect(find.text('Hasil & Saran Sesi Konsultasi'), findsOneWidget);
        expect(find.text('LATIHAN MANDIRI (ACTION ITEMS)'), findsOneWidget);

        // Tap close bottom sheet
        await tester.tap(find.text('Selesai & Tutup Saran Sesi'));
        await tester.pumpAndSettle();
      });
    });
  });
}

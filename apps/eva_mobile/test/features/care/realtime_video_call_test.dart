import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    test('MockVideoCallDataSource returns valid room session DTO', () async {
      final dataSource = MockVideoCallDataSource();
      final dto = await dataSource.joinRoom('test-session-1');

      expect(dto.sessionId, 'test-session-1');
      expect(dto.roomId, contains('test-session-1'));
      expect(dto.token, contains('mock-webrtc-token'));
      expect(dto.status, 'active');
      expect(dto.iceServers, isNotEmpty);
    });

    test('VideoCallRepositoryImpl initializes connected call state', () async {
      final repository =
          VideoCallRepositoryImpl(dataSource: MockVideoCallDataSource());
      final state = await repository.joinCall(dummySession);

      expect(state.connectionState, VideoCallConnectionState.connected);
      expect(state.isMicMuted, isFalse);
      expect(state.isCameraOff, isFalse);
      expect(state.isSpeakerOn, isTrue);
      expect(state.isFrontCamera, isTrue);
      expect(state.roomId, contains('session-vc-101'));
    });
  });

  group('VideoCallController Logic Tests', () {
    test('Toggles mic, camera, speaker, and front camera state properly',
        () async {
      final repository =
          VideoCallRepositoryImpl(dataSource: MockVideoCallDataSource());
      final controller = VideoCallController(
        repository: repository,
        initialSession: dummySession,
      );

      // Wait initial async join
      await Future.delayed(const Duration(milliseconds: 350));
      expect(controller.state.connectionState,
          VideoCallConnectionState.connected);

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
      controller.switchCamera();
      expect(controller.state.isFrontCamera, isFalse);
      controller.switchCamera();
      expect(controller.state.isFrontCamera, isTrue);

      // Toggle Speaker
      controller.toggleSpeaker();
      expect(controller.state.isSpeakerOn, isFalse);
      controller.toggleSpeaker();
      expect(controller.state.isSpeakerOn, isTrue);

      // End Call
      await controller.endCall();
      expect(controller.state.connectionState, VideoCallConnectionState.ended);
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
              home: PsychologistVideoCallScreen(session: dummySession),
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
        expect(find.byIcon(Icons.flip_camera_ios_rounded), findsWidgets);
        expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
        expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
        expect(find.byIcon(Icons.call_end_rounded), findsOneWidget);

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
        expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);

        // 6. Test End Call Confirmation & Result Bottom Sheet Navigation
        await tester.tap(find.byIcon(Icons.call_end_rounded));
        await tester.pumpAndSettle();

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

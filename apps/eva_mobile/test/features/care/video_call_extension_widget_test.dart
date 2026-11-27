import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webrtc_client/webrtc_client.dart';

import 'package:eva_mobile/config/app_config.dart';
import 'package:eva_mobile/features/care/domain/entities/consultation_session_entity.dart';
import 'package:eva_mobile/features/care/domain/entities/extension_availability_entity.dart';
import 'package:eva_mobile/features/care/domain/entities/psychologist_entity.dart';
import 'package:eva_mobile/features/care/domain/entities/video_call_state_entity.dart';
import 'package:eva_mobile/features/care/domain/repositories/video_call_repository.dart';
import 'package:eva_mobile/features/care/presentation/controllers/video_call_controller.dart';
import 'package:eva_mobile/features/care/presentation/providers/video_call_provider.dart';
import 'package:eva_mobile/features/care/presentation/screens/psychologist_video_call_screen.dart';
import 'package:eva_mobile/features/care/presentation/screens/booking_consultation_screen.dart';
import 'package:eva_mobile/features/coin/presentation/providers/coin_provider.dart';

import '../../test_helpers/mock_image_http.dart';

class _FakeVideoCallRepository implements VideoCallRepository {
  final bool canExtend;
  final double extensionPrice;
  final String? reason;
  final List<ExtensionSlotOption> nextSlots;
  int extendCallCount = 0;

  _FakeVideoCallRepository({
    required this.canExtend,
    this.extensionPrice = 50,
    this.reason,
    this.nextSlots = const [],
  });

  @override
  Future<VideoCallStateEntity> joinCall(ConsultationSessionEntity session) async {
    return VideoCallStateEntity(
      session: session,
      connectionState: VideoCallConnectionState.connected,
      roomId: 'room-${session.id}',
      maxDurationSeconds: session.durationMinutes * 60,
      isWaitingForCounselor: false,
    );
  }

  @override
  Future<void> endCall(String sessionId) async {}

  @override
  Future<ExtensionAvailabilityEntity> checkExtensionAvailability(
      String sessionId) async {
    return ExtensionAvailabilityEntity(
      sessionId: sessionId,
      canExtend: canExtend,
      extensionPrice: extensionPrice,
      reason: reason,
      nextAvailableSlots: nextSlots,
    );
  }

  @override
  Future<ConsultationSessionEntity> extendSession(String sessionId) async {
    extendCallCount++;
    return ConsultationSessionEntity(
      id: sessionId,
      psychologist: const PsychologistEntity(
        id: 'psy-001',
        name: 'Dr. Sarah Wilson, M.Psi',
        title: 'Psikolog Klinis',
        registrationNumber: 'STR-1',
        avatarUrl: '',
        rating: 4.9,
        reviewCount: 10,
        experienceYears: 5,
        specialties: ['CBT'],
        bio: 'Bio',
      ),
      sessionDateTime: DateTime.now(),
      status: ConsultationStatus.upcoming,
      durationMinutes: 60,
      isExtended: true,
    );
  }
}

void main() {
  setUpAll(() {
    HttpOverrides.global = TestHttpOverrides();
  });

  setUp(() {
    AppConfig.useMockData = true;
    SharedPreferences.setMockInitialValues({'user_coin_balance': 200});
  });

  const dummyPsy = PsychologistEntity(
    id: 'psy-001',
    name: 'Dr. Sarah Wilson, M.Psi',
    title: 'Psikolog Klinis',
    registrationNumber: 'STR-PSY-1234',
    avatarUrl: 'https://example.com/avatar.jpg',
    rating: 4.9,
    reviewCount: 142,
    experienceYears: 8,
    specialties: ['Kecemasan'],
    bio: 'CBT specialist',
    coinsPerSession: 50,
  );

  final dummySession = ConsultationSessionEntity(
    id: 'sess-ext-1',
    psychologist: dummyPsy,
    sessionDateTime: DateTime.now(),
    status: ConsultationStatus.upcoming,
    durationMinutes: 30,
  );

  testWidgets(
      'Available extension: shows banner at <=5m left, confirms coins, extends to 60m badge',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeRepo = _FakeVideoCallRepository(canExtend: true, extensionPrice: 50);
    late VideoCallController controller;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoCallRepositoryProvider.overrideWithValue(fakeRepo),
          videoCallControllerProvider(dummySession).overrideWith((ref) {
            controller = VideoCallController(
              repository: fakeRepo,
              initialSession: dummySession,
              peerManager: MockWebRtcPeerManager(),
              signalingService: MockSignalingService(),
            );
            return controller;
          }),
          coinBalanceProvider.overrideWith((ref) => CoinBalanceNotifier(isMockMode: true)),
        ],
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

    // Before minute 25, extension banner is hidden
    expect(find.byKey(const Key('in_call_extend_button')), findsNothing);

    // Move timer to minute 25 (1500s elapsed, 300s remaining)
    controller.state = controller.state.copyWith(
      connectionState: VideoCallConnectionState.connected,
      isWaitingForCounselor: false,
      callDurationSeconds: 1500,
    );
    await tester.pump();

    final extendBtn = find.byKey(const Key('in_call_extend_button'));
    expect(extendBtn, findsOneWidget);
    expect(find.text('Tambah Sesi (+30 Menit)'), findsOneWidget);

    await tester.tap(extendBtn);
    await tester.pumpAndSettle();

    // Confirmation dialog appears with extension fee
    expect(find.text('50 Koin EVA'), findsOneWidget);
    final confirmBtn = find.byKey(const Key('confirm_extend_session_btn'));
    expect(confirmBtn, findsOneWidget);

    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    expect(fakeRepo.extendCallCount, 1);
    expect(find.byKey(const Key('extended_duration_badge')), findsOneWidget);
    expect(find.text('60m'), findsOneWidget);
    expect(find.byKey(const Key('in_call_extend_button')), findsNothing);
  });

  testWidgets(
      'Busy extension: shows friendly sheet and opens BookingConsultationScreen on Schedule Next',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeRepo = _FakeVideoCallRepository(
      canExtend: false,
      reason: 'Perpanjangan (+30 menit) bertabrakan dengan jam istirahat konselor.',
      nextSlots: [
        ExtensionSlotOption(
          startTime: DateTime.utc(2026, 11, 26, 7, 0),
          endTime: DateTime.utc(2026, 11, 26, 7, 30),
        ),
      ],
    );
    late VideoCallController controller;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoCallRepositoryProvider.overrideWithValue(fakeRepo),
          videoCallControllerProvider(dummySession).overrideWith((ref) {
            controller = VideoCallController(
              repository: fakeRepo,
              initialSession: dummySession,
              peerManager: MockWebRtcPeerManager(),
              signalingService: MockSignalingService(),
            );
            return controller;
          }),
        ],
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

    controller.state = controller.state.copyWith(
      connectionState: VideoCallConnectionState.connected,
      isWaitingForCounselor: false,
      callDurationSeconds: 1550,
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('in_call_extend_button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Mohon maaf, psikolog memiliki janji konsultasi lain setelah ini'),
      findsOneWidget,
    );
    expect(find.textContaining('jam istirahat konselor'), findsOneWidget);

    final scheduleNextBtn = find.byKey(const Key('schedule_next_session_btn'));
    expect(scheduleNextBtn, findsOneWidget);

    await tester.tap(scheduleNextBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byType(BookingConsultationScreen), findsOneWidget);
  });
}

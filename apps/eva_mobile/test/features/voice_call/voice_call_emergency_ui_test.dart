import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eva_mobile/features/emergency/presentation/screens/support_emergency_screen.dart';
import 'package:eva_mobile/features/emergency/presentation/widgets/emergency_hotline_modal.dart';
import 'package:eva_mobile/features/voice_call/domain/entities/call_state.dart';
import 'package:eva_mobile/features/voice_call/presentation/controllers/ai_call_controller.dart';
import 'package:eva_mobile/features/voice_call/presentation/providers/ai_call_provider.dart';
import 'package:eva_mobile/features/voice_call/presentation/screens/voice_call_screen.dart';
import 'package:eva_mobile/features/voice_call/presentation/widgets/in_call_emergency_card.dart';

import 'ai_call_controller_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('VoiceCallScreen In-Call Emergency UI', () {
    late FakeSingleAudioCaptureService fakeCapture;
    late FakeAiAudioPlaybackService fakePlayback;
    late FakeVoiceCallWsClient fakeWs;
    late AiCallController controller;

    setUp(() {
      fakeCapture = FakeSingleAudioCaptureService();
      fakePlayback = FakeAiAudioPlaybackService();
      fakeWs = FakeVoiceCallWsClient();
      controller = AiCallController(
        audioCaptureService: fakeCapture,
        audioPlaybackService: fakePlayback,
        wsClient: fakeWs,
      );
    });

    tearDown(() {
      fakePlayback.dispose();
      fakeWs.dispose();
    });

    testWidgets(
      'shows InCallEmergencyCard on crisis escalation while keeping call active and opens hotline modal',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              aiCallControllerProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(
              home: VoiceCallScreen(),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(InCallEmergencyCard), findsNothing);
        expect(controller.state.callState, CallState.listening);

        fakeWs.eventController.add({
          'type': 'ai.crisis_escalation',
          'risk_level': 'high',
          'hotline': 'Kemenkes 119 ext 8 / LISA 0811-3855-472',
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(InCallEmergencyCard), findsOneWidget);
        expect(find.text('Dukungan Darurat Tersedia'), findsOneWidget);
        expect(controller.state.callState, CallState.listening);
        expect(find.byIcon(Icons.call_end), findsOneWidget);

        await tester.tap(find.text('Hotline 119 / LISA'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(EmergencyHotlineModal), findsOneWidget);
        expect(controller.state.callState, isNot(CallState.ended));
      },
    );

    testWidgets(
      'ending a crisis call navigates to SupportEmergencyScreen',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              aiCallControllerProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(
              home: VoiceCallScreen(),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        fakeWs.eventController.add({
          'type': 'ai.crisis_escalation',
          'risk_level': 'critical',
          'hotline': 'Kemenkes 119 ext 8',
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.byIcon(Icons.call_end));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(SupportEmergencyScreen), findsOneWidget);
        expect(fakePlayback.stopCount, greaterThanOrEqualTo(1));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'uses amber 0xFFF59E0B for Jeda AI button and bright Soft Rose-Blush card on crisis',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              aiCallControllerProvider.overrideWith((ref) => controller),
            ],
            child: const MaterialApp(
              home: VoiceCallScreen(),
            ),
          ),
        );

        await tester.pump();
        await controller.enterAiSpeaking(1);
        fakeWs.eventController.add({
          'type': 'ai.crisis_escalation',
          'risk_level': 'high',
          'hotline': 'Kemenkes 119 ext 8',
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final jedaFinder = find.text('Jeda AI');
        expect(jedaFinder, findsOneWidget);
        final button = tester.widget<ElevatedButton>(
          find.ancestor(of: jedaFinder, matching: find.byType(ElevatedButton)),
        );
        final bg = button.style?.backgroundColor?.resolve(<WidgetState>{});
        expect(bg, const Color(0xFFF59E0B));

        final cardContainer = tester.widget<Container>(
          find.descendant(
            of: find.byType(InCallEmergencyCard),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Container &&
                  w.decoration is BoxDecoration &&
                  (w.decoration as BoxDecoration).gradient is LinearGradient,
            ),
          ).first,
        );
        final gradient =
            (cardContainer.decoration as BoxDecoration).gradient as LinearGradient;
        expect(gradient.colors, const [Color(0xFFFFF1F2), Color(0xFFFFE4E6)]);
      },
    );
  });
}

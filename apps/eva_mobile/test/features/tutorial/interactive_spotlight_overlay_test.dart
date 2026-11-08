import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eva_mobile/features/tutorial/domain/entities/tutorial_step.dart';
import 'package:eva_mobile/features/tutorial/presentation/widgets/interactive_spotlight_overlay.dart';

void main() {
  group('InteractiveSpotlightOverlay', () {
    testWidgets('allows tap through target cutout while blocking background taps',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool targetTapped = false;
      bool backgroundTapped = false;
      bool skipped = false;

      final targetKey = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                // 1. Background button that SHOULD BE BLOCKED
                Positioned(
                  top: 100,
                  left: 50,
                  child: ElevatedButton(
                    onPressed: () => backgroundTapped = true,
                    child: const Text('Background Button'),
                  ),
                ),

                // 2. Target button that SHOULD BE REACHABLE
                Positioned(
                  bottom: 50,
                  left: 170,
                  child: GestureDetector(
                    key: targetKey,
                    onTap: () => targetTapped = true,
                    child: Container(
                      width: 60,
                      height: 60,
                      color: Colors.blue,
                      child: const Center(child: Text('Target')),
                    ),
                  ),
                ),

                // 3. Spotlight Overlay
                InteractiveSpotlightOverlay(
                  targetKey: targetKey,
                  content: TutorialContent.stepContents[TutorialStep.voiceSession]!,
                  onSkip: () => skipped = true,
                  onTargetTap: () => targetTapped = true,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check card content rendered
      expect(find.text('Cerita ke Eva, yuk!'), findsOneWidget);

      // Attempt tapping the background button outside the cutout
      await tester.tap(find.text('Background Button'));
      await tester.pump();
      expect(
        backgroundTapped,
        isFalse,
        reason: 'Background button must be blocked by the dimmed overlay barrier',
      );

      // Tap the target through the cutout hole
      await tester.tap(find.text('Target'));
      await tester.pump();
      expect(
        targetTapped,
        isTrue,
        reason: 'Target button must receive touch events directly through the cutout',
      );

      // Tap Lewati
      await tester.tap(find.text('Lewati'));
      expect(skipped, isTrue);
    });
  });
}

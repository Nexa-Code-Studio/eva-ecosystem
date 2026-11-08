import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eva_mobile/features/home/presentation/screens/main_shell_screen.dart';
import 'package:eva_mobile/features/tutorial/presentation/widgets/interactive_spotlight_overlay.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MainShellScreen Tutorial Integration', () {
    testWidgets(
        'displays spotlight overlay on center button and navigates when center button is tapped',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool chatRoutePushed = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            routes: {
              '/chat': (context) {
                chatRoutePushed = true;
                return const Scaffold(body: Text('Chat Screen Destination'));
              },
            },
            home: const MainShellScreen(initialIndex: 0),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Overlay is visible with Eva tutorial card
      expect(find.byType(InteractiveSpotlightOverlay), findsOneWidget);
      expect(find.text('Cerita ke Eva, yuk!'), findsOneWidget);
      expect(find.text('REKOMENDASI EVA'), findsOneWidget);

      // 2. Tap the central action button (Icons.auto_awesome) directly through the spotlight cutout
      await tester.tap(find.byIcon(Icons.auto_awesome).last);
      await tester.pumpAndSettle();

      // 3. Navigation was triggered
      expect(chatRoutePushed, isTrue);
      expect(find.text('Chat Screen Destination'), findsOneWidget);
    });

    testWidgets('dismisses spotlight overlay when Lewati is tapped',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MainShellScreen(initialIndex: 0),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(InteractiveSpotlightOverlay), findsOneWidget);

      // Tap Lewati
      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();

      // Overlay dismissed
      expect(find.byType(InteractiveSpotlightOverlay), findsNothing);
    });
  });
}

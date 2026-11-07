import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eva_mobile/config/app_config.dart';
import 'package:eva_mobile/features/auth/presentation/screens/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LoginScreen Demo Autofill Tests', () {
    testWidgets('renders demo autofill button and populates seeded credentials when tapped', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify the demo autofill button is present
      final demoButton = find.byKey(const Key('login_demo_autofill_button'));
      expect(demoButton, findsOneWidget);
      expect(find.text('Gunakan Akun Demo'), findsOneWidget);

      // Verify email and password fields are initially empty
      expect(find.text(AppConfig.demoEmail), findsNothing);
      expect(find.text(AppConfig.demoPassword), findsNothing);

      // Tap the demo autofill button
      await tester.tap(demoButton);
      await tester.pump();

      // Verify fields now contain the seeded demo credentials
      expect(find.text(AppConfig.demoEmail), findsOneWidget);
      expect(find.text(AppConfig.demoPassword), findsOneWidget);

      // Verify confirmation SnackBar is displayed
      expect(
        find.text('Akun demo berhasil diisi (${AppConfig.demoEmail})'),
        findsOneWidget,
      );
    });
  });
}

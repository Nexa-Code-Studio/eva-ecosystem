import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eva_mobile/theme/app_colors.dart';
import 'package:eva_mobile/widgets/app_snack_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSnackBar Widget Tests', () {
    testWidgets('renders primary variant with correct styling and icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppSnackBar.showPrimary(context, 'Pesan Primary');
                },
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump();

      expect(find.text('Pesan Primary'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.behavior, SnackBarBehavior.floating);
      expect(snackBar.backgroundColor, AppColors.primary);
    });

    testWidgets('renders success, warning, and danger variants with respective colors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  ElevatedButton(
                    onPressed: () => AppSnackBar.showSuccess(context, 'Sukses Simpan'),
                    child: const Text('Success'),
                  ),
                  ElevatedButton(
                    onPressed: () => AppSnackBar.showWarning(context, 'Peringatan Form'),
                    child: const Text('Warning'),
                  ),
                  ElevatedButton(
                    onPressed: () => AppSnackBar.showError(context, 'Terjadi Kesalahan'),
                    child: const Text('Danger'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Test Success
      await tester.tap(find.text('Success'));
      await tester.pump();
      expect(find.text('Sukses Simpan'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
      var snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.backgroundColor, AppColors.success);

      // Test Warning (replaces previous snackbar immediately)
      await tester.tap(find.text('Warning'));
      await tester.pump();
      expect(find.text('Peringatan Form'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.backgroundColor, const Color(0xFFF59E0B));

      // Test Danger
      await tester.tap(find.text('Danger'));
      await tester.pump();
      expect(find.text('Terjadi Kesalahan'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snackBar.backgroundColor, const Color(0xFFDC2626));
    });

    testWidgets('supports custom leading widget and showWithMessenger', (tester) async {
      late ScaffoldMessengerState messenger;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                messenger = ScaffoldMessenger.of(context);
                return ElevatedButton(
                  onPressed: () {
                    AppSnackBar.showWithMessenger(
                      messenger,
                      message: 'Sedang Proses...',
                      variant: SnackBarVariant.primary,
                      leading: const SizedBox(
                        key: Key('custom_spinner'),
                        width: 16,
                        height: 16,
                      ),
                    );
                  },
                  child: const Text('Custom'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Custom'));
      await tester.pump();

      expect(find.text('Sedang Proses...'), findsOneWidget);
      expect(find.byKey(const Key('custom_spinner')), findsOneWidget);
    });
  });
}

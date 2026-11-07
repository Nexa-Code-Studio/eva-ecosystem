import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eva_counselor_mobile/features/dashboard/presentation/widgets/counselor_spotlight_tour.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Counselor Spotlight Tour & Navigation Tests', () {
    test('hasSeenTour returns false initially and true after markTourSeen', () async {
      expect(await CounselorSpotlightTourOverlay.hasSeenTour(), isFalse);
      await CounselorSpotlightTourOverlay.markTourSeen();
      expect(await CounselorSpotlightTourOverlay.hasSeenTour(), isTrue);
    });

    testWidgets('Spotlight tour highlights menu with darkened blur backdrop and advances on tap', (tester) async {
      int step = 0;
      bool isClosed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              if (isClosed) {
                return const Scaffold(body: Center(child: Text('Tour Finished')));
              }
              return Scaffold(
                body: CounselorSpotlightTourOverlay(
                  currentStep: step,
                  targetCenter: const Offset(100, 600),
                  onNext: () {
                    if (step < CounselorSpotlightTourOverlay.steps.length - 1) {
                      setState(() => step++);
                    } else {
                      setState(() => isClosed = true);
                    }
                  },
                  onSkip: () {
                    setState(() => isClosed = true);
                  },
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Spotlight overlay should be displayed on step 0
      expect(find.byType(CounselorSpotlightTourOverlay), findsOneWidget);
      expect(find.text('Beranda Praktik Konseling'), findsOneWidget);
      expect(find.text('Menu 1 dari 4'), findsOneWidget);

      // Tap "Lanjut →" to step 2 (Rekam Medis & SOAP)
      await tester.tap(find.text('Lanjut →'));
      await tester.pumpAndSettle();

      expect(find.text('Rekam Medis & SOAP'), findsOneWidget);
      expect(find.text('Menu 2 dari 4'), findsOneWidget);

      // Tap "Lanjut →" to step 3 (Keuangan & Saldo Koin)
      await tester.tap(find.text('Lanjut →'));
      await tester.pumpAndSettle();

      expect(find.text('Keuangan & Saldo Koin'), findsOneWidget);
      expect(find.text('Menu 3 dari 4'), findsOneWidget);

      // Tap "Lanjut →" to step 4 (Profil, Drive E2EE & Sertifikat)
      await tester.tap(find.text('Lanjut →'));
      await tester.pumpAndSettle();

      expect(find.text('Profil, Drive E2EE & Sertifikat'), findsOneWidget);
      expect(find.text('Menu 4 dari 4'), findsOneWidget);
      expect(find.text('Mulai Praktik 🚀'), findsOneWidget);

      // Tap "Mulai Praktik 🚀"
      await tester.tap(find.text('Mulai Praktik 🚀'));
      await tester.pumpAndSettle();

      // Spotlight overlay is dismissed
      expect(find.byType(CounselorSpotlightTourOverlay), findsNothing);
      expect(find.text('Tour Finished'), findsOneWidget);
    });

    testWidgets('Spotlight tour can be skipped immediately with Lewati button', (tester) async {
      bool isClosed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              if (isClosed) {
                return const Scaffold(body: Center(child: Text('Tour Skipped')));
              }
              return Scaffold(
                body: CounselorSpotlightTourOverlay(
                  currentStep: 0,
                  targetCenter: const Offset(100, 600),
                  onNext: () {},
                  onSkip: () {
                    setState(() => isClosed = true);
                  },
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byType(CounselorSpotlightTourOverlay), findsOneWidget);

      // Tap Lewati
      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();

      expect(find.byType(CounselorSpotlightTourOverlay), findsNothing);
      expect(find.text('Tour Skipped'), findsOneWidget);
    });
  });
}

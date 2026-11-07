import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eva_counselor_mobile/features/dashboard/presentation/providers/counselor_nav_provider.dart';
import 'package:eva_counselor_mobile/features/dashboard/presentation/widgets/counselor_tour_guide_modal.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Counselor Tour Guide & Navigation Tests', () {
    test('hasSeenTour returns false initially and true after markTourSeen', () async {
      expect(await CounselorTourGuideModal.hasSeenTour(), isFalse);
      await CounselorTourGuideModal.markTourSeen();
      expect(await CounselorTourGuideModal.hasSeenTour(), isTrue);
    });

    testWidgets('CounselorTourGuideModal steps through menus and updates nav index', (tester) async {
      int activeIndex = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                activeIndex = ref.watch(counselorBottomNavIndexProvider);
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => CounselorTourGuideModal.show(context, ref),
                      child: const Text('Buka Tur'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      // Buka modal
      await tester.tap(find.text('Buka Tur'));
      await tester.pumpAndSettle();

      // Step 1: Beranda Praktik
      expect(find.text('Beranda Praktik'), findsOneWidget);
      expect(find.text('Mode Kesiapan Online Langsung'), findsOneWidget);
      expect(activeIndex, 0);

      // Klik Lanjut ke step 2
      final lanjutBtn = find.textContaining('Lanjut ke');
      expect(lanjutBtn, findsOneWidget);
      await tester.tap(lanjutBtn);
      await tester.pumpAndSettle();

      // Step 2: Rekam Medis
      expect(find.text('Rekam Medis Pasien'), findsOneWidget);
      expect(find.text('Consent Gating (Izin Pasien)'), findsOneWidget);
      expect(activeIndex, 1);

      // Klik Lanjut ke step 3
      await tester.tap(find.textContaining('Lanjut ke'));
      await tester.pumpAndSettle();

      // Step 3: Keuangan
      expect(find.text('Keuangan & Saldo Koin'), findsOneWidget);
      expect(activeIndex, 2);

      // Klik Sebelumnya -> balik ke step 2
      await tester.tap(find.text('Sebelumnya'));
      await tester.pumpAndSettle();
      expect(find.text('Rekam Medis Pasien'), findsOneWidget);
      expect(activeIndex, 1);

      // Klik Lewati -> modal tertutup & prefs diset true
      await tester.tap(find.text('Lewati'));
      await tester.pumpAndSettle();

      expect(find.byType(CounselorTourGuideModal), findsNothing);
      expect(await CounselorTourGuideModal.hasSeenTour(), isTrue);
    });
  });
}

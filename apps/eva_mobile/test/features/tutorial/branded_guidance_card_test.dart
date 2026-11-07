import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eva_mobile/features/tutorial/presentation/widgets/branded_guidance_card.dart';

void main() {
  group('BrandedGuidanceCard', () {
    testWidgets('renders branded card with typography, badge, title, and description',
        (tester) async {
      bool skipped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BrandedGuidanceCard(
                title: 'Cerita ke Eva, yuk!',
                description:
                    'Tekan tombol tengah untuk mulai berbicara. Kamu bisa mulai saat sudah siap.',
                actionHint: 'Ketuk tombol di bawah untuk mencoba',
                badgeText: 'EVA AI',
                onSkip: () => skipped = true,
              ),
            ),
          ),
        ),
      );

      // Verify title & description
      expect(find.text('Cerita ke Eva, yuk!'), findsOneWidget);
      expect(
        find.text(
            'Tekan tombol tengah untuk mulai berbicara. Kamu bisa mulai saat sudah siap.'),
        findsOneWidget,
      );
      expect(find.text('EVA AI'), findsOneWidget);
      expect(find.text('Ketuk tombol di bawah untuk mencoba'), findsOneWidget);
      expect(find.text('Lewati'), findsOneWidget);

      // Tap "Lewati"
      await tester.tap(find.text('Lewati'));
      expect(skipped, isTrue);
    });

    testWidgets('renders Lanjut button when isInteractiveTarget is false',
        (tester) async {
      bool nextClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BrandedGuidanceCard(
                title: 'Jurnal Refleksi Otomatis',
                description:
                    'Setiap selesai bercerita, intisari renunganmu tersimpan di sini.',
                isInteractiveTarget: false,
                onSkip: () {},
                onNext: () => nextClicked = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Lanjut'), findsOneWidget);
      await tester.tap(find.text('Lanjut'));
      expect(nextClicked, isTrue);
    });
  });
}

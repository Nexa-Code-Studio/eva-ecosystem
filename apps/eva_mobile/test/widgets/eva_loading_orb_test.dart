import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eva_mobile/widgets/eva_loading_orb.dart';

void main() {
  testWidgets('EvaLoadingOrb renders with halo and custom status message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EvaLoadingOrb(
            size: 200,
            message: 'Memuat ruang tenangmu...',
            showHalo: true,
          ),
        ),
      ),
    );

    expect(find.byType(EvaLoadingOrb), findsOneWidget);
    expect(find.text('Memuat ruang tenangmu...'), findsOneWidget);

    // Pump animated frames
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(EvaLoadingOrb), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eva_mobile/features/care/presentation/screens/care_screen.dart';
import 'package:eva_mobile/features/care/presentation/widgets/community_banner_card.dart';
import 'package:eva_mobile/features/care/presentation/widgets/community_paywall_sheet.dart';
import 'package:eva_mobile/features/care/presentation/widgets/psychologist_card.dart';
import 'package:eva_mobile/features/care/presentation/widgets/clinic_card.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'user_name': 'Alexander Agung',
      'user_email': 'alex@example.com',
    });
  });

  Widget createWidgetUnderTest() {
    return const ProviderScope(
      child: MaterialApp(
        home: CareScreen(),
      ),
    );
  }

  testWidgets('CareScreen renders header, banner, and filter chips', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Title & Subtitle
    expect(find.text('Layanan & Komunitas'), findsOneWidget);
    expect(find.text('Bantuan klinis profesional & safe space'), findsOneWidget);

    // Verify Community Banner Card
    expect(find.byType(CommunityBannerCard), findsOneWidget);
    expect(find.text('KOMUNITAS SAFE SPACE'), findsOneWidget);
    expect(find.text('Gabung Sekarang'), findsOneWidget);

    // Verify Filter Chips
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Psikolog'), findsOneWidget);
    expect(find.text('Psikiater'), findsOneWidget);
    expect(find.text('Klinik Mitra'), findsOneWidget);

    // Verify Psychologist Card rendered from mock data
    expect(find.byType(PsychologistCard), findsWidgets);
    expect(find.text('Amanda Zahra, M.Psi., Psikolog'), findsOneWidget);
    expect(find.text('SIPP Terdaftar'), findsWidgets);
  });

  testWidgets('Tapping Gabung Sekarang opens CommunityPaywallSheet', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Tap on Gabung Sekarang button
    final joinBtn = find.text('Gabung Sekarang');
    expect(joinBtn, findsOneWidget);
    await tester.tap(joinBtn);
    await tester.pumpAndSettle();

    // Verify Paywall Sheet is displayed
    expect(find.byType(CommunityPaywallSheet), findsOneWidget);
    expect(find.text('Eva Safe Space Community'), findsOneWidget);
    expect(find.text('Akses Sekali Bayar Seumur Hidup'), findsOneWidget);
    expect(find.text('Bonus 1 Bulan VIP Event Trial'), findsOneWidget);
  });

  testWidgets('Switching filter to Klinik Mitra renders ClinicCards', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Tap on Klinik Mitra chip
    final clinicChip = find.text('Klinik Mitra');
    expect(clinicChip, findsOneWidget);
    await tester.tap(clinicChip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify ClinicCards are displayed instead of PsychologistCards
    expect(find.byType(ClinicCard), findsWidgets);
    expect(find.text('Klinik Utama Sahabat Jiwa'), findsOneWidget);
    expect(find.byType(PsychologistCard), findsNothing);
  });
}

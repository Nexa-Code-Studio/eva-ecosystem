import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eva_mobile/config/app_config.dart';
import 'package:eva_mobile/features/care/domain/entities/psychologist_entity.dart';
import 'package:eva_mobile/features/care/presentation/widgets/booking_consultation_sheet.dart';
import '../../test_helpers/mock_image_http.dart';

void main() {
  setUpAll(() {
    HttpOverrides.global = TestHttpOverrides();
  });

  const testPsychologist = PsychologistEntity(
    id: 'psy_test_1',
    name: 'Amanda Zahra, M.Psi.',
    title: 'Psikolog Klinis Dewasa',
    registrationNumber: 'SIPP: 1234',
    avatarUrl: 'https://example.com/avatar.jpg',
    rating: 4.9,
    reviewCount: 120,
    experienceYears: 6,
    specialties: ['Kecemasan', 'Burnout'],
    bio: 'Test bio description',
    coinsPerSession: 0, // Free for straightforward test
  );

  setUp(() {
    AppConfig.useMockData = true;
    SharedPreferences.setMockInitialValues({
      'user_name': 'Test User',
      'user_coin_balance': 100,
    });
  });

  Widget createWidgetUnderTest({PsychologistEntity psychologist = testPsychologist}) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => BookingConsultationSheet.show(context, psychologist),
              child: const Text('Open Booking Sheet'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('BookingConsultationSheet renders AI chat history consent checkbox and toggles state', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Tap to open sheet
    await tester.tap(find.text('Open Booking Sheet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Verify Psychologist details and new sections
    expect(find.text('Amanda Zahra, M.Psi.'), findsOneWidget);
    expect(find.text('Pilih Moda Konsultasi'), findsOneWidget);
    expect(find.text('Pilih Hari'), findsOneWidget);
    expect(find.text('Durasi Pemesanan Sesi'), findsOneWidget);
    expect(find.text('Ketersediaan & Jam Mulai'), findsOneWidget);

    // Verify Consent Checkbox and text exist
    final consentCheckboxFinder = find.byKey(const Key('consent_share_chat_history_checkbox'));
    expect(consentCheckboxFinder, findsOneWidget);
    expect(find.text('Bagikan Riwayat Chat AI ke Psikolog'), findsOneWidget);
    expect(
      find.text('Saya bersedia mengirimkan riwayat percakapan dengan AI sebagai bahan analisis untuk psikolog.'),
      findsOneWidget,
    );

    // Initial state: checked by default
    Checkbox checkbox = tester.widget<Checkbox>(consentCheckboxFinder);
    expect(checkbox.value, isTrue);

    // Tap the checkbox to uncheck it
    await tester.tap(consentCheckboxFinder);
    await tester.pumpAndSettle();

    // Verify state updated to unchecked
    checkbox = tester.widget<Checkbox>(consentCheckboxFinder);
    expect(checkbox.value, isFalse);

    // Tap again to check
    await tester.tap(consentCheckboxFinder);
    await tester.pumpAndSettle();

    checkbox = tester.widget<Checkbox>(consentCheckboxFinder);
    expect(checkbox.value, isTrue);

    // Tap anywhere on the consent tile (by clicking the title text) to toggle to unchecked
    await tester.tap(find.text('Bagikan Riwayat Chat AI ke Psikolog'));
    await tester.pumpAndSettle();

    checkbox = tester.widget<Checkbox>(consentCheckboxFinder);
    expect(checkbox.value, isFalse);
  });

  testWidgets('Booking with consent checked displays confirmation badge in success dialog', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Tap to open sheet
    await tester.tap(find.text('Open Booking Sheet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Consent checkbox is checked by default
    final consentCheckboxFinder = find.byKey(const Key('consent_share_chat_history_checkbox'));
    expect(tester.widget<Checkbox>(consentCheckboxFinder).value, isTrue);

    // Confirm booking
    await tester.tap(find.text('Konfirmasi Janji Konsultasi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    // Verify Success Dialog and AI chat history indicator
    expect(find.text('Jadwal Berhasil Dibuat!'), findsOneWidget);
    expect(
      find.text('Riwayat percakapan AI dilampirkan untuk analisis psikolog'),
      findsOneWidget,
    );
  });

  testWidgets('Session duration stepper increases and decreases session count', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Tap to open sheet
    await tester.tap(find.text('Open Booking Sheet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Initial session is 1 session (30 minutes)
    expect(find.text('1 Sesi (30 Menit)'), findsOneWidget);

    // Tap [+] to add session
    final addFinder = find.byIcon(Icons.add);
    expect(addFinder, findsOneWidget);
    await tester.tap(addFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Verified updated to 2 sessions (60 minutes)
    expect(find.text('2 Sesi (60 Menit)'), findsOneWidget);

    // Tap [-] to decrease session
    final removeFinder = find.byIcon(Icons.remove);
    expect(removeFinder, findsOneWidget);
    await tester.tap(removeFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Verified decreased back to 1 session (30 minutes)
    expect(find.text('1 Sesi (30 Menit)'), findsOneWidget);
  });
}

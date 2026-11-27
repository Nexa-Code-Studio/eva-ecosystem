import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eva_mobile/config/app_config.dart';
import 'package:eva_mobile/features/care/domain/entities/psychologist_entity.dart';
import 'package:eva_mobile/features/care/presentation/screens/booking_consultation_screen.dart';
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
    coinsPerSession: 0,
  );

  // Deterministic morning time (08:30 on a Tuesday) so mock 08:00-17:00 slots are open.
  DateTime morningClock() => DateTime(2026, 11, 24, 8, 30);

  setUp(() {
    AppConfig.useMockData = true;
    SharedPreferences.setMockInitialValues({
      'user_name': 'Test User',
      'user_coin_balance': 100,
    });
  });

  Widget createWidgetUnderTest({
    PsychologistEntity psychologist = testPsychologist,
    DateTime Function()? nowProvider,
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookingConsultationScreen(
                    psychologist: psychologist,
                    nowProvider: nowProvider ?? morningClock,
                  ),
                ),
              ),
              child: const Text('Open Booking Page'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
      'BookingConsultationScreen opens as a full page without removed teleconsultation banner and with concise clinical summary consent',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Booking Page'));
    await tester.pumpAndSettle();

    expect(find.byType(BookingConsultationScreen), findsOneWidget);
    expect(find.text('Jadwalkan Konsultasi'), findsOneWidget);
    expect(find.text('Amanda Zahra, M.Psi.'), findsOneWidget);

    // Requirement 1: Removed teleconsultation banner
    expect(
      find.text('Telekonsultasi Video Call Online • Durasi 30 Menit / Sesi'),
      findsNothing,
    );
    expect(find.text('Tatap Muka'), findsNothing);

    // Date picker & duration stepper
    expect(find.text('Pilih Tanggal'), findsOneWidget);
    expect(find.byKey(const Key('booking_date_picker_field')), findsOneWidget);
    expect(find.text('Durasi Pemesanan Sesi'), findsOneWidget);

    // Requirement 2: Start time input field & picker button
    expect(find.byKey(const Key('booking_start_time_input')), findsOneWidget);
    expect(find.byKey(const Key('booking_pick_time_button')), findsOneWidget);

    // Requirement 3: Simplified legends (Tersedia & Tidak Tersedia only)
    expect(find.text('Tersedia'), findsOneWidget);
    expect(find.text('Tidak Tersedia'), findsOneWidget);
    expect(find.text('Istirahat'), findsNothing);
    expect(find.text('Terisi'), findsNothing);
    expect(find.text('Jeda Sesi'), findsNothing);

    // Requirement 4: Concise clinical summary consent
    final consentCheckboxFinder =
        find.byKey(const Key('consent_share_chat_history_checkbox'));
    expect(consentCheckboxFinder, findsOneWidget);
    expect(find.text('Bagikan ringkasan klinis'), findsOneWidget);
    expect(
      find.text(
        'Opsional. Hanya kirim keluhan dan diagnosis terkonfirmasi, tanpa jurnal atau transkrip suara.',
      ),
      findsOneWidget,
    );

    Checkbox checkbox = tester.widget<Checkbox>(consentCheckboxFinder);
    expect(checkbox.value, isFalse);

    await tester.ensureVisible(consentCheckboxFinder);
    await tester.tap(consentCheckboxFinder);
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(consentCheckboxFinder).value, isTrue);

    await tester.tap(find.text('Bagikan ringkasan klinis'));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(consentCheckboxFinder).value, isFalse);
  });

  testWidgets('Start time input updates selected slot without dragging timeline',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Booking Page'));
    await tester.pumpAndSettle();

    final timeInputFinder = find.byKey(const Key('booking_start_time_input'));
    await tester.enterText(timeInputFinder, '13:30');
    await tester.pumpAndSettle();

    expect(find.text('Pilihan: 13:30 - 14:00 (30 Menit)'), findsOneWidget);

    // Invalid format disables confirm and displays validation hint
    await tester.enterText(timeInputFinder, '99:99');
    await tester.pumpAndSettle();
    expect(find.text('Gunakan format JJ:MM, contoh 14:30'), findsOneWidget);
    expect(find.text('Format Jam Tidak Valid'), findsOneWidget);
  });

  testWidgets('Booking with consent checked displays confirmation badge and pops page',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Booking Page'));
    await tester.pumpAndSettle();

    final consentCheckboxFinder =
        find.byKey(const Key('consent_share_chat_history_checkbox'));
    await tester.ensureVisible(consentCheckboxFinder);
    await tester.tap(consentCheckboxFinder);
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(consentCheckboxFinder).value, isTrue);

    await tester.tap(find.byKey(const Key('booking_confirm_button')));
    await tester.pumpAndSettle();

    expect(find.text('Jadwal Berhasil Dibuat!'), findsOneWidget);
    expect(
      find.text('Riwayat percakapan AI dilampirkan untuk analisis psikolog'),
      findsOneWidget,
    );

    await tester.tap(find.text('Selesai'));
    await tester.pumpAndSettle();

    // Returns to previous screen after closing success dialog
    expect(find.byType(BookingConsultationScreen), findsNothing);
    expect(find.text('Open Booking Page'), findsOneWidget);
  });

  testWidgets('Enforces minimum 2 minutes lead time so current and +1 minute are rejected',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      createWidgetUnderTest(
        nowProvider: () => DateTime(2026, 11, 24, 14, 0),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Booking Page'));
    await tester.pumpAndSettle();

    final timeInputFinder = find.byKey(const Key('booking_start_time_input'));

    // Same minute (14:00) is rejected
    await tester.enterText(timeInputFinder, '14:00');
    await tester.pumpAndSettle();
    expect(find.text('Jam mulai minimal 2 menit dari waktu saat ini.'), findsOneWidget);
    expect(find.text('Pilih Jam yang Tersedia'), findsOneWidget);

    // +1 minute (14:01) is rejected
    await tester.enterText(timeInputFinder, '14:01');
    await tester.pumpAndSettle();
    expect(find.text('Jam mulai minimal 2 menit dari waktu saat ini.'), findsOneWidget);
    expect(find.text('Pilih Jam yang Tersedia'), findsOneWidget);

    // +2 minutes (14:02) is allowed
    await tester.enterText(timeInputFinder, '14:02');
    await tester.pumpAndSettle();
    expect(find.text('Jam mulai minimal 2 menit dari waktu saat ini.'), findsNothing);
    expect(find.text('Konfirmasi Janji Konsultasi'), findsOneWidget);
  });

  testWidgets('After operating hours today, confirm button is disabled with clear reason',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      createWidgetUnderTest(
        nowProvider: () => DateTime(2026, 11, 24, 19, 30),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Booking Page'));
    await tester.pumpAndSettle();

    expect(
      find.text('Jam praktik hari ini sudah selesai. Pilih tanggal lain.'),
      findsOneWidget,
    );
    expect(find.text('Pilih Jam yang Tersedia'), findsOneWidget);
  });

  testWidgets('Session duration stepper increases and decreases session count',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Booking Page'));
    await tester.pumpAndSettle();

    expect(find.text('1 Sesi (30 Menit)'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('2 Sesi (60 Menit)'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    expect(find.text('1 Sesi (30 Menit)'), findsOneWidget);
  });
}

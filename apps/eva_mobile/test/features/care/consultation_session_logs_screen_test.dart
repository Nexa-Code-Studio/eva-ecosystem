import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eva_mobile/config/app_config.dart';
import 'package:eva_mobile/core/routes/app_router.dart';
import 'package:eva_mobile/features/care/domain/entities/consultation_session_entity.dart';
import 'package:eva_mobile/features/care/domain/entities/psychologist_entity.dart';
import 'package:eva_mobile/features/care/presentation/screens/consultation_history_screen.dart';
import 'package:eva_mobile/features/care/presentation/screens/consultation_session_logs_screen.dart';

void main() {
  setUp(() {
    AppConfig.useMockData = true;
    SharedPreferences.setMockInitialValues({
      'user_name': 'Alexander Agung',
      'user_email': 'alex@example.com',
      'user_coin_balance': 120,
    });
  });

  final testPsychologist = PsychologistEntity(
    id: 'psy_test_1',
    name: 'Dr. Sarah Amalia, M.Psi., Psikolog',
    title: 'Psikolog Klinis Dewasa',
    registrationNumber: 'STR-1994829102-PK',
    avatarUrl: 'https://images.unsplash.com/photo-1594824813637-279c13b2e5a7?auto=format&fit=crop&q=80&w=300',
    rating: 4.9,
    reviewCount: 142,
    experienceYears: 8,
    specialties: const ['Depresi', 'Kecemasan', 'Manajemen Stres'],
    coinsPerSession: 40,
    durationMinutes: 50,
    availableOnline: true,
    bio: 'Berpengalaman menangani berbagai isu kesehatan mental klinis.',
    practitionerType: PractitionerType.professional,
    hasPsychologistCertificate: true,
    isVolunteerRole: false,
  );

  final testSessions = [
    ConsultationSessionEntity(
      id: 'session_test_1',
      psychologist: testPsychologist,
      sessionDateTime: DateTime(2026, 5, 10, 14, 0),
      status: ConsultationStatus.completed,
      type: ConsultationType.onlineVideo,
      sessionNumber: 1,
      durationMinutes: 50,
      notes: 'Sering merasa cemas berlebihan dan insomnia menjelang deadline.',
      diagnosisSummary: 'Kecemasan situasional tingkat sedang terpicu oleh beban kerja tinggi.',
      adviceList: const [
        'Lakukan teknik pernapasan 4-7-8 setiap kali mulai merasa overwhelmed.',
        'Batasi penggunaan layar minimal 45 menit sebelum tidur malam.',
      ],
      actionItems: const [
        'Catat pemicu cemas harian di fitur Buku Harian AI.',
        'Lakukan jalan santai 15 menit setiap pagi.',
      ],
      moodBefore: 'Cemas & Gelisah',
      moodAfter: 'Lebih Tenang & Lega',
    ),
  ];

  testWidgets('ConsultationSessionLogsScreen renders title, psychologist card, advice, and bottom CTA', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: ConsultationSessionLogsScreen(
            psychologist: testPsychologist,
            sessions: testSessions,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title & Header
    expect(find.text('Log & Saran Sesi'), findsOneWidget);
    expect(find.text('Catatan klinis & rekomendasi per sesi'), findsOneWidget);

    // Verify Psychologist Overview & chevron icon (no standalone 'Profil' button)
    expect(find.text('Dr. Sarah Amalia, M.Psi., Psikolog'), findsOneWidget);
    expect(find.text('Psikolog Klinis Dewasa'), findsOneWidget);
    expect(find.text('Profil'), findsNothing);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

    // Verify Date Filter
    expect(find.text('Semua Tanggal (1)'), findsOneWidget);
    expect(find.text('10 Mei 2026'), findsOneWidget);

    // Verify Rating Prompt Card is present
    expect(find.text('Beri Penilaian Sesi'), findsOneWidget);
    expect(find.text('Beri Rating'), findsOneWidget);

    // Verify Session Details
    expect(find.text('Sesi #1'), findsOneWidget);
    expect(find.text('50 Menit'), findsOneWidget);
    expect(find.text('"Sering merasa cemas berlebihan dan insomnia menjelang deadline."'), findsOneWidget);
    expect(find.text('Kecemasan situasional tingkat sedang terpicu oleh beban kerja tinggi.'), findsOneWidget);
    expect(find.text('Lakukan teknik pernapasan 4-7-8 setiap kali mulai merasa overwhelmed.'), findsOneWidget);
    expect(find.text('Catat pemicu cemas harian di fitur Buku Harian AI.'), findsOneWidget);

    // Verify Bottom Action Button
    expect(find.text('Jadwalkan Sesi Baru Bersama Dr. Sarah Amalia'), findsOneWidget);
  });

  testWidgets('ConsultationHistoryScreen navigates to ConsultationSessionLogsScreen when pressing Lihat Log & Saran Sesi', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: ConsultationHistoryScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Screen Title
    expect(find.text('Riwayat Bicara & Konseling'), findsOneWidget);

    // Find and tap "Lihat Log & Saran Sesi"
    final buttonFinder = find.text('Lihat Log & Saran Sesi');
    expect(buttonFinder, findsWidgets);

    await tester.tap(buttonFinder.first);
    await tester.pumpAndSettle();

    // Verify that we arrived on the new dedicated ConsultationSessionLogsScreen
    expect(find.text('Log & Saran Sesi'), findsOneWidget);
    expect(find.text('Catatan klinis & rekomendasi per sesi'), findsOneWidget);
  });

  testWidgets('ConsultationHistoryScreen search bar filters psychologists and shows empty state on unmatched query', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: ConsultationHistoryScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify search bar is rendered
    final searchFinder = find.byType(TextField);
    expect(searchFinder, findsOneWidget);
    expect(find.text('Cari nama psikolog atau relawan...'), findsOneWidget);

    // Search for a non-existent name
    await tester.enterText(searchFinder, 'NamaTidakAdaXYZ');
    await tester.pump();

    // Verify search empty state
    expect(find.text('Tidak Ditemukan'), findsOneWidget);
    expect(find.text('Reset Pencarian'), findsOneWidget);

    // Tap reset
    await tester.tap(find.text('Reset Pencarian'));
    await tester.pump();

    // Verify items are restored
    expect(find.text('Tidak Ditemukan'), findsNothing);
  });

  testWidgets('ConsultationSessionLogsScreen rating flow: open rating page, submit, and display preview card', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: ConsultationSessionLogsScreen(
            psychologist: testPsychologist,
            sessions: testSessions,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify rating prompt is visible
    expect(find.text('Beri Rating'), findsOneWidget);

    // Tap "Beri Rating"
    await tester.tap(find.text('Beri Rating'));
    await tester.pumpAndSettle();

    // Verify on ConsultationRatingScreen with Star, Ulasan Singkat, & Deskripsi (no Baik/Tidak)
    expect(find.text('Beri Penilaian Sesi'), findsOneWidget);
    expect(find.text('1. Nilai Pengalaman Sesi (Star)'), findsOneWidget);
    expect(find.text('2. Ulasan Singkat'), findsOneWidget);
    expect(find.text('3. Deskripsi Ulasan'), findsOneWidget);
    expect(find.text('2. Kesan Sesi (Baik / Tidak)'), findsNothing);
    expect(find.text('Kirim Penilaian & Ulasan'), findsOneWidget);

    // Enter short review form input (within character limit)
    await tester.enterText(find.byType(TextField).first, 'Sangat Sabar & Empati');
    await tester.pumpAndSettle();

    // Submit rating
    await tester.tap(find.text('Kirim Penilaian & Ulasan'));
    await tester.pumpAndSettle();

    // Verify back on ConsultationSessionLogsScreen and preview card is visible (without Baik/Tidak badge)
    expect(find.text('Ulasan Anda'), findsOneWidget);
    expect(find.text('Baik'), findsNothing);
    expect(find.text('Sangat Sabar & Empati'), findsOneWidget);
    expect(find.text('Ubah'), findsOneWidget);
    expect(find.text('Beri Rating'), findsNothing);
  });
}

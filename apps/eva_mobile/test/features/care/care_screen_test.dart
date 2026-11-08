import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eva_mobile/config/app_config.dart';
import 'package:eva_mobile/core/routes/app_router.dart';
import 'package:eva_mobile/features/care/presentation/screens/care_screen.dart';
import 'package:eva_mobile/features/care/presentation/screens/consultation_schedule_screen.dart';
import 'package:eva_mobile/features/care/presentation/screens/consultation_history_screen.dart';
import 'package:eva_mobile/features/care/presentation/screens/psychologist_video_call_screen.dart';
import 'package:eva_mobile/features/care/presentation/screens/psychologist_detail_screen.dart';
import 'package:eva_mobile/features/care/presentation/widgets/care_quick_actions.dart';
import 'package:eva_mobile/features/care/presentation/widgets/community_banner_card.dart';
import 'package:eva_mobile/features/care/presentation/widgets/psychologist_card.dart';
import 'package:eva_mobile/features/care/presentation/widgets/psychologist_certificate_carousel.dart';
import 'package:eva_mobile/features/care/presentation/widgets/clinic_location_map_card.dart';
import 'package:eva_mobile/features/care/presentation/widgets/consultation_result_bottom_sheet.dart';
import 'package:eva_mobile/features/care/presentation/widgets/psychologist_role_badge.dart';

void main() {
  setUp(() {
    AppConfig.useMockData = true;
    SharedPreferences.setMockInitialValues({
      'user_name': 'Alexander Agung',
      'user_email': 'alex@example.com',
      'user_coin_balance': 120,
    });
  });

  Widget createWidgetUnderTest() {
    return const ProviderScope(
      child: MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: CareScreen(),
      ),
    );
  }

  testWidgets('CareScreen renders header, 4 quick action buttons, and filters', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify Title & Subtitle
    expect(find.text('Layanan Konseling'), findsOneWidget);
    expect(find.text('Konseling psikolog berlisensi & relawan sebaya'), findsOneWidget);

    // Verify Community Banner is REMOVED
    expect(find.byType(CommunityBannerCard), findsNothing);
    expect(find.text('KOMUNITAS SAFE SPACE'), findsNothing);

    // Verify 4 Quick Action Buttons
    expect(find.byType(CareQuickActions), findsOneWidget);
    expect(find.text('Jadwal'), findsOneWidget);
    expect(find.text('Riwayat'), findsOneWidget);
    expect(find.text('Koin Saya'), findsOneWidget);
    expect(find.text('Panduan'), findsOneWidget);

    // Verify Filter Chips: Semua, Psikolog, Relawan
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Psikolog'), findsOneWidget);
    expect(find.text('Relawan'), findsWidgets);
    expect(find.text('Psikolog Profesional'), findsNothing);
    expect(find.text('Psikolog Freelance'), findsNothing);
    expect(find.text('Volunteer'), findsNothing);

    // Verify Psychologist Cards rendered from mock data
    expect(find.byType(PsychologistCard), findsWidgets);
    expect(find.text('Amanda Zahra, M.Psi., Psikolog'), findsOneWidget);

    // Verify Tag chips rendered on cards (without volunteer explanation container)
    expect(find.text('Profesional'), findsWidgets);
    expect(find.text('Relawan'), findsWidgets);
  });

  testWidgets('Tapping Psikolog and Relawan filter chips filters counselors list accordingly', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Tap on Psikolog chip
    final psikologChip = find.widgetWithText(ChoiceChip, 'Psikolog');
    expect(psikologChip, findsOneWidget);
    await tester.tap(psikologChip);
    await tester.pumpAndSettle();

    // Verify psychologists are shown
    expect(find.text('Amanda Zahra, M.Psi., Psikolog'), findsOneWidget);
    expect(find.text('Dimas Wicaksono, M.Psi., Psikolog'), findsOneWidget);

    // Tap on Relawan chip
    final relawanChip = find.widgetWithText(ChoiceChip, 'Relawan');
    expect(relawanChip, findsOneWidget);
    await tester.tap(relawanChip);
    await tester.pumpAndSettle();

    // Verify volunteer counselors are shown
    expect(find.text('Bayu Aditya, S.Psi.'), findsOneWidget);
  });

  testWidgets('Tapping psychologist card navigates to PsychologistDetailScreen with patient stats, 4 tags, and 5 testimonials', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Tap on Amanda Zahra's card
    final card = find.text('Amanda Zahra, M.Psi., Psikolog');
    expect(card, findsOneWidget);
    await tester.tap(card);
    await tester.pumpAndSettle();

    // Verify PsychologistDetailScreen is displayed
    expect(find.byType(PsychologistDetailScreen), findsOneWidget);
    expect(find.text('Profil Konselor'), findsOneWidget);

    // 1. Verify Patient Statistics section
    expect(find.text('Statistik Pasien Dirawat'), findsOneWidget);
    expect(find.text('284+'), findsOneWidget);
    expect(find.text('Pasien Dirawat'), findsOneWidget);
    expect(find.text('98.6%'), findsOneWidget);
    expect(find.text('Tingkat Puas'), findsOneWidget);
    expect(find.text('3.8 Sesi'), findsOneWidget);
    expect(find.text('96% Ulasan Positif'), findsOneWidget);
    expect(find.text('4% Catatan / Masukan'), findsOneWidget);
    expect(find.text('94.5% pasien merasakan penurunan kecemasan & stres kerja signifikan'), findsOneWidget);

    // 2. Verify Ulasan & Kesan Pasien is REMOVED (covered by Testimoni and Statistik)
    expect(find.text('Ulasan & Kesan Pasien'), findsNothing);

    // 3. Verify Focus Issues & Payment Card in body are REMOVED
    expect(find.text('FOKUS ISU & SPESIALISASI'), findsNothing);
    expect(find.text('Biaya Sesi: 50 Koin EVA'), findsNothing);

    // 4. Verify 5 Patient Testimonials rendered with short review badges & descriptions
    expect(find.text('TESTIMONI PASIEN'), findsOneWidget);
    expect(find.text('5 ulasan pengalaman konseling pasien terverifikasi:'), findsOneWidget);
    expect(find.text('Pasien Terverifikasi (A. Z.)'), findsOneWidget);
    expect(find.text('Pasien Terverifikasi (R. K.)'), findsOneWidget);
    expect(find.text('Pasien Terverifikasi (M. F.)'), findsOneWidget);
    expect(find.text('Pasien Terverifikasi (N. D.)'), findsOneWidget);
    expect(find.text('Pasien Terverifikasi (H. P.)'), findsOneWidget);

    // 5. Verify Clean Certificate Carousel in Detail Screen (Photo & Label)
    expect(find.byType(PsychologistCertificateCarousel), findsOneWidget);
    expect(find.text('Sertifikat & Lisensi'), findsOneWidget);
    expect(find.text('1 / 4'), findsOneWidget);
    expect(find.text('SIPP: 1988-12-04-2021 (HIMPSI)'), findsOneWidget);
    expect(find.text('Perbesar'), findsWidgets);

    // 6. Verify Bottom Bar consultation fee & action button
    expect(find.text('Biaya Konsultasi'), findsOneWidget);
    expect(find.text('50 Koin'), findsOneWidget);
    expect(find.text('Jadwalkan Konsultasi'), findsOneWidget);

    // 7. Verify "Lihat Semua" opens modal bottom sheet with filter tabs
    final lihatSemuaBtn = find.text('Lihat Semua');
    expect(lihatSemuaBtn, findsOneWidget);
    await tester.tap(lihatSemuaBtn);
    await tester.pumpAndSettle();

    expect(find.text('Semua Testimoni Pasien'), findsOneWidget);
    expect(find.text('Semua (5)'), findsOneWidget);
    expect(find.text('Positif (4)'), findsOneWidget);
    expect(find.text('Catatan (1)'), findsOneWidget);
  });

  testWidgets('Tapping Jadwal navigates to ConsultationScheduleScreen and launches PsychologistVideoCallScreen', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final jadwalBtn = find.text('Jadwal');
    expect(jadwalBtn, findsOneWidget);
    await tester.tap(jadwalBtn);
    await tester.pumpAndSettle();

    // Verify ConsultationScheduleScreen is displayed
    expect(find.byType(ConsultationScheduleScreen), findsOneWidget);
    expect(find.text('Jadwal Sesi Mendatang'), findsOneWidget);
    expect(find.text('Waktunya Sesi Konsultasi!'), findsOneWidget);

    // 1. Verify that upcoming session outside session time is locked with "Belum Waktunya"
    final lockedBtn = find.text('Belum Waktunya').first;
    expect(lockedBtn, findsOneWidget);
    await tester.tap(lockedBtn);
    await tester.pumpAndSettle();

    // Verify "Belum Waktunya Sesi" dialog appears preventing entry
    expect(find.text('Belum Waktunya Sesi'), findsOneWidget);
    expect(find.text('Mengerti'), findsOneWidget);
    await tester.tap(find.text('Mengerti'));
    await tester.pumpAndSettle();

    // 2. Verify offline clinic session shows Maps card & Buka di Maps button
    expect(find.byType(ClinicLocationMapCard), findsWidgets);
    expect(find.text('Lokasi Konsultasi'), findsWidgets);
    expect(find.text('Buka di Maps'), findsOneWidget);

    // 3. Verify Masuk Video Call button is present for active session and tap it
    final videoCallBtn = find.text('Masuk Video Call Sekarang');
    expect(videoCallBtn, findsOneWidget);
    await tester.tap(videoCallBtn);
    await tester.pumpAndSettle();

    // Verify PsychologistVideoCallScreen is launched
    expect(find.byType(PsychologistVideoCallScreen), findsOneWidget);
    expect(find.byIcon(Icons.call_end_rounded), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(find.byIcon(Icons.videocam_rounded), findsOneWidget);

    // 4. End the video call
    final endCallBtn = find.byIcon(Icons.call_end_rounded);
    await tester.tap(endCallBtn);
    await tester.pumpAndSettle();

    // In confirmation dialog, tap "Ya, Selesaikan"
    final confirmEndBtn = find.text('Ya, Selesaikan');
    expect(confirmEndBtn, findsOneWidget);
    await tester.tap(confirmEndBtn);
    await tester.pumpAndSettle();

    // 5. Verify ConsultationResultBottomSheet appears directly (not redirected to history)
    expect(find.byType(ConsultationResultBottomSheet), findsOneWidget);
    expect(find.text('Hasil & Saran Sesi Konsultasi'), findsOneWidget);
    expect(find.text('RANGKUMAN HASIL KONSULTASI'), findsOneWidget);
    expect(find.text('SARAN & REKOMENDASI PSIKOLOG'), findsOneWidget);
    expect(find.text('LATIHAN MANDIRI (ACTION ITEMS)'), findsOneWidget);

    // Tap "Selesai & Tutup Saran Sesi" to close
    final closeSheetBtn = find.text('Selesai & Tutup Saran Sesi');
    expect(closeSheetBtn, findsOneWidget);
    await tester.tap(closeSheetBtn);
    await tester.pumpAndSettle();
  });

  testWidgets('Tapping Riwayat navigates to ConsultationHistoryScreen and shows hired psychologists & logs', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final historyBtn = find.text('Riwayat');
    expect(historyBtn, findsOneWidget);
    await tester.tap(historyBtn);
    await tester.pumpAndSettle();

    // Verify ConsultationHistoryScreen is displayed
    expect(find.byType(ConsultationHistoryScreen), findsOneWidget);
    expect(find.text('Riwayat Bicara & Konseling'), findsOneWidget);
    expect(find.text('PSIKOLOG YANG PERNAH DISEWA'), findsOneWidget);

    // Verify hired psychologists listed
    expect(find.text('Amanda Zahra, M.Psi., Psikolog'), findsOneWidget);
    expect(find.text('Dimas Wicaksono, M.Psi., Psikolog'), findsOneWidget);
    expect(find.text('Rian Pratama, M.Psi., Psikolog'), findsOneWidget);

    // Tap on Lihat Log & Saran Sesi on Amanda Zahra's card
    final lihatLogBtn = find.text('Lihat Log & Saran Sesi').first;
    expect(lihatLogBtn, findsOneWidget);
    await tester.tap(lihatLogBtn);
    await tester.pumpAndSettle();

    // Verify modal sheet opens with per-session logs and clinical advice
    expect(find.text('Saran & Rekomendasi Psikolog:'), findsWidgets);
    expect(find.text('Praktikkan teknik relaksasi napas 4-7-8 setiap malam 15 menit sebelum waktu tidur.'), findsOneWidget);
    expect(find.text('LATIHAN MANDIRI (ACTION ITEMS)'), findsWidgets);
  });

  testWidgets('PsychologistCertificateCarousel displays certificates one by one and navigates via swipe and chevron buttons', (tester) async {
    final certs = [
      'SIPP: 1988-12-04-2021 (HIMPSI)',
      'Magister Profesi Psikologi Klinis Dewasa (S2)',
      'Sertifikasi CBT Terapan & Regulasi Emosi',
      'Sertifikat Psychological First Aid (PFA) Nasional',
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PsychologistCertificateCarousel(certifications: certs),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify first certificate is shown with photo & clean label (no AI slop)
    expect(find.text('1 / 4'), findsOneWidget);
    expect(find.text('SIPP: 1988-12-04-2021 (HIMPSI)'), findsOneWidget);
    expect(find.text('Perbesar'), findsOneWidget);

    // Tap next chevron button
    final nextBtn = find.byIcon(Icons.chevron_right_rounded);
    expect(nextBtn, findsOneWidget);
    await tester.tap(nextBtn);
    await tester.pumpAndSettle();

    // Verify second certificate is displayed
    expect(find.text('2 / 4'), findsOneWidget);
    expect(find.text('Magister Profesi Psikologi Klinis Dewasa (S2)'), findsOneWidget);

    // Tap previous chevron button
    final prevBtn = find.byIcon(Icons.chevron_left_rounded);
    expect(prevBtn, findsOneWidget);
    await tester.tap(prevBtn);
    await tester.pumpAndSettle();

    // Verify back to first certificate
    expect(find.text('1 / 4'), findsOneWidget);
    expect(find.text('SIPP: 1988-12-04-2021 (HIMPSI)'), findsOneWidget);

    // Swipe left on PageView to go to certificate 2
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(find.text('2 / 4'), findsOneWidget);
    expect(find.text('Magister Profesi Psikologi Klinis Dewasa (S2)'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/counselor_nav_provider.dart';

class TourPoint {
  final IconData icon;
  final String title;
  final String description;

  const TourPoint({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class TourStepModel {
  final int navIndex;
  final String stepLabel;
  final String tabName;
  final String title;
  final String summary;
  final IconData icon;
  final Color accentColor;
  final Color bgAccent;
  final List<TourPoint> points;

  const TourStepModel({
    required this.navIndex,
    required this.stepLabel,
    required this.tabName,
    required this.title,
    required this.summary,
    required this.icon,
    required this.accentColor,
    required this.bgAccent,
    required this.points,
  });
}

class CounselorTourGuideModal extends StatefulWidget {
  final WidgetRef ref;
  final bool isFirstTime;

  const CounselorTourGuideModal({
    super.key,
    required this.ref,
    this.isFirstTime = false,
  });

  static const String prefsKey = 'counselor_has_seen_menu_tour';

  static Future<bool> hasSeenTour() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(prefsKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> markTourSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefsKey, true);
    } catch (_) {}
  }

  static Future<void> show(BuildContext context, WidgetRef ref, {bool isFirstTime = false}) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (ctx) => CounselorTourGuideModal(
        ref: ref,
        isFirstTime: isFirstTime,
      ),
    );
  }

  @override
  State<CounselorTourGuideModal> createState() => _CounselorTourGuideModalState();
}

class _CounselorTourGuideModalState extends State<CounselorTourGuideModal> {
  int _currentStep = 0;

  final List<TourStepModel> _steps = const [
    TourStepModel(
      navIndex: 0,
      stepLabel: 'Langkah 1 dari 4',
      tabName: 'Beranda Praktik',
      title: 'Beranda & Manajemen Sesi Telekonseling',
      summary: 'Pusat kendali praktik untuk mengaktifkan ketersediaan, memantau antrean pasien, dan memulai sesi video tatap muka.',
      icon: Icons.home_rounded,
      accentColor: AppColors.primary,
      bgAccent: Color(0xFFEEF2FF),
      points: [
        TourPoint(
          icon: Icons.toggle_on_rounded,
          title: 'Mode Kesiapan Online Langsung',
          description: 'Aktifkan sakelar Siap Konsultasi saat Anda senggang. Pasien yang booking jadwal Anda langsung terkonfirmasi tanpa perlu menunggu acc manual.',
        ),
        TourPoint(
          icon: Icons.videocam_rounded,
          title: 'Jadwal & Ruang Video Call',
          description: 'Lihat hitung mundur sesi aktif dan masuki ruang telekonseling terenkripsi secara instan dengan satu ketukan tombol Buka Ruang VC.',
        ),
        TourPoint(
          icon: Icons.health_and_safety_rounded,
          title: 'Triase Emosional Pasien',
          description: 'Ketahui indikator keparahan pasien (Stabil, Butuh Evaluasi, atau Kritis) sebagai referensi persiapan awal sebelum konseling.',
        ),
      ],
    ),
    TourStepModel(
      navIndex: 1,
      stepLabel: 'Langkah 2 dari 4',
      tabName: 'Rekam Medis Pasien',
      title: 'Rekam Medis Terenkripsi & Catatan SOAP',
      summary: 'Dokumentasi klinis terstruktur yang terlindungi persetujuan pasien (Consent Gating) dan riwayat transkrip utuh.',
      icon: Icons.people_alt_rounded,
      accentColor: Color(0xFF0D9488),
      bgAccent: Color(0xFFCCFBF1),
      points: [
        TourPoint(
          icon: Icons.lock_person_rounded,
          title: 'Consent Gating (Izin Pasien)',
          description: 'Rekam medis dan catatan emosional hanya dapat diakses setelah pasien memberikan persetujuan eksplisit demi privasi medis tertinggi.',
        ),
        TourPoint(
          icon: Icons.assignment_turned_in_rounded,
          title: 'Formulir SOAP Medis Klinis',
          description: 'Dokumentasikan Subjective, Objective, Assessment, dan Plan secara komprehensif setelah sesi telekonseling berakhir.',
        ),
        TourPoint(
          icon: Icons.insights_rounded,
          title: 'Transkrip Sesi & Grafik DASS-21',
          description: 'Tinjau riwayat skor skrining depresi, kecemasan, dan stres pasien serta transkrip percakapan telekonseling kapan saja.',
        ),
      ],
    ),
    TourStepModel(
      navIndex: 2,
      stepLabel: 'Langkah 3 dari 4',
      tabName: 'Keuangan & Saldo Koin',
      title: 'Sistem Koin & Bagi Hasil Transparan',
      summary: 'Koin otomatis dikreditkan setelah sesi telekonseling dan dokumentasi selesai, siap dicairkan ke rekening bank Anda.',
      icon: Icons.account_balance_wallet_rounded,
      accentColor: Color(0xFFD97706),
      bgAccent: Color(0xFFFEF3C7),
      points: [
        TourPoint(
          icon: Icons.monetization_on_rounded,
          title: 'Koin Masuk Otomatis per Sesi',
          description: 'Saldo koin akun otomatis bertambah begitu durasi sesi terpenuhi dan verifikasi catatan SOAP klinis tersimpan.',
        ),
        TourPoint(
          icon: Icons.currency_exchange_rounded,
          title: 'Pencairan Rupiah (Psikolog Mandiri)',
          description: 'Tarik saldo koin ke rekening bank lokal dengan nilai tukar 1 Koin = Rp 1.000 dengan sistem bagi hasil adil (85% bersih konselor).',
        ),
        TourPoint(
          icon: Icons.corporate_fare_rounded,
          title: 'Dukungan Psikolog Mitra Institusi',
          description: 'Bagi psikolog dari RS/Klinik mitra, tarif koin dan jadwal sesi dikelola langsung oleh mitra melalui web portal terpusat.',
        ),
      ],
    ),
    TourStepModel(
      navIndex: 3,
      stepLabel: 'Langkah 4 dari 4',
      tabName: 'Profil, Keamanan & Sertifikat',
      title: 'Jadwal Praktik, Drive E2EE & Sertifikasi',
      summary: 'Pengaturan fleksibilitas praktik, pencadangan Google Drive terenkripsi, serta unduhan sertifikat penghargaan resmi.',
      icon: Icons.shield_rounded,
      accentColor: Color(0xFF7C3AED),
      bgAccent: Color(0xFFF3E8FF),
      points: [
        TourPoint(
          icon: Icons.cloud_sync_rounded,
          title: 'Backup Lokal ke Google Drive (E2EE)',
          description: 'Rekam medis tersimpan aman di perangkat lokal Anda dan dicadangkan ke Google Drive pribadi tanpa disimpan di server pusat.',
        ),
        TourPoint(
          icon: Icons.workspace_premium_rounded,
          title: 'Sertifikat Pencapaian Resmi (PDF)',
          description: 'Kumpulkan sertifikat penghargaan resmi berjenjang atas dedikasi dan jam terbang konseling Anda, siap diunduh dalam resolusi tinggi.',
        ),
        TourPoint(
          icon: Icons.upgrade_rounded,
          title: 'Peningkatan Lisensi Profesional',
          description: 'Relawan Teman Sebaya dapat mengajukan kenaikan status akun menjadi Psikolog Profesional setelah melengkapi SIPP dan STR.',
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Sinkronkan tab aktif shell dengan step awal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.ref.read(counselorBottomNavIndexProvider.notifier).state = _steps[_currentStep].navIndex;
    });
  }

  void _onNext() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
      widget.ref.read(counselorBottomNavIndexProvider.notifier).state = _steps[_currentStep].navIndex;
    } else {
      _finishTour();
    }
  }

  void _onPrevious() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      widget.ref.read(counselorBottomNavIndexProvider.notifier).state = _steps[_currentStep].navIndex;
    }
  }

  Future<void> _finishTour() async {
    await CounselorTourGuideModal.markTourSeen();
    if (mounted) {
      widget.ref.read(counselorBottomNavIndexProvider.notifier).state = 0;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final isLast = _currentStep == _steps.length - 1;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 32, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Header: Title, Step Counter, and Skip
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: step.bgAccent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: step.accentColor.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(step.icon, size: 14, color: step.accentColor),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    step.tabName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: step.accentColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          step.stepLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.textSecondary),
                    label: const Text(
                      'Lewati',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    onPressed: _finishTour,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Step Progress Indicator Bars
              Row(
                children: List.generate(_steps.length, (idx) {
                  final isActive = idx == _currentStep;
                  final isDone = idx < _currentStep;
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: EdgeInsets.only(right: idx < _steps.length - 1 ? 6 : 0),
                      height: 4,
                      decoration: BoxDecoration(
                        color: isActive
                            ? step.accentColor
                            : isDone
                                ? step.accentColor.withValues(alpha: 0.4)
                                : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),

              // Title & Subtitle Card
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: step.bgAccent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: step.accentColor.withValues(alpha: 0.2)),
                    ),
                    child: Icon(step.icon, color: step.accentColor, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          step.summary,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Feature Points
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.38,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: step.points.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, pIdx) {
                    final point = step.points[pIdx];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFEDF2F7)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              color: step.accentColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(point.icon, size: 14, color: step.accentColor),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  point.title,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  point.description,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),

              // Navigation Action Buttons
              Row(
                children: [
                  if (_currentStep > 0) ...[
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _onPrevious,
                      child: const Text(
                        'Sebelumnya',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: step.accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _onNext,
                      child: Text(
                        isLast ? 'Mulai Praktik Sekarang 🚀' : 'Lanjut ke ${_steps[_currentStep + 1].tabName} →',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

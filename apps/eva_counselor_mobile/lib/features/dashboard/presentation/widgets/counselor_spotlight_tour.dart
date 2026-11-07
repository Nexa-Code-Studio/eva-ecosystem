import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import 'counselor_spotlight_card.dart';

class SpotlightStepModel {
  final int index;
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;

  const SpotlightStepModel({
    required this.index,
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
  });
}

class CounselorSpotlightTourOverlay extends StatelessWidget {
  final int currentStep;
  final Rect targetRect;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const CounselorSpotlightTourOverlay({
    super.key,
    required this.currentStep,
    required this.targetRect,
    required this.onNext,
    required this.onSkip,
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

  static const List<SpotlightStepModel> steps = [
    SpotlightStepModel(
      index: 0,
      title: 'Beranda Praktik Konseling',
      description: 'Kelola status kesiapan online & pantau jadwal telekonseling aktif. Pasien booking langsung terkonfirmasi otomatis.',
      icon: Icons.home_rounded,
      accentColor: AppColors.primary,
    ),
    SpotlightStepModel(
      index: 1,
      title: 'Rekam Medis & SOAP',
      description: 'Akses rekam medis dengan persetujuan pasien (Consent Gating), grafik DASS-21, transkrip dialog, dan dokumen SOAP.',
      icon: Icons.people_alt_rounded,
      accentColor: Color(0xFF0D9488),
    ),
    SpotlightStepModel(
      index: 2,
      title: 'Keuangan & Saldo Koin',
      description: 'Koin otomatis bertambah setelah sesi dan verifikasi SOAP selesai. Tarik koin ke rekening bank (1 Koin = Rp 1.000).',
      icon: Icons.account_balance_wallet_rounded,
      accentColor: Color(0xFFD97706),
    ),
    SpotlightStepModel(
      index: 3,
      title: 'Profil, Drive E2EE & Sertifikat',
      description: 'Atur durasi sesi, cadangkan rekam medis terenkripsi ke Google Drive pribadi, dan unduh sertifikat resmi pencapaian.',
      icon: Icons.shield_rounded,
      accentColor: Color(0xFF7C3AED),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final step = steps[currentStep.clamp(0, steps.length - 1)];
    final isLast = step.index == steps.length - 1;
    final size = MediaQuery.of(context).size;
    final navLabels = ['Beranda', 'Pasien', 'Keuangan', 'Profil'];

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. LIGHTWEIGHT DARK SCRIM WITH CUT-OUT HOLE (ZERO BLUR, ZERO GPU STALL)
          CustomPaint(
            size: size,
            painter: _SpotlightHolePainter(targetRect: targetRect),
          ),

          // 2. TAP BACKGROUND TO ADVANCE
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: onNext,
            ),
          ),

          // 3. THE PROMINENT ROUNDED HIGHLIGHT BOX (CRISP, 100% SHARP)
          Positioned(
            left: targetRect.left,
            top: targetRect.top,
            width: targetRect.width,
            height: targetRect.height,
            child: Container(
              decoration: BoxDecoration(
                color: step.accentColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: step.accentColor.withValues(alpha: 0.7),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                  const BoxShadow(
                    color: Colors.black38,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(step.icon, color: Colors.white, size: 21),
                        const SizedBox(height: 2),
                        Text(
                          navLabels[step.index],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 4. FLOATING COACHMARK TOOLTIP CARD
          Positioned(
            bottom: (size.height - targetRect.top) + 14,
            left: 20,
            right: 20,
            child: CounselorSpotlightCard(
              step: step,
              totalSteps: steps.length,
              isLast: isLast,
              onNext: onNext,
              onSkip: onSkip,
            ),
          ),

          // 5. TRIANGLE POINTER
          Positioned(
            left: targetRect.center.dx - 9,
            bottom: (size.height - targetRect.top) + 6,
            child: CustomPaint(
              size: const Size(18, 9),
              painter: _TrianglePointerPainter(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpotlightHolePainter extends CustomPainter {
  final Rect targetRect;
  final double radius;
  final Color overlayColor;

  _SpotlightHolePainter({
    required this.targetRect,
    this.radius = 16.0,
    this.overlayColor = const Color(0xDD0A0F1D),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(targetRect, Radius.circular(radius)));
    final combinedPath = Path.combine(PathOperation.difference, backgroundPath, holePath);

    final paint = Paint()..color = overlayColor;
    canvas.drawPath(combinedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightHolePainter oldDelegate) {
    return oldDelegate.targetRect != targetRect || oldDelegate.overlayColor != overlayColor;
  }
}

class _TrianglePointerPainter extends CustomPainter {
  final Color color;

  _TrianglePointerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePointerPainter oldDelegate) => oldDelegate.color != color;
}

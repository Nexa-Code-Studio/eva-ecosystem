import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';

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
  final Offset targetCenter;
  final double targetRadius;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const CounselorSpotlightTourOverlay({
    super.key,
    required this.currentStep,
    required this.targetCenter,
    this.targetRadius = 34.0,
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

    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. BLURRED & DARKENED SCRIM WITH CIRCULAR CUTOUT HOLE
          ClipPath(
            clipper: _InvertedCircleClipper(
              center: targetCenter,
              radius: targetRadius,
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: Container(
                color: const Color(0xB8070B14),
              ),
            ),
          ),

          // 2. TAP LISTENER OVER DARK BACKGROUND TO ADVANCE
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: onNext,
            ),
          ),

          // 3. GLOWING ILLUMINATION RINGS AROUND THE MENU ITEM
          CustomPaint(
            size: size,
            painter: _SpotlightRingsPainter(
              targetCenter: targetCenter,
              radius: targetRadius,
              accentColor: step.accentColor,
            ),
          ),

          // 4. FLOATING COACHMARK TOOLTIP CARD ABOVE TARGET
          Positioned(
            bottom: (size.height - targetCenter.dy) + targetRadius + 14,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Step pill & Skip
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: step.accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(step.icon, size: 14, color: step.accentColor),
                                const SizedBox(width: 5),
                                Text(
                                  'Menu ${step.index + 1} dari ${steps.length}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: step.accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: onSkip,
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text(
                                    'Lewati',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  SizedBox(width: 3),
                                  Icon(Icons.close_rounded, size: 16, color: AppColors.textSecondary),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Title
                      Text(
                        step.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 5),

                      // Short Snappy Description
                      Text(
                        step.description,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF475569),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Footer: Step dots & Action Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: List.generate(steps.length, (dotIdx) {
                              final isActive = dotIdx == step.index;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.only(right: 6),
                                width: isActive ? 20 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isActive ? step.accentColor : const Color(0xFFCBD5E1),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            }),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: step.accentColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: onNext,
                            child: Text(
                              isLast ? 'Mulai Praktik 🚀' : 'Lanjut →',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Triangle pointer pointing to the circled menu
                Align(
                  alignment: Alignment(
                    ((targetCenter.dx - 20) / (size.width - 40)).clamp(0.05, 0.95) * 2 - 1,
                    0,
                  ),
                  child: CustomPaint(
                    size: const Size(18, 9),
                    painter: _TrianglePointerPainter(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InvertedCircleClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;

  _InvertedCircleClipper({required this.center, required this.radius});

  @override
  Path getClip(Size size) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(covariant _InvertedCircleClipper oldClipper) {
    return oldClipper.center != center || oldClipper.radius != radius;
  }
}

class _SpotlightRingsPainter extends CustomPainter {
  final Offset targetCenter;
  final double radius;
  final Color accentColor;

  _SpotlightRingsPainter({
    required this.targetCenter,
    required this.radius,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Inner crisp white ring
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.white;
    canvas.drawCircle(targetCenter, radius, innerPaint);

    // Middle glowing accent ring
    final middlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = accentColor.withValues(alpha: 0.9);
    canvas.drawCircle(targetCenter, radius + 2.5, middlePaint);

    // Outer soft halo
    final haloPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = accentColor.withValues(alpha: 0.35);
    canvas.drawCircle(targetCenter, radius + 6.0, haloPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightRingsPainter oldDelegate) {
    return oldDelegate.targetCenter != targetCenter ||
        oldDelegate.radius != radius ||
        oldDelegate.accentColor != accentColor;
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
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePointerPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

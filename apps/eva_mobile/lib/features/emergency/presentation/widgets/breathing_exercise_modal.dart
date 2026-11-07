import "dart:async";
import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../theme/app_colors.dart";

class BreathingExerciseModal extends StatefulWidget {
  const BreathingExerciseModal({super.key});

  @override
  State<BreathingExerciseModal> createState() => BreathingExerciseModalState();
}

class BreathingExerciseModalState extends State<BreathingExerciseModal> {
  Timer? _timer;
  int _seconds = 0;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _seconds++;
      });
    });
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _startTimer();
      } else {
        _timer?.cancel();
      }
    });
  }

  void _reset() {
    setState(() {
      _seconds = 0;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 4-7-8 Breathing Cycle (Total: 19 seconds per cycle)
    final cycle = _seconds % 19;
    String phaseText;
    String phaseDesc;
    Color phaseColor;
    double targetScale;

    if (cycle < 4) {
      phaseText = 'Tarik Napas';
      phaseDesc = 'Hirup napas perlahan melalui hidung (${4 - cycle}s)';
      phaseColor = const Color(0xFF6C5CE7);
      targetScale = 0.85 + (cycle / 4.0) * 0.35;
    } else if (cycle < 11) {
      final holdLeft = 11 - cycle;
      phaseText = 'Tahan Napas';
      phaseDesc = 'Tahan napas di dalam dada ($holdLeft s)';
      phaseColor = const Color(0xFFF59E0B);
      targetScale = 1.2;
    } else {
      final exhaleLeft = 19 - cycle;
      phaseText = 'Hembuskan Napas';
      phaseDesc = 'Lepaskan napas perlahan dari mulut ($exhaleLeft s)';
      phaseColor = const Color(0xFF00CEC9);
      targetScale = 1.2 - ((cycle - 11) / 8.0) * 0.35;
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Latihan Napas 4-7-8',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Meredakan panik & menstabilkan detak jantung',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 36),

          // Animated Breathing Circle
          SizedBox(
            height: 180,
            child: Center(
              child: AnimatedScale(
                scale: targetScale,
                duration: const Duration(seconds: 1),
                curve: Curves.easeInOut,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: phaseColor.withValues(alpha: 0.15),
                    border: Border.all(color: phaseColor, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: phaseColor.withValues(alpha: 0.25),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.air, color: phaseColor, size: 30),
                        const SizedBox(height: 6),
                        Text(
                          phaseText,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: phaseColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Phase Description
          Text(
            phaseDesc,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 28),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Mulai Ulang'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _togglePlayPause,
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 18),
                label: Text(_isPlaying ? 'Jeda' : 'Lanjutkan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

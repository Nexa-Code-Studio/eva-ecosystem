import "dart:async";
import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../theme/app_colors.dart";

/// Modal bottom sheet content for home screen with rationale, steps, and breath pacer
class HomeActivityModalContent extends StatefulWidget {
  final Map<String, dynamic> activity;
  final String conditionReason;
  final bool isCompleted;
  final VoidCallback onComplete;

  const HomeActivityModalContent({
    super.key,
    required this.activity,
    required this.conditionReason,
    required this.isCompleted,
    required this.onComplete,
  });

  @override
  State<HomeActivityModalContent> createState() =>
      HomeActivityModalContentState();
}

class HomeActivityModalContentState extends State<HomeActivityModalContent> {
  bool _isBreathPacerActive = false;
  int _breathTimerSec = 0;
  String _breathPhase = 'Tarik Napas';
  Timer? _breathTimer;

  @override
  void dispose() {
    _breathTimer?.cancel();
    super.dispose();
  }

  void _toggleBreathPacer() {
    if (_isBreathPacerActive) {
      _breathTimer?.cancel();
      setState(() {
        _isBreathPacerActive = false;
        _breathTimerSec = 0;
        _breathPhase = 'Selesai';
      });
    } else {
      setState(() {
        _isBreathPacerActive = true;
        _breathTimerSec = 0;
        _breathPhase = 'Tarik Napas (4 dtk)';
      });

      _breathTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          _breathTimerSec++;
          final cycle = _breathTimerSec % 19;
          if (cycle < 4) {
            _breathPhase = 'Tarik Napas Perlahan (4s)';
          } else if (cycle < 11) {
            _breathPhase = 'Tahan Napas di Dada (7s)';
          } else {
            _breathPhase = 'Hembuskan Napas Rileks (8s)';
          }
        });
      });
    }
  }

  String _normalizeCategory(String? raw) {
    final cat = (raw ?? '').toLowerCase();
    if (cat.contains('mindful') || cat.contains('napas') || cat.contains('breath')) return 'Mindfulness';
    if (cat.contains('cbt') || cat.contains('kognitif') || cat.contains('problem')) return 'CBT';
    if (cat.contains('refleksi') || cat.contains('syukur') || cat.contains('self-care')) return 'Refleksi';
    if (cat.contains('fisik') || cat.contains('gerak') || cat.contains('somatis') || cat.contains('aktivasi') || cat.contains('jalan')) return 'Fisik & Gerak';
    return raw?.isNotEmpty == true ? raw! : 'Self-Care';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.activity['title']?.toString() ?? 'Latihan Relaksasi';
    final rawCat = widget.activity['category']?.toString() ?? 'Self-Care';
    final category = _normalizeCategory(rawCat);
    final duration = widget.activity['duration']?.toString() ?? '5 menit';
    final difficulty = widget.activity['difficulty']?.toString() ?? 'Pemula';
    final description = widget.activity['description']?.toString() ?? '';
    final rationale = widget.activity['rationale']?.toString() ?? '';
    final rawInstructions = widget.activity['instructions'];
    List<String> instructions = rawInstructions is List
        ? List<String>.from(rawInstructions.map((e) => e.toString()))
        : <String>[];

    if (instructions.isEmpty) {
      instructions = [
        'Cari posisi duduk yang santai dan nyaman.',
        'Tarik napas dalam perlahan dan hembuskan perlahan.',
        'Lakukan langkah latihan ini secara tenang selama $duration.',
        'Rasakan perubahan sensasi rileks di tubuhmu setelah selesai.'
      ];
    }

    final displayRationale =
        rationale.isNotEmpty ? rationale : widget.conditionReason;

    final isBreathingActivity = title.toLowerCase().contains('napas') ||
        title.toLowerCase().contains('breath') ||
        category.toLowerCase() == 'mindfulness';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header tags & close button (X)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  category.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '•  $duration  •  $difficulty',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Title
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),

          // Description
          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Rationale Card
                  if (displayRationale.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFDDD6FE)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lightbulb_outline,
                            size: 18,
                            color: Color(0xFF7C3AED),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kenapa Latihan Ini Membantu?',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF5B21B6),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  displayRationale,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    height: 1.4,
                                    color: const Color(0xFF6D28D9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 2. Interactive Breath Pacer (if relevant)
                  if (isBreathingActivity) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFEEF2FF),
                            Color(0xFFE0E7FF),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFC7D2FE)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.air,
                                      size: 16, color: Color(0xFF4F46E5)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Pemandu Irama Napas',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF3730A3),
                                    ),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: _toggleBreathPacer,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isBreathPacerActive
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF4F46E5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _isBreathPacerActive
                                        ? 'Hentikan'
                                        : 'Mulai Pemandu',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_isBreathPacerActive) ...[
                            const SizedBox(height: 14),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 700),
                              width: _breathPhase.contains('Tarik') ? 80 : 65,
                              height: _breathPhase.contains('Tarik') ? 80 : 65,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF6366F1)
                                    .withValues(alpha: 0.2),
                                border: Border.all(
                                    color: const Color(0xFF4F46E5), width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  '${_breathTimerSec}s',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF3730A3),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _breathPhase,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF4338CA),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 3. Step-by-step instructions
                  Text(
                    'Langkah-Langkah yang Perlu Dilakukan:',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: instructions.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${idx + 1}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              instructions[idx],
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                height: 1.4,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Completion Button CTA
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onComplete,
              icon: Icon(
                widget.isCompleted ? Icons.check_circle : Icons.check,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                widget.isCompleted
                    ? 'Sudah Diselesaikan Hari Ini'
                    : 'Saya Sudah Melakukan Latihan Ini',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isCompleted
                    ? const Color(0xFF10B981)
                    : AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

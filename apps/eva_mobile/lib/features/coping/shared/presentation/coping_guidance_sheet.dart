import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_colors.dart';
import '../../../../widgets/app_back_button.dart';
import '../domain/coping_exercise_definition.dart';
import '../domain/coping_session_result.dart';
import '../domain/coping_tutorial_data.dart';
import 'coping_tutorial_dialog.dart';

/// Shared step-by-step detail sheet/view for non-breathing coping modules.
class CopingGuidanceSheet extends StatelessWidget {
  final CopingExerciseDefinition exercise;
  final List<String> instructions;
  final String rationale;
  final bool isCompleted;
  final VoidCallback onComplete;

  const CopingGuidanceSheet({
    super.key,
    required this.exercise,
    required this.instructions,
    required this.rationale,
    required this.isCompleted,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final steps = instructions.isNotEmpty
        ? instructions
        : exercise.defaultInstructions;
    final whyText = rationale.isNotEmpty
        ? rationale
        : exercise.defaultRationale;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
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
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  exercise.category.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                exercise.estimatedDurationLabel,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Tutup panduan',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: const Icon(
                  Icons.close,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            exercise.title,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            exercise.subtitle,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (whyText.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(
                          alpha: 0.65,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderSoft),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lightbulb_outline_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Kenapa Latihan Ini Membantu?',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  whyText,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    height: 1.45,
                                    color: AppColors.textPrimary,
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
                  Text(
                    'Langkah-Langkah Latihan:',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: steps.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
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
                              steps[idx],
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                height: 1.45,
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
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onComplete,
              icon: Icon(
                isCompleted ? Icons.check_circle : Icons.check,
                color: Colors.white,
                size: 18,
              ),
              label: Text(
                isCompleted ? 'Sudah Diselesaikan Hari Ini' : 'Tandai Selesai',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isCompleted
                    ? AppColors.successDark
                    : AppColors.primary,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
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

/// Dedicated interactive step-by-step session page for non-breathing coping modules.
class CopingStepExercisePage extends StatefulWidget {
  final CopingExerciseDefinition exercise;
  final CopingTutorialData? tutorial;
  final List<String>? customInstructions;
  final String? customRationale;
  final bool initialCompleted;

  const CopingStepExercisePage({
    super.key,
    required this.exercise,
    this.tutorial,
    this.customInstructions,
    this.customRationale,
    this.initialCompleted = false,
  });

  @override
  State<CopingStepExercisePage> createState() => _CopingStepExercisePageState();
}

class _CopingStepExercisePageState extends State<CopingStepExercisePage> {
  final Stopwatch _stopwatch = Stopwatch();
  final TextEditingController _noteController = TextEditingController();

  late final List<String> _steps =
      (widget.customInstructions != null &&
          widget.customInstructions!.isNotEmpty)
      ? widget.customInstructions!
      : widget.exercise.defaultInstructions.isNotEmpty
      ? widget.exercise.defaultInstructions
      : const [
          'Ambil posisi duduk yang nyaman dan tenang.',
          'Fokuskan perhatianmu pada satu langkah dalam satu waktu.',
          'Amati rasa lebih tenang yang muncul setelah menyelesaikan latihan.',
        ];

  late bool _sessionStarted = widget.tutorial == null;
  int _currentStepIndex = 0;

  @override
  void initState() {
    super.initState();
    if (_sessionStarted) {
      _stopwatch.start();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || widget.tutorial == null) return;
        final started = await showCopingTutorialDialog(
          context,
          widget.tutorial!,
        );
        if (!mounted) return;
        if (!started) {
          Navigator.of(context).pop(
            CopingSessionResult.cancelled(
              exerciseId: widget.exercise.id,
              elapsed: Duration.zero,
            ),
          );
          return;
        }
        setState(() {
          _sessionStarted = true;
          _stopwatch.start();
        });
      });
    }
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _noteController.dispose();
    super.dispose();
  }

  void _cancelSession() {
    Navigator.of(context).pop(
      CopingSessionResult.cancelled(
        exerciseId: widget.exercise.id,
        elapsed: _stopwatch.elapsed,
      ),
    );
  }

  void _finishSession() {
    Navigator.of(context).pop(
      CopingSessionResult.completed(
        exerciseId: widget.exercise.id,
        elapsed: _stopwatch.elapsed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _steps.length;
    final progress = (_currentStepIndex + 1) / total;
    final isLastStep = _currentStepIndex >= total - 1;
    final supportsNote =
        widget.exercise.id == 'gratitude_journal' ||
        widget.exercise.category.toLowerCase().contains('refleksi');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _cancelSession();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    AppBackButton(onPressed: _cancelSession),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.exercise.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Langkah ${_currentStepIndex + 1}/$total',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceHigh,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.borderSoft),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${_currentStepIndex + 1}',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _sessionStarted
                                        ? 'Fokus Langkah Ini'
                                        : 'Membaca Panduan Sesi...',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: Text(
                                _steps[_currentStepIndex],
                                key: ValueKey<int>(_currentStepIndex),
                                style: GoogleFonts.inter(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (supportsNote && isLastStep) ...[
                              const SizedBox(height: 18),
                              TextField(
                                controller: _noteController,
                                maxLines: 3,
                                style: GoogleFonts.inter(
                                  fontSize: 13.5,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      'Catatan singkat untuk dirimu sendiri (opsional)...',
                                  hintStyle: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.background,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: AppColors.borderSoft,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: AppColors.borderSoft,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.customRationale != null &&
                          widget.customRationale!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withValues(
                              alpha: 0.55,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderSoft),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.spa_outlined,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  widget.customRationale!,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    height: 1.45,
                                    color: AppColors.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Row(
                  children: [
                    if (_currentStepIndex > 0) ...[
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('coping_step_prev_button'),
                          onPressed: _sessionStarted
                              ? () => setState(() => _currentStepIndex -= 1)
                              : null,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(color: AppColors.borderSoft),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                          ),
                          child: Text(
                            'Sebelumnya',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        key: const Key('coping_step_next_button'),
                        onPressed: !_sessionStarted
                            ? null
                            : isLastStep
                            ? _finishSession
                            : () => setState(() => _currentStepIndex += 1),
                        icon: Icon(
                          isLastStep
                              ? Icons.check_circle_outline_rounded
                              : Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: Text(
                          isLastStep
                              ? (widget.initialCompleted
                                    ? 'Selesai Lagi'
                                    : 'Selesaikan Latihan')
                              : 'Langkah Berikutnya',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isLastStep
                              ? AppColors.successDark
                              : AppColors.primary,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

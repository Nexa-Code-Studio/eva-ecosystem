import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:eva_mobile/features/voice_call/domain/entities/call_state.dart';
import 'package:eva_mobile/features/voice_call/presentation/controllers/ai_call_controller.dart';
import 'package:eva_mobile/features/voice_call/presentation/controllers/ai_call_state.dart';
import 'package:eva_mobile/features/voice_call/presentation/providers/ai_call_provider.dart';
import 'package:eva_mobile/features/voice_call/presentation/widgets/morphing_voice_nodes_visualizer.dart';
import 'package:eva_mobile/services/daily_progress_local_service.dart';
import 'package:eva_mobile/theme/app_colors.dart';
import 'package:eva_mobile/widgets/app_back_button.dart';
import 'package:eva_mobile/widgets/custom_button.dart';
import 'package:eva_mobile/widgets/glass_card.dart';
import 'package:eva_mobile/features/emergency/presentation/screens/support_emergency_screen.dart';
import 'package:eva_mobile/features/tutorial/domain/entities/tutorial_step.dart';
import 'package:eva_mobile/features/tutorial/presentation/providers/tutorial_provider.dart';
import 'package:eva_mobile/features/tutorial/presentation/widgets/interactive_spotlight_overlay.dart';

class VoiceCallScreen extends ConsumerStatefulWidget {
  const VoiceCallScreen({super.key});

  @override
  ConsumerState<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends ConsumerState<VoiceCallScreen>
    with TickerProviderStateMixin {
  late final AnimationController _aiRippleController;

  @override
  void initState() {
    super.initState();
    _aiRippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(aiCallControllerProvider.notifier).startCall();
    });
  }

  @override
  void dispose() {
    _aiRippleController.dispose();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _handleExitCall(AiCallViewState state) {
    if (state.isCrisisSession) {
      ref.read(aiCallControllerProvider.notifier).endCall();
      Navigator.pushReplacement(context, SupportEmergencyScreen.route());
    } else {
      _showSessionSummaryBottomSheet(state.callDurationSeconds);
    }
  }

  bool _isHighDistressSession(AiCallViewState state) {
    if (state.crisisHotline != null) return true;
    final text = '${state.currentTranscript} ${state.aiTranscript}'.toLowerCase();
    final highDistressKeywords = [
      'krisis',
      'panik',
      'sesak',
      'bunuh diri',
      'menyakiti',
      'tidak sanggup',
      'kelelahan mental',
      'anxiety berat',
      'depresi berat',
      'putus asa',
      'tidak ada harapan',
      'takut sekali',
      'stres berat',
    ];
    return highDistressKeywords.any((k) => text.contains(k));
  }

  bool _isDassTriggeredSession(AiCallViewState state) {
    if (state.crisisHotline != null) return true;
    final text = '${state.currentTranscript} ${state.aiTranscript}'.toLowerCase();
    final dassKeywords = [
      'dass',
      'skala 0',
      'skor 0',
      'pertanyaan asesmen',
      'gejala yang kamu rasakan',
      'seberapa sering kamu merasa',
      'jantung berdebar',
      'sulit bernapas',
      'cemas berlebihan',
      'merasa putus asa',
      'kehilangan minat',
      'panik',
      'stres berat',
      'depresi berat',
    ];
    return dassKeywords.any((k) => text.contains(k));
  }

  void _showSessionSummaryBottomSheet(int durationSeconds) {
    final state = ref.read(aiCallControllerProvider);
    ref.read(aiCallControllerProvider.notifier).endCall();
    final isHighDistress = _isHighDistressSession(state);
    final hasDassTriggered = _isDassTriggeredSession(state);

    if (isHighDistress) {
      _showPostCallCrisisModal(durationSeconds);
    } else {
      _showNormalSessionSummaryBottomSheet(
        durationSeconds,
        false,
        hasDassTriggered: hasDassTriggered,
      );
    }
  }

  void _showPostCallCrisisModal(int durationSeconds) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Glowing Heart Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFE0E3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE57373).withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.favorite,
                  color: Color(0xFFE57373),
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                'Deteksi Beban Emosional Berat 🍃',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                'EVA mendeteksi tingkat ketegangan dan beban emosional yang tinggi dalam percakapan tadi. Kamu tidak harus memikulnya sendirian.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),

              // Reassurance info box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFE57373).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.air_rounded,
                      color: Color(0xFFE57373),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tersedia Latihan Napas 4-7-8 untuk menstabilkan detak jantung, kontak orang terpercaya, dan hotline krisis.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF881337),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action 1: Open Crisis Support (Pink/Rose button)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE57373),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  icon: const Icon(Icons.favorite_rounded, size: 18),
                  label: Text(
                    'Buka Latihan Napas & Bantuan Krisis',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/support');
                  },
                ),
              ),
              const SizedBox(height: 10),

              // Action 2: Review Session Summary
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _showNormalSessionSummaryBottomSheet(
                      durationSeconds,
                      true,
                      hasDassTriggered: true,
                    );
                  },
                  child: Text(
                    'Lihat Ringkasan Sesi Dulu',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNormalSessionSummaryBottomSheet(
    int durationSeconds,
    bool isHighDistress, {
    bool hasDassTriggered = false,
  }) {
    DailyProgressLocalService.recordConversationCheckin(hasConversation: true);

    final tutorialState = ref.read(tutorialNotifierProvider);
    final isTutorialActive = !tutorialState.isCompleted &&
        (tutorialState.currentStep == TutorialStep.voiceCompleted ||
            tutorialState.currentStep == TutorialStep.voiceStart ||
            tutorialState.currentStep == TutorialStep.voiceCoins);

    if (isTutorialActive) {
      ref
          .read(tutorialNotifierProvider.notifier)
          .resumeAtStep(TutorialStep.voiceCompleted);
    }

    final GlobalKey journalButtonKey = GlobalKey(debugLabel: 'journalDetailButton');

    void navigateToJournal(BuildContext bottomSheetContext) {
      final currentTutorialState = ref.read(tutorialNotifierProvider);
      if (!currentTutorialState.isCompleted &&
          (currentTutorialState.currentStep == TutorialStep.voiceCompleted ||
              currentTutorialState.currentStep == TutorialStep.voiceStart ||
              currentTutorialState.currentStep == TutorialStep.voiceCoins)) {
        ref
            .read(tutorialNotifierProvider.notifier)
            .onTargetTapped(TutorialStep.voiceCompleted);
      }
      Navigator.pop(bottomSheetContext); // Close Bottom Sheet
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
        (route) => false,
        arguments: {'initialIndex': 1},
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: !isTutorialActive,
      enableDrag: !isTutorialActive,
      builder: (bottomSheetContext) {
        final Widget sheetCard = Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sesi Suara Selesai 🍃',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Durasi: ${_formatDuration(durationSeconds)} • Hybrid Half-Duplex',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // If High Distress: Show top Crisis Support Card
              if (isHighDistress) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE57373).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFDCDD),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Color(0xFFE57373),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Intervensi De-eskalasi Disarankan',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFD32F2F),
                              ),
                            ),
                            Text(
                              'Coba teknik napas 4-7-8 untuk menenangkan detak jantung.',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/support');
                        },
                        child: Text(
                          'Buka →',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFD32F2F),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              if (hasDassTriggered) ...[
                GlassCard(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F4FB),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'SINTESIS OTOMATIS DASS-21',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF20667B),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'EVA telah mengekstrak indikator stres, kecemasan, dan suasana hatimu dari percakapan tadi ke dalam lembar DASS-21 hari ini. Kamu bisa langsung meninjau bukti kutipan obrolan, mengedit skor, atau melengkapi butir yang belum terbahas.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                CustomPillButton(
                  text: 'Tinjau & Lengkapi Skor DASS-21',
                  suffixIcon: Icons.arrow_forward_rounded,
                  onPressed: () {
                    Navigator.pop(context); // Close Bottom Sheet
                    Navigator.pushNamed(context, '/dass_assessment');
                  },
                ),
                const SizedBox(height: 10),
              ] else ...[
                GlassCard(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'REFLEKSI HARIAN TERSIMPAN',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF2E7D32),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Obrolanmu telah tersimpan dan terangkum rapi ke dalam catatan refleksi emosimu hari ini. Kamu bisa membacanya kembali kapan saja.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              CustomPillButton(
                key: journalButtonKey,
                text: 'Lihat Detail Jurnal Refleksi',
                isOutline: hasDassTriggered,
                onPressed: () => navigateToJournal(bottomSheetContext),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: isTutorialActive
                      ? null
                      : () {
                          Navigator.pop(bottomSheetContext);
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/home',
                            (route) => false,
                          );
                        },
                  child: Text(
                    'Kembali ke Beranda',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isTutorialActive
                          ? AppColors.textLight.withValues(alpha: 0.35)
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        if (isTutorialActive) {
          return SizedBox(
            height: MediaQuery.of(bottomSheetContext).size.height,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: sheetCard,
                ),
                InteractiveSpotlightOverlay(
                  targetKey: journalButtonKey,
                  content: TutorialContent.stepContents[TutorialStep.voiceCompleted]!,
                  onSkip: () {
                    ref.read(tutorialNotifierProvider.notifier).skipTutorial();
                    Navigator.pop(bottomSheetContext);
                  },
                  onNext: () => navigateToJournal(bottomSheetContext),
                  onTargetTap: () => navigateToJournal(bottomSheetContext),
                ),
              ],
            ),
          );
        }

        return sheetCard;
      },
    );
  }

  void _showSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalContext) {
        return Consumer(
          builder: (context, ref, _) {
            final currentState = ref.watch(aiCallControllerProvider);
            final currentController = ref.read(aiCallControllerProvider.notifier);

            return Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1B2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Pengaturan Panggilan',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pilih metode interaksi suara yang paling nyaman untuk Anda.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white60,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildSettingsModeTile(
                    title: 'Auto Turn (Otomatis)',
                    subtitle: 'Deteksi jeda ucapan otomatis tanpa perlu menekan tombol.',
                    isSelected: currentState.conversationMode == ConversationMode.hybridAuto,
                    onTap: () {
                      currentController.setConversationMode(ConversationMode.hybridAuto);
                      Navigator.pop(modalContext);
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildSettingsModeTile(
                    title: 'Push-To-Talk (Manual)',
                    subtitle: 'Tekan dan tahan tombol saat Anda ingin berbicara ke EVA.',
                    isSelected: currentState.conversationMode == ConversationMode.pushToTalk,
                    onTap: () {
                      currentController.setConversationMode(ConversationMode.pushToTalk);
                      Navigator.pop(modalContext);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingsModeTile({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.white10,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white60,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.primary : Colors.white38,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiCallControllerProvider);
    final controller = ref.read(aiCallControllerProvider.notifier);

    if (!_aiRippleController.isAnimating) {
      _aiRippleController.repeat();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleExitCall(state);
        }
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF13111C),
                Color(0xFF0F0E17),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header Bar with Back Button, Centered Duration Timer, and Settings Icon
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      AppBackButton.dark(
                        onPressed: () => _handleExitCall(state),
                      ),
                    Expanded(
                      child: Center(
                        child: Text(
                          _formatDuration(state.callDurationSeconds),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: Colors.white),
                      onPressed: () => _showSettingsBottomSheet(context),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Center Avatar Orb with Multi-Layer Ripple Wave Animation
              _buildInteractiveAvatarOrb(state),

              const SizedBox(height: 24),

              // Title & Clean Subtitle Info
              Text(
                'EVA AI Assistant',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _getCleanStatusText(state),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: state.isMuted ? const Color(0xFFFF8B94) : Colors.white70,
                  letterSpacing: 0.2,
                ),
              ),

              // Dynamic Live Transcript preview
              if (state.latestPartial.isNotEmpty || state.currentTranscript.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 8.0),
                  child: Text(
                    '"${state.latestPartial.isNotEmpty ? state.latestPartial : state.currentTranscript}"',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Colors.white60,
                    ),
                  ),
                ),



              const Spacer(),

              // INTERACTIVE ACTION CONTROLS
              // 1. In LISTENING: "Selesai Bicara" (Manual Force Commit)
              // 2. In AI_SPEAKING or THINKING: "Bicara (Potong AI)" (Manual Barge-In)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildMainActionButton(state, controller),
              ),

              const SizedBox(height: 24),

              // Bottom Control Bar (Mute, End Call, Speaker)
              Padding(
                padding: const EdgeInsets.fromLTRB(36.0, 0, 36.0, 32.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute Microphone Button
                    GestureDetector(
                      onTap: () => controller.toggleMute(),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: state.isMuted
                              ? const Color(0xFFE53935)
                              : Colors.white.withValues(alpha: 0.15),
                        ),
                        child: Icon(
                          state.isMuted ? Icons.mic_off : Icons.mic,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),

                    // End Call Button
                    GestureDetector(
                      onTap: () => _handleExitCall(state),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFD32F2F),
                        ),
                        child: const Icon(
                          Icons.call_end,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),

                    // Speakerphone Toggle Button
                    GestureDetector(
                      onTap: () => controller.toggleSpeaker(),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: state.isSpeakerOn
                              ? const Color(0xFF3F51B5)
                              : Colors.white.withValues(alpha: 0.15),
                        ),
                        child: Icon(
                          state.isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                          color: Colors.white,
                          size: 26,
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
    ),
  );
}



  Widget _buildMainActionButton(AiCallViewState state, AiCallController controller) {
    if (state.conversationMode == ConversationMode.pushToTalk) {
      return GestureDetector(
        onTapDown: (_) => controller.pushToTalkPress(),
        onTapUp: (_) => controller.pushToTalkRelease(),
        onTapCancel: () => controller.pushToTalkRelease(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: state.callState == CallState.listening
                ? const Color(0xFFE53935)
                : AppColors.primary,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.touch_app, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Tahan untuk Bicara',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Hybrid Auto Mode Dynamic Action Button
    if (state.callState == CallState.aiSpeaking) {
      // Barge-in / Jeda AI button (Simple & elegant, matching Selesai Bicara style)
      return ElevatedButton.icon(
        onPressed: () => controller.bargeIn(),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF59E0B),
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
        ),
        icon: const Icon(Icons.pause_rounded, color: Colors.white, size: 20),
        label: Text(
          'Jeda AI',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
      );
    } else if (state.callState == CallState.thinking) {
      // Non-interactive thinking badge to prevent accidental tap cancellation
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Text(
              'Eva sedang memproses...',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      );
    } else if (state.callState == CallState.listening &&
        (state.currentTranscript.isNotEmpty || state.latestPartial.isNotEmpty)) {
      // Force Commit button (Only when user has actually spoken something)
      return ElevatedButton.icon(
        onPressed: () => controller.forceCommit(),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
        label: Text(
          'Selesai Bicara',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    }

    return const SizedBox(height: 48);
  }

  String _getCleanStatusText(AiCallViewState state) {
    if (state.isMuted) return 'Mikrofon Di-Mute';

    switch (state.callState) {
      case CallState.listening:
        return state.isUserSpeaking
            ? 'Mendengarkan (Anda sedang berbicara)'
            : 'Mendengarkan...';
      case CallState.thinking:
        return 'AI Memproses...';
      case CallState.aiSpeaking:
        return 'EVA Sedang Berbicara...';
      case CallState.interrupting:
        return 'Memotong Suara EVA...';
      case CallState.idle:
      case CallState.ended:
      case CallState.error:
        return state.errorMessage ?? 'Standby';
    }
  }

  Widget _buildInteractiveAvatarOrb(AiCallViewState state) {
    final bool isAiSpeaking = state.callState == CallState.aiSpeaking;
    final double soundLevel = state.isMuted ? 0.0 : state.soundLevel;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _aiRippleController,
        builder: (context, child) {
          final animValue = _aiRippleController.value;

          return Center(
            child: SizedBox(
              width: 280,
              height: 280,
              child: Stack(
                alignment: Alignment.center,
                children: [
                // 1. RADIAL FREQUENCY EQUALIZER BARS (CIRCULAR AUDIO SPECTRUM)
                CustomPaint(
                  size: const Size(280, 280),
                  painter: RadialFrequencyBarsPainter(
                    animationProgress: animValue,
                    soundLevel: soundLevel,
                    isAiSpeaking: isAiSpeaking,
                    isMuted: state.isMuted,
                  ),
                ),

                // 2. SOFT AMBIENT IRIDESCENT HALO
                Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFC7D2FE).withValues(
                          alpha: state.isMuted ? 0.08 : 0.20 + ((isAiSpeaking ? soundLevel : 0.0) * 0.25),
                        ),
                        blurRadius: 36 + ((isAiSpeaking ? soundLevel : 0.0) * 20),
                        spreadRadius: 3,
                      ),
                      BoxShadow(
                        color: const Color(0xFFFFD1DC).withValues(
                          alpha: state.isMuted ? 0.05 : 0.15 + ((isAiSpeaking ? soundLevel : 0.0) * 0.15),
                        ),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),

                // 3. MAIN ORB (PASTEL / IRIDESCENT SPHERE)
                Container(
                  width: 174,
                  height: 174,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // Soft iridescent pastel gradient exactly like the design
                    gradient: const RadialGradient(
                      center: Alignment(-0.25, -0.35),
                      radius: 0.95,
                      colors: [
                        Color(0xFFFFFFFF), // soft white highlight
                        Color(0xFFEDE9FE), // pale lavender
                        Color(0xFFE0E7FF), // soft periwinkle
                        Color(0xFFBAE6FD), // soft cyan edge
                      ],
                      stops: [0.0, 0.45, 0.75, 1.0],
                    ),
                    border: Border.all(
                      // Thin subtle iridescent outer border
                      color: const Color(0xFFE2E8F0).withValues(alpha: 0.7),
                      width: 1.5,
                    ),
                    boxShadow: [
                      // Subtle rim illumination
                      BoxShadow(
                        color: const Color(0xFF818CF8).withValues(alpha: 0.25),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: const Color(0xFFF472B6).withValues(alpha: 0.20),
                        blurRadius: 20,
                        spreadRadius: -2,
                        offset: const Offset(4, -2),
                      ),
                    ],
                  ),
                  child: Center(
                    // 4. UNIFIED MORPHING VOICE NODES VISUALIZER
                    // Seamless pure code transformation:
                    // Listening / User Speaking / AI Speaking: Equalizer bars / flat dots
                    // Thinking: Nodes morph, expand, orbit in circle with glowing aurora colors, and return smoothly.
                    child: MorphingVoiceNodesVisualizer(
                      callState: state.callState,
                      soundLevel: soundLevel,
                      isAiSpeaking: isAiSpeaking,
                      animValue: animValue,
                      isMuted: state.isMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
}

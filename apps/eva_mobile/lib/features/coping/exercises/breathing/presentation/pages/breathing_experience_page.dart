import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../shared/domain/coping_session_result.dart';
import '../../../../shared/domain/coping_tutorial_data.dart';
import '../../../../shared/presentation/coping_tutorial_dialog.dart';
import '../../application/breathing_controller.dart';
import '../../application/breathing_state.dart';
import '../../infrastructure/breathing_audio_adapter.dart';
import '../../infrastructure/breathing_timeline_loader.dart';
import '../widgets/breathing_phase_label.dart';
import '../widgets/breathing_session_controls.dart';
import '../widgets/breathing_touch_ripple.dart';
import '../widgets/breathing_visual_stage.dart';

/// Injectable timeline loader provider (overridable in widget tests).
final breathingTimelineLoaderProvider = Provider<BreathingTimelineLoader>(
  (ref) => BreathingTimelineLoader(),
);

/// Factory provider creating an isolated per-session [BreathingController].
final breathingControllerProvider =
    StateNotifierProvider.autoDispose<BreathingController, BreathingState>((
      ref,
    ) {
      final loader = ref.watch(breathingTimelineLoaderProvider);
      final audio = AudioplayersBreathingAdapter();
      return BreathingController(timelineLoader: loader, audioAdapter: audio);
    });

/// Full-screen immersive guided breathing exercise route.
class BreathingExperiencePage extends ConsumerStatefulWidget {
  final bool forceVisualOnly;
  final String? timelineAsset;
  final CopingTutorialData? tutorial;

  const BreathingExperiencePage({
    super.key,
    this.forceVisualOnly = false,
    this.timelineAsset,
    this.tutorial,
  });

  @override
  ConsumerState<BreathingExperiencePage> createState() =>
      _BreathingExperiencePageState();
}

class _BreathingExperiencePageState
    extends ConsumerState<BreathingExperiencePage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _exiting = false;
  late bool _awaitingTutorial = widget.tutorial != null;
  late final BreathingController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = ref.read(breathingControllerProvider.notifier);
    _enterImmersiveSystemUi();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _controller.attachTickerProvider(this);
      _controller.setReducedMotion(MediaQuery.disableAnimationsOf(context));

      if (widget.tutorial != null) {
        final started = await showCopingTutorialDialog(
          context,
          widget.tutorial!,
        );
        if (!mounted) return;
        if (!started) {
          _awaitingTutorial = false;
          await _handleExit();
          return;
        }
        setState(() => _awaitingTutorial = false);
      }

      if (!mounted) return;
      await _controller.initializeAndStart(
        timelineAsset:
            widget.timelineAsset ??
            BreathingTimelineLoader.defaultTimelineAsset,
        forceVisualOnly: widget.forceVisualOnly,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.setReducedMotion(disableAnimations);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _controller.handleAppBackgrounded();
    }
  }

  void _enterImmersiveSystemUi() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0B1027),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  void _restoreSystemUi() {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _handleExit({bool allowPop = true}) async {
    if (_exiting) return;
    _exiting = true;
    final result = await _controller.cancel();
    _restoreSystemUi();
    if (allowPop && mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.detachTickerProvider();
    _restoreSystemUi();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(breathingControllerProvider);
    final reducedMotion =
        MediaQuery.disableAnimationsOf(context) || state.reducedMotion;

    ref.listen<BreathingState>(breathingControllerProvider, (prev, next) {
      if (prev?.currentPhase != next.currentPhase &&
          next.isPlaying &&
          !reducedMotion) {
        HapticFeedback.selectionClick();
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleExit();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1027),
        body: BreathingTouchRipple(
          enabled: !reducedMotion && state.isPlaying,
          child: Stack(
            fit: StackFit.expand,
            children: [
              BreathingVisualStage(
                motion: _controller.motionListenable,
                reducedMotion: reducedMotion,
              ),
              SafeArea(
                child: Column(
                  children: [
                    BreathingSessionControls(
                      isPlaying: state.isPlaying,
                      isPaused: state.isPaused,
                      isAudioGuided: state.isAudioGuided,
                      isMuted: state.isMuted,
                      isLoadingOrError:
                          _awaitingTutorial ||
                          state.isLoading ||
                          state.hasError ||
                          state.hasCompleted,
                      onExit: () => _handleExit(),
                      onTogglePlayPause: _controller.togglePlayPause,
                      onToggleMute: _controller.toggleMute,
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: state.isLoading
                              ? Padding(
                                  padding: const EdgeInsets.only(bottom: 48),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(
                                        color: Color(0xFFD9C8FF),
                                        strokeWidth: 2.2,
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        'Menyiapkan sesi napas...',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: const Color(0xFFB6B2CF),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : state.hasError
                              ? _ErrorCard(
                                  message:
                                      state.errorMessage ??
                                      'Terjadi gangguan saat memuat panduan napas.',
                                  onRetry: () => _controller.initializeAndStart(
                                    timelineAsset:
                                        widget.timelineAsset ??
                                        BreathingTimelineLoader
                                            .defaultTimelineAsset,
                                    forceVisualOnly: widget.forceVisualOnly,
                                  ),
                                  onContinueVisualOnly:
                                      _controller.switchToVisualOnlyFromError,
                                  onExit: () => _handleExit(),
                                )
                              : state.hasCompleted
                              ? _CompletionCard(
                                  isVisualOnly: !state.isAudioGuided,
                                  onDone: () {
                                    if (_exiting) return;
                                    _exiting = true;
                                    _restoreSystemUi();
                                    Navigator.of(context).pop(
                                      CopingSessionResult.completed(
                                        exerciseId: 'breathing',
                                        elapsed: Duration(
                                          milliseconds: state.durationMs,
                                        ),
                                        isVisualOnly: !state.isAudioGuided,
                                      ),
                                    );
                                  },
                                )
                              : Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    0,
                                    24,
                                    34,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      BreathingPhaseLabel(
                                        phase: state.currentPhase,
                                        phaseRemainingSeconds:
                                            state.phaseRemainingSeconds,
                                        isPaused:
                                            state.isPaused || state.isBuffering,
                                        motion: _controller.motionListenable,
                                      ),
                                      if (state.isBuffering) ...[
                                        const SizedBox(height: 10),
                                        Text(
                                          'Menyelaraskan audio...',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: const Color(0xFFB6B2CF),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
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

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onContinueVisualOnly;
  final VoidCallback onExit;

  const _ErrorCard({
    required this.message,
    required this.onRetry,
    required this.onContinueVisualOnly,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF17183D).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFFF4EFFF),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onContinueVisualOnly,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B93FF),
                foregroundColor: const Color(0xFF0B1027),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text(
                'Lanjutkan Mode Visual',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: onRetry,
                child: Text(
                  'Coba Lagi',
                  style: GoogleFonts.inter(color: const Color(0xFFD9C8FF)),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: onExit,
                child: Text(
                  'Keluar',
                  style: GoogleFonts.inter(color: const Color(0xFFB6B2CF)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  final bool isVisualOnly;
  final VoidCallback onDone;

  const _CompletionCard({required this.isVisualOnly, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 34),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF17183D).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x4DD9C8FF)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            size: 36,
            color: Color(0xFFD9C8FF),
          ),
          const SizedBox(height: 10),
          Text(
            'Latihan Selesai',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFF4EFFF),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Kembali bernapas seperti biasa. Terima kasih sudah meluangkan waktu untuk dirimu.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              height: 1.45,
              color: const Color(0xFFB6B2CF),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('breathing_done_button'),
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD9C8FF),
                foregroundColor: const Color(0xFF0B1027),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text(
                'Selesai',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

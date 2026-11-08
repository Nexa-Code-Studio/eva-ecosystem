import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:eva_mobile/theme/app_colors.dart';
import 'package:eva_mobile/widgets/floating_nav_bar.dart';
import 'package:eva_mobile/features/diary/presentation/screens/ai_diary_screen.dart';
import 'home_screen.dart';
import 'package:eva_mobile/features/monitoring/presentation/screens/monitoring_screen.dart';
import 'package:eva_mobile/features/care/presentation/screens/care_screen.dart';
import 'package:eva_mobile/features/tutorial/domain/entities/tutorial_step.dart';
import 'package:eva_mobile/features/tutorial/presentation/providers/tutorial_provider.dart';
import 'package:eva_mobile/features/tutorial/presentation/widgets/interactive_spotlight_overlay.dart';

/// Lightweight wrapper ensuring each tab maintains its state and scroll position across switches.
class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;

  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class MainShellScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  const MainShellScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  late int _currentIndex;
  bool _isNavBarVisible = true;
  bool _isPageAnimating = false;
  late final PageController _pageController;

  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();
  final GlobalKey<AiDiaryScreenState> _diaryKey = GlobalKey<AiDiaryScreenState>();
  final GlobalKey<MonitoringScreenState> _monitoringKey = GlobalKey<MonitoringScreenState>();
  final GlobalKey<CareScreenState> _careKey = GlobalKey<CareScreenState>();

  final GlobalKey _centerButtonKey = GlobalKey(debugLabel: 'centerButton');
  final GlobalKey _firstJournalCardKey = GlobalKey(debugLabel: 'firstJournalCard');
  final GlobalKey _monitoringDassCardKey = GlobalKey(debugLabel: 'monitoringDassCard');
  final GlobalKey _firstPsychologistCardKey = GlobalKey(debugLabel: 'firstPsychologistCard');
  final GlobalKey _journalTabKey = GlobalKey(debugLabel: 'journalTab');
  final GlobalKey _trenTabKey = GlobalKey(debugLabel: 'trenTab');
  final GlobalKey _careTabKey = GlobalKey(debugLabel: 'careTab');

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 3);
    _pageController = PageController(initialPage: _currentIndex);
    _pages = [
      _KeepAliveWrapper(
        child: HomeScreen(
          key: _homeKey,
          onNavigateTab: _onTabTapped,
        ),
      ),
      _KeepAliveWrapper(
        child: AiDiaryScreen(
          key: _diaryKey,
          firstCardKey: _firstJournalCardKey,
        ),
      ),
      _KeepAliveWrapper(
        child: MonitoringScreen(
          key: _monitoringKey,
          dassCardKey: _monitoringDassCardKey,
        ),
      ),
      _KeepAliveWrapper(
        child: CareScreen(
          key: _careKey,
          firstPsychologistCardKey: _firstPsychologistCardKey,
        ),
      ),
    ];

    if (widget.initialIndex == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(tutorialNotifierProvider.notifier).ensureActiveOnLaunch();
      });
    } else if (widget.initialIndex == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final tutorialState = ref.read(tutorialNotifierProvider);
        if (!tutorialState.isCompleted &&
            tutorialState.currentStep == TutorialStep.journal) {
          ref
              .read(tutorialNotifierProvider.notifier)
              .resumeAtStep(TutorialStep.journal);
        }
      });
    }
  }

  GlobalKey? _getTargetKeyForStep(TutorialStep step) {
    switch (step) {
      case TutorialStep.voiceSession:
        return _centerButtonKey;
      case TutorialStep.voiceCoins:
      case TutorialStep.voiceStart:
      case TutorialStep.voiceCompleted:
      case TutorialStep.dassDetail:
      case TutorialStep.dassItem:
        return null;
      case TutorialStep.journal:
        return _firstJournalCardKey;
      case TutorialStep.analytics:
        return _monitoringDassCardKey;
      case TutorialStep.care:
        return _firstPsychologistCardKey;
    }
  }

  void _handleCenterButtonTap() {
    final tutorialState = ref.read(tutorialNotifierProvider);
    if (tutorialState.isActive &&
        tutorialState.currentStep == TutorialStep.voiceSession) {
      ref
          .read(tutorialNotifierProvider.notifier)
          .onTargetTapped(TutorialStep.voiceSession);
    }
    Navigator.pushNamed(context, '/chat');
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) {
      // Tapping same tab = refresh
      _triggerRefresh(index);
      return;
    }

    setState(() {
      _currentIndex = index;
      _isNavBarVisible = true;
      _isPageAnimating = true;
    });

    _pageController
        .animateToPage(
          index,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        )
        .then((_) {
          if (mounted) {
            setState(() {
              _isPageAnimating = false;
            });
            _triggerRefresh(index);
          }
        });
  }

  void _triggerRefresh(int index) {
    switch (index) {
      case 0:
        _homeKey.currentState?.refresh();
        break;
      case 1:
        _diaryKey.currentState?.refresh();
        break;
      case 2:
        _monitoringKey.currentState?.refresh();
        break;
      case 3:
        break;
      default:
        break;
    }
  }

  Future<bool> _showExitConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Empathetic Icon Circle
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.nightlight_round,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 18),

                // Title
                Text(
                  'Keluar dari EVA?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),

                // Friendly, Reassuring Message
                Text(
                  'Apakah kamu yakin ingin menutup aplikasi? Seluruh sesi dialog, catatan refleksi, dan progres perawatan dirimu hari ini telah tersimpan dengan aman.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),

                // Warm Reassurance Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Text('🌿', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'EVA selalu siap menemanimu kapan pun kamu ingin kembali bercerita.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF475569),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Action Buttons
                Row(
                  children: [
                    // Keluar Button
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE11D48),
                          side: const BorderSide(color: Color(0xFFFECDD3)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(
                          'Keluar',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Tetap di Sini Button
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          'Tetap di Sini',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return result ?? false;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tutorialState = ref.watch(tutorialNotifierProvider);

    ref.listen<TutorialState>(tutorialNotifierProvider, (previous, next) {
      if (next.isActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (next.currentStep == TutorialStep.journal && _currentIndex != 1) {
            _onTabTapped(1);
          } else if (next.currentStep == TutorialStep.analytics && _currentIndex != 2) {
            _onTabTapped(2);
          } else if (next.currentStep == TutorialStep.care && _currentIndex != 3) {
            _onTabTapped(3);
          }
        });
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_currentIndex != 0) {
          _onTabTapped(0);
          return;
        }
        final shouldExit = await _showExitConfirmationDialog();
        if (shouldExit) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: NotificationListener<UserScrollNotification>(
                  onNotification: (notification) {
                    if (notification.direction == ScrollDirection.reverse &&
                        _isNavBarVisible &&
                        !tutorialState.isActive) {
                      setState(() {
                        _isNavBarVisible = false;
                      });
                    } else if (notification.direction == ScrollDirection.forward &&
                        !_isNavBarVisible) {
                      setState(() {
                        _isNavBarVisible = true;
                      });
                    }
                    return true;
                  },
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _pages,
                  ),
                ),
              ),
            ),

            // Animated Floating Navigation Bar (Slides down when scrolling down, slides up on scroll up)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: AnimatedSlide(
                    offset: _isNavBarVisible ? Offset.zero : const Offset(0, 2.0),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: FloatingNavBar(
                      currentIndex: _currentIndex,
                      onTap: _onTabTapped,
                      onCenterTap: _handleCenterButtonTap,
                      centerButtonKey: _centerButtonKey,
                      journalTabKey: _journalTabKey,
                      trenTabKey: _trenTabKey,
                      careTabKey: _careTabKey,
                    ),
                  ),
                ),
              ),
            ),

            // Branded Guidance Card + Interactive Spotlight Overlay
            if (tutorialState.isActive &&
                tutorialState.currentStep != null &&
                !_isPageAnimating &&
                _getTargetKeyForStep(tutorialState.currentStep!) != null)
              InteractiveSpotlightOverlay(
                key: ValueKey(tutorialState.currentStep),
                targetKey: _getTargetKeyForStep(tutorialState.currentStep!),
                secondaryTargetKey: tutorialState.currentStep == TutorialStep.care
                    ? _careTabKey
                    : null,
                content: TutorialContent.stepContents[tutorialState.currentStep!]!,
                onSkip: () =>
                    ref.read(tutorialNotifierProvider.notifier).skipTutorial(),
                onNext: () {
                  final current = tutorialState.currentStep;
                  if (current == TutorialStep.voiceSession) {
                    _handleCenterButtonTap();
                    return;
                  }
                  if (current == TutorialStep.journal) {
                    ref
                        .read(tutorialNotifierProvider.notifier)
                        .onTargetTapped(TutorialStep.journal);
                    return;
                  }
                  if (current == TutorialStep.analytics) {
                    ref
                        .read(tutorialNotifierProvider.notifier)
                        .onTargetTapped(TutorialStep.analytics);
                    Navigator.pushNamed(context, '/dass_assessment').then((_) {
                      final tut = ref.read(tutorialNotifierProvider);
                      if (!tut.isCompleted && tut.currentStep == TutorialStep.care) {
                        _onTabTapped(3);
                      }
                    });
                    return;
                  }
                  if (current == TutorialStep.care) {
                    ref
                        .read(tutorialNotifierProvider.notifier)
                        .onTargetTapped(TutorialStep.care);
                    return;
                  }
                  ref.read(tutorialNotifierProvider.notifier).nextStep();
                },
                onTargetTap: () {
                  final current = tutorialState.currentStep;
                  if (current == TutorialStep.voiceSession) {
                    _handleCenterButtonTap();
                    return;
                  }
                  if (current == TutorialStep.journal) {
                    ref
                        .read(tutorialNotifierProvider.notifier)
                        .onTargetTapped(TutorialStep.journal);
                    return;
                  }
                  if (current == TutorialStep.analytics) {
                    ref
                        .read(tutorialNotifierProvider.notifier)
                        .onTargetTapped(TutorialStep.analytics);
                    Navigator.pushNamed(context, '/dass_assessment').then((_) {
                      final tut = ref.read(tutorialNotifierProvider);
                      if (!tut.isCompleted && tut.currentStep == TutorialStep.care) {
                        _onTabTapped(3);
                      }
                    });
                    return;
                  }
                  if (current == TutorialStep.care) {
                    ref
                        .read(tutorialNotifierProvider.notifier)
                        .onTargetTapped(TutorialStep.care);
                    return;
                  }
                  ref.read(tutorialNotifierProvider.notifier).nextStep();
                },
              ),
          ],
        ),
      ),
    );
  }
}

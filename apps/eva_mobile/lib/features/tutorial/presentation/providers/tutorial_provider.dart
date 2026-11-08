import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/tutorial_repository_impl.dart';
import '../../domain/entities/tutorial_step.dart';
import '../../domain/repositories/tutorial_repository.dart';

final tutorialRepositoryProvider = Provider<TutorialRepository>((ref) {
  return TutorialRepositoryImpl();
});

class TutorialState {
  final bool isInitialized;
  final bool isActive;
  final bool isCompleted;
  final TutorialStep? currentStep;

  const TutorialState({
    this.isInitialized = false,
    this.isActive = false,
    this.isCompleted = false,
    this.currentStep,
  });

  TutorialState copyWith({
    bool? isInitialized,
    bool? isActive,
    bool? isCompleted,
    TutorialStep? currentStep,
    bool clearStep = false,
  }) {
    return TutorialState(
      isInitialized: isInitialized ?? this.isInitialized,
      isActive: isActive ?? this.isActive,
      isCompleted: isCompleted ?? this.isCompleted,
      currentStep: clearStep ? null : (currentStep ?? this.currentStep),
    );
  }
}

class TutorialNotifier extends StateNotifier<TutorialState> {
  final TutorialRepository _repository;

  TutorialNotifier(this._repository) : super(const TutorialState()) {
    checkInitialStatus();
  }

  /// Always ensures the recommendation/tutorial guidance is active on app open or restart
  Future<void> checkInitialStatus() async {
    state = const TutorialState(
      isInitialized: true,
      isCompleted: false,
      isActive: true,
      currentStep: TutorialStep.voiceSession,
    );
  }

  /// Explicitly triggers recommendation/tutorial on screen initialization/restart
  void ensureActiveOnLaunch() {
    state = const TutorialState(
      isInitialized: true,
      isCompleted: false,
      isActive: true,
      currentStep: TutorialStep.voiceSession,
    );
  }

  Future<void> startTutorial() async {
    state = state.copyWith(
      isActive: true,
      isCompleted: false,
      currentStep: TutorialStep.voiceSession,
    );
  }

  void nextStep() {
    if (state.currentStep == null) return;

    final steps = TutorialStep.values;
    final currentIndex = steps.indexOf(state.currentStep!);

    if (currentIndex + 1 < steps.length) {
      state = state.copyWith(
        currentStep: steps[currentIndex + 1],
      );
    } else {
      completeTutorial();
    }
  }

  Future<void> onTargetTapped(TutorialStep step) async {
    if (state.currentStep == step) {
      if (step == TutorialStep.voiceSession) {
        // Center button tapped -> navigate to /chat and highlight coin balance
        state = state.copyWith(
          isActive: true,
          currentStep: TutorialStep.voiceCoins,
        );
      } else if (step == TutorialStep.voiceCoins) {
        // Coin explanation acknowledged -> highlight Mulai Sesi Suara button
        state = state.copyWith(
          isActive: true,
          currentStep: TutorialStep.voiceStart,
        );
      } else if (step == TutorialStep.voiceStart) {
        // Voice call initiated -> pause spotlight overlay during active call
        state = state.copyWith(
          isActive: false,
          currentStep: TutorialStep.voiceCompleted,
        );
      } else if (step == TutorialStep.voiceCompleted) {
        // User tapped Lihat Detail Jurnal Refleksi -> proceed to journal tab
        state = state.copyWith(
          isActive: true,
          currentStep: TutorialStep.journal,
        );
      } else if (step == TutorialStep.journal) {
        state = state.copyWith(
          isActive: true,
          currentStep: TutorialStep.analytics,
        );
      } else if (step == TutorialStep.analytics) {
        state = state.copyWith(
          isActive: true,
          currentStep: TutorialStep.dassDetail,
        );
      } else if (step == TutorialStep.dassDetail) {
        state = state.copyWith(
          isActive: true,
          currentStep: TutorialStep.dassItem,
        );
      } else if (step == TutorialStep.dassItem) {
        state = state.copyWith(
          isActive: true,
          currentStep: TutorialStep.care,
        );
      } else if (step == TutorialStep.care) {
        completeTutorial();
      } else {
        nextStep();
      }
    }
  }

  void resumeAtStep(TutorialStep step) {
    state = state.copyWith(
      isActive: true,
      currentStep: step,
    );
  }

  /// Skips tutorial for the current session. Will show again on app restart as requested.
  Future<void> skipTutorial() async {
    state = state.copyWith(
      isActive: false,
      isCompleted: true,
      clearStep: true,
    );
  }

  Future<void> completeTutorial() async {
    state = state.copyWith(
      isActive: false,
      isCompleted: true,
      clearStep: true,
    );
  }

  Future<void> resetTutorial() async {
    await _repository.resetTutorial();
    state = const TutorialState(
      isInitialized: true,
      isActive: true,
      isCompleted: false,
      currentStep: TutorialStep.voiceSession,
    );
  }
}

final tutorialNotifierProvider =
    StateNotifierProvider<TutorialNotifier, TutorialState>((ref) {
  final repository = ref.watch(tutorialRepositoryProvider);
  return TutorialNotifier(repository);
});

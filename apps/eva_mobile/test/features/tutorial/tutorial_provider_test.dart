import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eva_mobile/features/tutorial/domain/entities/tutorial_step.dart';
import 'package:eva_mobile/features/tutorial/domain/repositories/tutorial_repository.dart';
import 'package:eva_mobile/features/tutorial/presentation/providers/tutorial_provider.dart';

class _FakeTutorialRepository implements TutorialRepository {
  bool _completed = false;

  @override
  Future<bool> hasCompletedTutorial() async => _completed;

  @override
  Future<void> setTutorialCompleted(bool completed) async {
    _completed = completed;
  }

  @override
  Future<void> resetTutorial() async {
    _completed = false;
  }
}

void main() {
  group('TutorialNotifier', () {
    test('initializes and activates for new users', () async {
      final repo = _FakeTutorialRepository();
      final container = ProviderContainer(
        overrides: [
          tutorialRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      // Wait for checkInitialStatus
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final state = container.read(tutorialNotifierProvider);
      expect(state.isInitialized, isTrue);
      expect(state.isActive, isTrue);
      expect(state.currentStep, TutorialStep.voiceSession);
    });

    test('advances through steps until completed', () async {
      final repo = _FakeTutorialRepository();
      final container = ProviderContainer(
        overrides: [
          tutorialRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      final notifier = container.read(tutorialNotifierProvider.notifier);

      // Voice session target tapped -> sets step to journal, pauses overlay for call
      await notifier.onTargetTapped(TutorialStep.voiceSession);
      expect(container.read(tutorialNotifierProvider).currentStep,
          TutorialStep.journal);
      expect(container.read(tutorialNotifierProvider).isActive, isFalse);

      // Resume at journal
      notifier.resumeAtStep(TutorialStep.journal);
      expect(container.read(tutorialNotifierProvider).isActive, isTrue);

      // Next step -> analytics
      notifier.nextStep();
      expect(container.read(tutorialNotifierProvider).currentStep,
          TutorialStep.analytics);

      // Next step -> care
      notifier.nextStep();
      expect(
          container.read(tutorialNotifierProvider).currentStep, TutorialStep.care);

      // Next step -> completed
      notifier.nextStep();
      expect(container.read(tutorialNotifierProvider).isCompleted, isTrue);
      expect(container.read(tutorialNotifierProvider).isActive, isFalse);
    });

    test('skipTutorial dismisses for current session, ensureActiveOnLaunch resets on launch', () async {
      final repo = _FakeTutorialRepository();
      final container = ProviderContainer(
        overrides: [
          tutorialRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      final notifier = container.read(tutorialNotifierProvider.notifier);

      await notifier.skipTutorial();
      expect(container.read(tutorialNotifierProvider).isCompleted, isTrue);
      expect(container.read(tutorialNotifierProvider).isActive, isFalse);

      // On app reopen or restart, ensureActiveOnLaunch displays recommendation again
      notifier.ensureActiveOnLaunch();
      expect(container.read(tutorialNotifierProvider).isActive, isTrue);
      expect(container.read(tutorialNotifierProvider).currentStep, TutorialStep.voiceSession);
    });
  });
}

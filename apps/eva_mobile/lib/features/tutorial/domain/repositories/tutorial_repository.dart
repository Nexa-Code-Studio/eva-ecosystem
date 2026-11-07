abstract class TutorialRepository {
  Future<bool> hasCompletedTutorial();
  Future<void> setTutorialCompleted(bool completed);
  Future<void> resetTutorial();
}

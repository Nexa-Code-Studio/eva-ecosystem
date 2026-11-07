import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/repositories/tutorial_repository.dart';

class TutorialRepositoryImpl implements TutorialRepository {
  static const String _keyCompleted = 'eva_tutorial_completed_v1';

  @override
  Future<bool> hasCompletedTutorial() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyCompleted) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> setTutorialCompleted(bool completed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyCompleted, completed);
    } catch (_) {}
  }

  @override
  Future<void> resetTutorial() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyCompleted);
    } catch (_) {}
  }
}

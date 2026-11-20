import 'package:shared_preferences/shared_preferences.dart';

class ScheduleStorage {
  static const String _keyConfigured = 'eva_counselor_schedule_configured_persistent';

  static Future<void> markConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyConfigured, true);
  }

  static Future<bool> isConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    // Defaults to true for established accounts (Dr. Sarah / Verified), false only if explicitly unconfigured
    return prefs.getBool(_keyConfigured) ?? true;
  }

  static Future<void> resetForNewRegistration() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyConfigured, false);
  }
}

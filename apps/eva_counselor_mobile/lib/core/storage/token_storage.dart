import 'package:shared_preferences/shared_preferences.dart';

/// Secure local storage helper for Psychologist JWT tokens and session data.
class TokenStorage {
  static const String _keyToken = 'eva_counselor_token';
  static const String _keyUserId = 'eva_counselor_user_id';
  static const String _keyCounselorProfile = 'eva_counselor_profile_json';

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, userId);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  static Future<void> saveProfileJson(String profileJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCounselorProfile, profileJson);
  }

  static Future<String?> getProfileJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCounselorProfile);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyCounselorProfile);
  }
}

import 'package:flutter/services.dart';

class ScreenSecurityHelper {
  static const MethodChannel _channel = MethodChannel('id.eva.counselor/security');

  /// Prevents screenshots, screen recording, and system task previews
  static Future<void> enableSecureScreen() async {
    try {
      await _channel.invokeMethod('enableSecure');
    } catch (_) {
      // Ignored on web/desktop/unsupported platforms or unit test harnesses
    }
  }

  /// Restores normal screen capture behavior
  static Future<void> disableSecureScreen() async {
    try {
      await _channel.invokeMethod('disableSecure');
    } catch (_) {
      // Ignored on web/desktop/unsupported platforms or unit test harnesses
    }
  }
}

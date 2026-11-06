class AppConfig {
  /// Toggle between Mock Data (offline/local development) and Live Backend API.
  /// Can be overridden at build time via:
  /// --dart-define=USE_MOCK_DATA=true / false
  static const bool useMockData = bool.fromEnvironment(
    'USE_MOCK_DATA',
    defaultValue: true,
  );

  /// Toggle local API endpoint (127.0.0.1:8888 or 10.0.2.2:8888 for Android emulator)
  static const bool useLocalApi = bool.fromEnvironment(
    'USE_LOCAL_API',
    defaultValue: false,
  );

  /// Custom host override (e.g. --dart-define=LOCAL_HOST=192.168.1.100:8888)
  static const String customLocalHost = String.fromEnvironment(
    'LOCAL_HOST',
    defaultValue: '',
  );

  /// Production server domain
  static const String defaultServerHost = 'eva.nexacode.dev';

  /// Local development hosts
  static const String localServerHost = '127.0.0.1:8888';
  static const String emulatorServerHost = '10.0.2.2:8888';

  /// Active host resolution
  static String get serverHost {
    if (customLocalHost.isNotEmpty) return customLocalHost;
    if (useLocalApi) return localServerHost;
    return defaultServerHost;
  }

  /// Whether the connection uses SSL (HTTPS / WSS)
  static bool get isSecure => !useLocalApi && customLocalHost.isEmpty;

  /// Base API URL for psychologist endpoints
  static String get apiBaseUrl {
    final scheme = isSecure ? 'https' : 'http';
    return '$scheme://$serverHost/api/v1/counselor';
  }

  /// Base WebSocket URL for real-time video signaling & chat
  static String get wsBaseUrl {
    final scheme = isSecure ? 'wss' : 'ws';
    return '$scheme://$serverHost/api/v1/counselor/ws';
  }

  /// Request timeout duration
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
}

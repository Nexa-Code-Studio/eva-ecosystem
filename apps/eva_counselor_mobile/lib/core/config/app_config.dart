class AppConfig {
  /// Toggle between Mock Data (offline/local development) and Live Backend API.
  /// Can be overridden at build time via:
  /// --dart-define=USE_MOCK_DATA=true / false
  /// Defaults to false for production live server connection.
  static bool useMockData = const bool.fromEnvironment(
    'USE_MOCK_DATA',
    defaultValue: false,
  );

  /// Toggle local API endpoint (127.0.0.1:8888 or 10.0.2.2:8888 for Android emulator)
  static const bool useLocalApi = bool.fromEnvironment(
    'USE_LOCAL_API',
    defaultValue: true,
  );

  /// Whether running on an Android emulator (uses 10.0.2.2 instead of 127.0.0.1)
  static const bool isEmulator = bool.fromEnvironment(
    'IS_EMULATOR',
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
    if (useLocalApi) {
      if (isEmulator) return emulatorServerHost;
      return localServerHost;
    }
    return defaultServerHost;
  }

  /// Whether the connection uses SSL (HTTPS / WSS)
  static bool get isSecure => !useLocalApi && customLocalHost.isEmpty;

  /// Base API URL for psychologist endpoints
  static String get apiBaseUrl {
    final scheme = isSecure ? 'https' : 'http';
    return '$scheme://$serverHost/api/v1';
  }

  /// Base WebSocket URL for real-time video signaling & consultation
  static String get wsCareBaseUrl {
    final scheme = isSecure ? 'wss' : 'ws';
    return '$scheme://$serverHost/api/v1/care/ws';
  }

  /// Base WebSocket URL (alias for wsCareBaseUrl)
  static String get wsBaseUrl => wsCareBaseUrl;

  /// Google OAuth 2.0 Client ID for Google Sign-In & Google Drive backup
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '541439650704-tufjmhlfh9qg1a54irmbgfb4pv2rpm2g.apps.googleusercontent.com',
  );

  /// Google Drive scopes for encrypted clinical backup
  static const List<String> googleDriveScopes = [
    'email',
    'https://www.googleapis.com/auth/drive.appdata',
    'https://www.googleapis.com/auth/drive.file',
  ];

  /// Request timeout duration
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
}

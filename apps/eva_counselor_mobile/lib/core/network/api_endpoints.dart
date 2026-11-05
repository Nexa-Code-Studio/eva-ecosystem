/// Centralized backend API route constants for Counselor Application.
class ApiEndpoints {
  // Auth & Profile
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String profile = '/auth/me';
  static const String updateProfile = '/auth/profile';
  static const String uploadCertificate = '/auth/upload-certificate';

  // Patients & Consent
  static const String patients = '/patients';
  static String patientDetail(String id) => '/patients/$id';
  static String patientEmotions(String id) => '/patients/$id/emotions';
  static String patientDassHistory(String id) => '/patients/$id/dass-history';
  static String patientDiaries(String id) => '/patients/$id/diaries';
  static String requestConsent(String id) => '/patients/$id/request-consent';
  static String clinicalNotes(String id) => '/patients/$id/clinical-notes';

  // Video Call & Teleconsultation
  static const String activeSessions = '/sessions';
  static String sessionDetail(String id) => '/sessions/$id';
  static String startSession(String id) => '/sessions/$id/start';
  static String endSession(String id) => '/sessions/$id/end';
  static String sessionSignaling(String id) => '/sessions/$id/signal';

  // Financials & Transactions
  static const String financialSummary = '/finances/summary';
  static const String transactions = '/finances/transactions';
  static const String requestPayout = '/finances/payout';

  // Availability / Schedule
  static const String availability = '/schedule/availability';
  static const String appointments = '/schedule/appointments';
}

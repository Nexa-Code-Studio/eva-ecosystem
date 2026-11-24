/// Centralized backend API route constants for Counselor Application.
class ApiEndpoints {
  // Auth & Profile
  static const String login = '/auth/login';
  static const String register = '/counselors/register';
  static const String profile = '/counselors/me';
  static const String updateProfile = '/counselors/me';
  static const String uploadCertificate = '/counselors/me/resubmit-verification';
  static const String availability = '/counselors/me/availability';
  static const String bankDetails = '/counselors/me/bank-details';
  static const String scheduleConfig = '/counselors/me/schedule-config';
  static String counselorTimeline(String id, String date) =>
      '/counselors/$id/timeline?date=$date';
  static String patientTriggers(String id) => '/patients/$id/clinical-triggers';

  // Pricing & Leveling
  static const String pricing = '/pricing/active';
  static const String calculatePricing = '/pricing/calculate';
  static const String levelMetrics = '/counselors/me/level-metrics';
  static const String updatePricing = '/counselors/me/pricing';
  static const String myReviews = '/counselors/me/reviews';
  static String counselorReviews(String id) => '/counselors/$id/reviews';

  // Patients & Consent
  static const String patients = '/patients';
  static String patientDetail(String id) => '/patients/$id';
  static String patientEmotions(String id) => '/patients/$id/emotions';
  static String patientDassHistory(String id) => '/patients/$id/dass-history';
  static String patientDiaries(String id) => '/patients/$id/diaries';
  static String requestConsent(String id) => '/patients/$id/request-consent';
  static String clinicalNotes(String id) => '/patients/$id/clinical-notes';
  static String patientConsent(String patientId, String counselorId) =>
      '/patients/$patientId/consent/$counselorId';

  // Video Call & Teleconsultation Sessions
  static const String activeSessions = '/sessions';
  static String sessionDetail(String id) => '/sessions/$id';
  static String videoToken(String id) => '/care/sessions/$id/video-token';
  static String careWebSocket(String id, String token) => '/care/ws/$id?token=$token';
  static String updateCallStatus(String id) => '/care/sessions/$id/status';
  static String sessionExtensionAvailability(String id) =>
      '/sessions/$id/extension-availability';
  static String extendSession(String id) => '/sessions/$id/extend';
  static String soapNotes(String id) => '/sessions/$id/soap-notes';
  static String soapSynthesis(String id) => '/sessions/$id/synthesize-soap';
  static String startSession(String id) => '/sessions/$id/start';
  static String endSession(String id) => '/sessions/$id/end';
  static String sessionSignaling(String id) => '/sessions/$id/signal';

  // Financials & Transactions
  static const String financialSummary = '/finances/summary';
  static const String transactions = '/finances/transactions';
  static const String requestPayout = '/finances/payout';

  // Availability / Schedule
  static const String appointments = '/schedule/appointments';
}

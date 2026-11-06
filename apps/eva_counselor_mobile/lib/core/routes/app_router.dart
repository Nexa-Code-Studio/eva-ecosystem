import 'package:flutter/material.dart';
import '../../features/auth/presentation/screens/psychologist_login_screen.dart';
import '../../features/auth/presentation/screens/psychologist_registration_screen.dart';
import '../../features/dashboard/presentation/screens/counselor_main_shell_screen.dart';
import '../../features/patients/presentation/screens/patient_detail_consent_screen.dart';
import '../../features/patients/presentation/screens/patient_list_screen.dart';
import '../../features/video_call/presentation/screens/video_consultation_screen.dart';
import '../../features/finances/presentation/screens/transaction_history_screen.dart';
import '../../features/dashboard/presentation/screens/counselor_notification_screen.dart';
import 'app_route_transitions.dart';

class AppRouter {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
      case '/counselor-login':
        return FadeThroughPageRoute(
          page: const PsychologistLoginScreen(),
          settings: settings,
        );

      case '/counselor-register':
        return FadeThroughPageRoute(
          page: const PsychologistRegistrationScreen(),
          settings: settings,
        );

      case '/counselor-shell':
        return FadeThroughPageRoute(
          page: const CounselorMainShellScreen(),
          settings: settings,
        );

      case '/counselor-notifications':
        return FadeThroughPageRoute(
          page: const CounselorNotificationScreen(),
          settings: settings,
        );

      case '/counselor-patients':
        return FadeThroughPageRoute(
          page: const PatientListScreen(),
          settings: settings,
        );

      case '/counselor-patient-detail':
        final patientId = settings.arguments as String? ?? 'patient-001';
        return FadeThroughPageRoute(
          page: PatientDetailConsentScreen(patientId: patientId),
          settings: settings,
        );

      case '/counselor-video-call':
        final sessionId = settings.arguments as String? ?? 'session-live-001';
        return FadeThroughPageRoute(
          page: VideoConsultationScreen(sessionId: sessionId),
          settings: settings,
        );

      case '/counselor-finances':
        return FadeThroughPageRoute(
          page: const TransactionHistoryScreen(),
          settings: settings,
        );

      default:
        return FadeThroughPageRoute(
          page: const PsychologistLoginScreen(),
          settings: settings,
        );
    }
  }
}

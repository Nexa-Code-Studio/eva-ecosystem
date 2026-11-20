import 'package:flutter/material.dart';
import '../../features/auth/presentation/screens/psychologist_login_screen.dart';
import '../../features/auth/presentation/screens/psychologist_registration_screen.dart';
import '../../features/auth/presentation/screens/verification_pending_screen.dart';
import '../../features/auth/presentation/screens/verification_rejected_screen.dart';
import '../../features/dashboard/presentation/screens/counselor_main_shell_screen.dart';
import '../../features/patients/presentation/screens/patient_detail_consent_screen.dart';
import '../../features/patients/presentation/screens/patient_list_screen.dart';
import '../../features/video_call/presentation/screens/video_consultation_screen.dart';
import '../../features/finances/presentation/screens/transaction_history_screen.dart';
import '../../features/dashboard/presentation/screens/counselor_notification_screen.dart';
import '../../features/profile/presentation/screens/counselor_schedule_settings_screen.dart';
import '../../features/dashboard/presentation/screens/counselor_full_schedule_screen.dart';
import 'app_route_transitions.dart';

class AppRouter {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final uri = Uri.parse(settings.name ?? '/');
    switch (uri.path) {
      case '/':
      case '/counselor-login':
        return FadeThroughPageRoute(
          page: const PsychologistLoginScreen(),
          settings: settings,
        );

      case '/counselor-verification-pending':
        return FadeThroughPageRoute(
          page: const VerificationPendingScreen(),
          settings: settings,
        );

      case '/counselor-verification-rejected':
        return FadeThroughPageRoute(
          page: const VerificationRejectedScreen(),
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
        String patientId = 'patient-001';
        bool initialSessionUnlocked = false;
        String? activeSessionId;
        if (settings.arguments is String) {
          patientId = settings.arguments as String;
        } else if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          patientId = args['patientId'] as String? ?? 'patient-001';
          initialSessionUnlocked = args['sessionFinished'] as bool? ?? false;
          activeSessionId = args['sessionId'] as String?;
        }
        return FadeThroughPageRoute(
          page: PatientDetailConsentScreen(
            patientId: patientId,
            initialSessionUnlocked: initialSessionUnlocked,
            activeSessionId: activeSessionId,
          ),
          settings: settings,
        );

      case '/counselor-video-call':
        if (settings.arguments is Map<String, dynamic>) {
          final args = settings.arguments as Map<String, dynamic>;
          final sessionId = args['sessionId'] as String? ?? 'session-live-001';
          final patientName = args['patientName'] as String?;
          final scheduledTime = args['scheduledTime'] as String?;
          final isLiveNow = args['isLiveNow'] as bool? ?? true;
          return FadeThroughPageRoute(
            page: VideoConsultationScreen(
              sessionId: sessionId,
              patientName: patientName,
              scheduledTime: scheduledTime,
              isEarlyEntry: !isLiveNow,
            ),
            settings: settings,
          );
        }
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

      case '/counselor-schedule-settings':
        return FadeThroughPageRoute(
          page: const CounselorScheduleSettingsScreen(),
          settings: settings,
        );

      case '/counselor-full-schedule':
        return FadeThroughPageRoute(
          page: const CounselorFullScheduleScreen(),
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

import 'package:flutter/material.dart';
import '../../features/auth/presentation/screens/partner_counselor_activation_screen.dart';
import '../../features/auth/presentation/screens/psychologist_login_screen.dart';
import '../../features/auth/presentation/screens/psychologist_registration_screen.dart';
import '../../features/dashboard/presentation/screens/counselor_main_shell_screen.dart';
import '../../features/patients/presentation/screens/patient_detail_consent_screen.dart';
import '../../features/patients/presentation/screens/patient_list_screen.dart';
import '../../features/video_call/presentation/screens/video_consultation_screen.dart';
import '../../features/finances/presentation/screens/transaction_history_screen.dart';
import '../../features/dashboard/presentation/screens/counselor_notification_screen.dart';
import '../../features/profile/presentation/screens/counselor_schedule_settings_screen.dart';
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

      case '/counselor-activation':
        final args = settings.arguments as Map<String, dynamic>?;
        final token = args?['token'] as String? ?? uri.queryParameters['token'];
        final email = args?['email'] as String? ?? uri.queryParameters['email'];
        final partnerName =
            args?['partnerName'] as String? ?? uri.queryParameters['partner'];
        final fullName =
            args?['fullName'] as String? ?? uri.queryParameters['name'];
        return FadeThroughPageRoute(
          page: PartnerCounselorActivationScreen(
            invitationToken: token,
            prefilledEmail: email,
            partnerName: partnerName,
            fullName: fullName,
          ),
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

      default:
        return FadeThroughPageRoute(
          page: const PsychologistLoginScreen(),
          settings: settings,
        );
    }
  }
}

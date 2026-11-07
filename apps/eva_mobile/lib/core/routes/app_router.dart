import 'package:flutter/material.dart';

import 'package:eva_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:eva_mobile/features/auth/presentation/screens/register_screen.dart';
import 'package:eva_mobile/features/auth/presentation/screens/profile_screen.dart';
import 'package:eva_mobile/features/auth/presentation/screens/settings_screen.dart';
import 'package:eva_mobile/features/auth/presentation/screens/terms_disclaimer_screen.dart';
import 'package:eva_mobile/features/auth/presentation/screens/splash_onboarding_screen.dart';
import 'package:eva_mobile/features/chat/presentation/screens/ai_conversation_screen.dart';
import 'package:eva_mobile/features/dass/presentation/screens/dass_assessment_screen.dart';
import 'package:eva_mobile/features/diary/presentation/screens/ai_diary_screen.dart';
import 'package:eva_mobile/features/diary/presentation/screens/ai_diary_detail_screen.dart';
import 'package:eva_mobile/features/emergency/presentation/screens/emergency_contacts_screen.dart';
import 'package:eva_mobile/features/emergency/presentation/screens/support_emergency_screen.dart';
import 'package:eva_mobile/features/home/presentation/screens/main_shell_screen.dart';
import 'package:eva_mobile/features/monitoring/presentation/screens/monitoring_screen.dart';
import 'package:eva_mobile/features/care/presentation/screens/care_screen.dart';
import 'package:eva_mobile/features/recommendations/presentation/screens/recommendation_screen.dart';
import 'package:eva_mobile/features/voice_call/presentation/screens/voice_call_screen.dart';
import 'package:eva_mobile/features/voice_call/presentation/screens/voice_session_detail_screen.dart';
import 'app_route_transitions.dart';

/// Centralized route generator applying custom transitions to all Eva Mobile pages.
class AppRouter {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final name = settings.name;
    final args = settings.arguments as Map<String, dynamic>?;

    switch (name) {
      // 1. Root Context & Auth Shift (fadeThroughRoute)
      case '/':
        return AppRouteTransitions.fadeThroughRoute(
          page: const SplashOnboardingScreen(),
          settings: settings,
        );
      case '/login':
        return AppRouteTransitions.fadeThroughRoute(
          page: const LoginScreen(),
          settings: settings,
        );
      case '/register':
        return AppRouteTransitions.fadeThroughRoute(
          page: const RegisterScreen(),
          settings: settings,
        );
      case '/home':
        final initialIndex = (args?['initialIndex'] as int?) ?? 0;
        return AppRouteTransitions.fadeThroughRoute(
          page: MainShellScreen(initialIndex: initialIndex),
          settings: settings,
        );
      case '/diary':
        return AppRouteTransitions.fadeThroughRoute(
          page: const AiDiaryScreen(),
          settings: settings,
        );
      case '/monitoring':
        return AppRouteTransitions.fadeThroughRoute(
          page: const MonitoringScreen(),
          settings: settings,
        );
      case '/care':
        return AppRouteTransitions.fadeThroughRoute(
          page: const CareScreen(),
          settings: settings,
        );
      case '/user_profile':
      case '/profile':
        return AppRouteTransitions.horizontalDetailRoute(
          page: const ProfileScreen(),
          settings: settings,
        );

      // 2. Modal / Immersive Experience (modalSlideUpRoute)
      case '/chat':
        return AppRouteTransitions.modalSlideUpRoute(
          page: const AiConversationScreen(),
          settings: settings,
        );
      case '/voice_call':
      case '/call':
        return AppRouteTransitions.modalSlideUpRoute(
          page: const VoiceCallScreen(),
          settings: settings,
        );
      case '/support':
      case '/support_emergency':
        return AppRouteTransitions.modalSlideUpRoute(
          page: const SupportEmergencyScreen(),
          settings: settings,
        );
      case '/dass_assessment':
      case '/dass':
        final initialPeriod = (args?['period'] as String?) ?? 'today';
        return AppRouteTransitions.modalSlideUpRoute(
          page: DASSAssessmentScreen(initialPeriod: initialPeriod),
          settings: settings,
        );

      // 3. Hierarchical Forward/Back (horizontalDetailRoute)
      case '/diary_detail':
        return AppRouteTransitions.horizontalDetailRoute(
          page: AiDiaryDetailScreen(journalData: args),
          settings: settings,
        );
      case '/voice_session_detail':
        return AppRouteTransitions.horizontalDetailRoute(
          page: VoiceSessionDetailScreen(sessionData: args),
          settings: settings,
        );
      case '/emergency_contacts':
        return AppRouteTransitions.horizontalDetailRoute(
          page: const EmergencyContactsScreen(),
          settings: settings,
        );
      case '/settings':
        return AppRouteTransitions.horizontalDetailRoute(
          page: const SettingsScreen(),
          settings: settings,
        );
      case '/recommendation':
        return AppRouteTransitions.horizontalDetailRoute(
          page: const RecommendationScreen(),
          settings: settings,
        );
      case '/terms_disclaimer':
        return AppRouteTransitions.horizontalDetailRoute(
          page: const TermsDisclaimerScreen(),
          settings: settings,
        );

      default:
        return null;
    }
  }
}

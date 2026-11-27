import 'package:flutter/material.dart';

/// Semantic color tokens derived from docs/DESIGN.md (Eva / LUNA Mental Health).
class AppColors {
  // Core brand triad: Periwinkle, Lavender, Sky Blue
  static const Color primary = Color(0xFF5358CB); // Periwinkle Primary (5.79:1 on white)
  static const Color primaryLight = Color(0xFF8B93FF); // Highlight accent only
  static const Color primaryContainer = Color(0xFFE8E9FF); // Soft Primary Container
  static const Color onPrimaryContainer = Color(0xFF1D238F); // 10.38:1 on primaryContainer

  static const Color secondary = Color(0xFFE2DAFF); // Lavender Secondary
  static const Color secondaryDark = Color(0xFF605A79); // 6.49:1 on white

  static const Color tertiary = Color(0xFFA7E6FF); // Sky Blue Tertiary
  static const Color tertiaryContainer = Color(0xFFE0F4FB);
  static const Color tertiaryDark = Color(0xFF003948); // 11.02:1 on tertiaryContainer

  // Surfaces & neutrals
  static const Color background = Color(0xFFF8F9FE); // Cool Tint Off-White
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceLow = Color(0xFFF2F3F8);
  static const Color surfaceContainer = Color(0xFFECEEF3);
  static const Color surfaceHigh = Color(0xFFE7E8ED);

  // Accessible text hierarchy (WCAG AA verified)
  static const Color textPrimary = Color(0xFF191C1F); // 17.0:1 on white
  static const Color textSecondary = Color(0xFF464652); // 9.30:1 on white, 8.84:1 on background
  static const Color textLight = Color(0xFF605A79); // 6.49:1 on white, 6.17:1 on background

  // Borders, glass & dividers
  static const Color glassBackground = Color(0xCCFFFFFF); // 80% opacity white
  static const Color glassBorder = Color(0x66FFFFFF); // 40% opacity white
  static const Color glassShadow = Color(0x145358CB); // 8% periwinkle shadow
  static const Color borderSubtle = Color(0xFFC6C5D5); // outline-variant
  static const Color borderSoft = Color(0xFFE0E2F2);
  static const Color divider = Color(0x145358CB); // Soft gentle periwinkle divider

  // Semantic feedback (WCAG AA verified)
  static const Color success = Color(0xFF2E7D32); // 5.13:1 with white text
  static const Color successContainer = Color(0xFFE8F5E9);
  static const Color successDark = Color(0xFF2E7D32);

  static const Color warning = Color(0xFFB45309); // 5.02:1 with white text
  static const Color warningContainer = Color(0xFFFFFBEB);
  static const Color warningDark = Color(0xFFB45309); // 4.84:1 on warningContainer

  static const Color error = Color(0xFFBA1A1A); // 6.46:1 with white text
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color errorDark = Color(0xFF93000A);
}

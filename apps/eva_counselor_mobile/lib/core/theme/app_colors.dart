import 'package:flutter/material.dart';

class AppColors {
  // Brand Palette (consistent with EVA Ecosystem)
  static const Color primary = Color(0xFF5358CB); // Periwinkle Primary
  static const Color primaryLight = Color(0xFF8B93FF); // Highlight Accent
  static const Color primaryContainer = Color(0xFFE8E9FF); // Soft Container

  static const Color secondary = Color(0xFFE2DAFF); // Lavender Secondary
  static const Color secondaryDark = Color(0xFF605A79); // Lavender Dark

  static const Color tertiary = Color(0xFFA7E6FF); // Sky Blue Tertiary
  static const Color tertiaryDark = Color(0xFF20667B); // Sky Blue Dark

  // Neutral Canvas
  static const Color background = Color(0xFFF8F9FE); // Cool Tint Off-White
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBg = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF191C1F);
  static const Color textSecondary = Color(0xFF767684);
  static const Color textLight = Color(0xFF9EA0AB);

  // Glass Effect Tokens
  static const Color glassBackground = Color(0xCCFFFFFF); // 80% opacity
  static const Color glassBorder = Color(0x66FFFFFF); // 40% opacity
  static const Color glassShadow = Color(0x145358CB); // 8% periwinkle shadow
  static const Color divider = Color(0x0E5358CB); // Soft divider

  // Clinical Status Badges
  static const Color verifiedGreen = Color(0xFF2E7D32);
  static const Color verifiedBg = Color(0xFFE8F5E9);
  static const Color pendingAmber = Color(0xFFED6C02);
  static const Color pendingBg = Color(0xFFFFF4E5);
  static const Color highRiskRed = Color(0xFFD32F2F);
  static const Color highRiskBg = Color(0xFFFFEBEE);

  // Functional
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFBA1A1A);
}

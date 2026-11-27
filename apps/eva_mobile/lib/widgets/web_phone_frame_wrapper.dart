import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Wraps the application inside a clean phone frame when viewed on
/// desktop/wide web browsers (width > 500px).
class WebPhoneFrameWrapper extends StatelessWidget {
  final Widget child;

  const WebPhoneFrameWrapper({
    super.key,
    required this.child,
  });

  static const double maxPhoneWidth = 420.0;
  static const double maxPhoneHeight = 900.0;
  static const double breakpointWidth = 500.0;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return child;
    }

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    if (screenWidth <= breakpointWidth) {
      return child;
    }

    final double phoneWidth = math.min(screenWidth - 48.0, maxPhoneWidth);
    final double phoneHeight = math.min(screenHeight - 56.0, maxPhoneHeight);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFEEF0FB),
              AppColors.background,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 20,
              left: 28,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.borderSoft),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.glassShadow,
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.phone_iphone_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Eva AI Mobile Preview',
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Center(
              child: Container(
                width: phoneWidth,
                height: phoneHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(44.0),
                  border: Border.all(
                    color: AppColors.textPrimary,
                    width: 9.0,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F191C1F),
                      blurRadius: 36,
                      spreadRadius: 0,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(35.0),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: MediaQuery(
                          data: mediaQuery.copyWith(
                            size: Size(phoneWidth, phoneHeight),
                            padding: const EdgeInsets.only(top: 28, bottom: 20),
                            viewPadding: const EdgeInsets.only(top: 28, bottom: 20),
                          ),
                          child: child,
                        ),
                      ),
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Container(
                            width: 92,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.textPrimary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Container(
                            width: 112,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.textSecondary.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:eva_mobile/core/routes/app_route_transitions.dart';
import 'package:eva_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:eva_mobile/features/emergency/presentation/widgets/breathing_exercise_modal.dart';
import 'package:eva_mobile/features/emergency/presentation/widgets/emergency_hotline_modal.dart';
import 'package:eva_mobile/theme/app_colors.dart';
import 'package:eva_mobile/widgets/app_snack_bar.dart';
import 'package:eva_mobile/widgets/staggered_entrance.dart';

class SupportEmergencyScreen extends ConsumerStatefulWidget {
  const SupportEmergencyScreen({super.key});

  /// Custom Route with smooth fade & gentle slide-up animation for enter and exit
  static Route<void> route() {
    return AppRouteTransitions.modalSlideUpRoute<void>(
      page: const SupportEmergencyScreen(),
    );
  }

  @override
  ConsumerState<SupportEmergencyScreen> createState() => _SupportEmergencyScreenState();
}

class _SupportEmergencyScreenState extends ConsumerState<SupportEmergencyScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  Map<String, dynamic>? _primaryContact;
  bool _isLoadingContact = true;

  static const String _dinkesWhatsappUrl =
      'https://api.whatsapp.com/send/?phone=6281380073120&text=halo%20kak%2C%20saya%20ingin%20bercerita%20mengenai...&type=phone_number&app_absent=0';

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _fetchPrimaryEmergencyContact();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(
      begin: 0.94,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchPrimaryEmergencyContact() async {
    try {
      final contacts = await ref.read(authRepositoryProvider).getEmergencyContacts();
      if (contacts.isNotEmpty && mounted) {
        final primary = contacts.firstWhere(
          (c) => c.isPrimary,
          orElse: () => contacts.first,
        );
        setState(() {
          _primaryContact = {
            'id': primary.id,
            'name': primary.name,
            'relationship': primary.relationship,
            'phone': primary.phone,
            'is_primary': primary.isPrimary,
          };
          _isLoadingContact = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isLoadingContact = false;
      });
    }
  }

  Future<void> _openDinkesHotline() async {
    final uri = Uri.parse(_dinkesWhatsappUrl);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {
        if (mounted) {
          AppSnackBar.showError(context, 'Tidak dapat membuka WhatsApp Dinkes');
        }
      }
    }
  }

  void _onTapHubungiOrangTerdekat() {
    if (_primaryContact != null && _primaryContact!['phone'] != null) {
      final phone = _primaryContact!['phone'].toString().replaceAll(RegExp(r'[^\d+]'), '');
      final uri = Uri.parse('tel:$phone');
      launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Navigator.pushNamed(context, '/emergency_contacts');
    }
  }

  void _openBreathingExercise() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const BreathingExerciseModal(),
    );
  }

  void _openHotlineModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const EmergencyHotlineModal(),
    );
  }

  void _handleDismiss() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final contactSubtitle = _isLoadingContact
        ? 'Memuat data kontak...'
        : (_primaryContact != null
            ? '${_primaryContact!['name']} (${_primaryContact!['relation']})'
            : 'Atur nomor kontak keluarga atau teman');

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleDismiss();
        }
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFFFF4F5),
                Color(0xFFFFE8EC),
                Color(0xFFFFF0F2),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                    children: [
                      const Spacer(flex: 1),

                      // Heart Badge Visual with Breathing Pulse Animation & Tap action                      // Animated Soft Emergency / Pulse Indicator
                      StaggeredEntrance(
                        index: 0,
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _openBreathingExercise,
                              child: AnimatedBuilder(
                                animation: _pulseScale,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: _pulseScale.value,
                                    child: child,
                                  );
                                },
                                child: Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFFFFE0E3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFE57373).withValues(alpha: 0.25),
                                        blurRadius: 30,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.favorite,
                                    color: Color(0xFFE57373),
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 22),

                            // Title & Subtitle
                            Text(
                              'Tarik napas dalam-dalam.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 10),

                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                "EVA menyadari bahwa kamu mungkin membutuhkan dukungan ekstra saat ini. Kamu tidak harus menghadapi ini sendirian.",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Quick breathing guide trigger button
                      StaggeredEntrance(
                        index: 1,
                        child: GestureDetector(
                          onTap: _openBreathingExercise,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFE57373).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.air,
                                  size: 16,
                                  color: Color(0xFFE57373),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Mulai Latihan Napas 4-7-8',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFE57373),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Action Pill Card 1: WhatsApp Krisis Dinkes DKI
                      StaggeredEntrance(
                        index: 2,
                        child: _buildSupportPillCard(
                          icon: Icons.support_agent_rounded,
                          iconBg: const Color(0xFFE8F8F5),
                          iconColor: const Color(0xFF00B894),
                          title: 'WhatsApp Krisis Dinkes DKI',
                          subtitle: 'Pendampingan Konseling Krisis Resmi',
                          onTap: _openDinkesHotline,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Action Pill Card 2: Hubungi Orang Terdekat
                      StaggeredEntrance(
                        index: 3,
                        child: _buildSupportPillCard(
                          icon: Icons.perm_contact_calendar_outlined,
                          iconBg: const Color(0xFFFFDCDD),
                          iconColor: const Color(0xFFE57373),
                          title: 'Hubungi Orang Terdekat',
                          subtitle: contactSubtitle,
                          onTap: _onTapHubungiOrangTerdekat,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Action Pill Card 3: Hotline Krisis & Bantuan Darurat
                      StaggeredEntrance(
                        index: 4,
                        child: _buildSupportPillCard(
                          icon: Icons.language,
                          iconBg: const Color(0xFFD7F3FF),
                          iconColor: const Color(0xFF00CEC9),
                          title: 'Hotline Krisis & Bantuan Darurat',
                          subtitle: 'SEJIWA 119, LISA, 112 Bebas Pulsa',
                          onTap: _openHotlineModal,
                        ),
                      ),
                      const Spacer(flex: 2),

                      // 'Saya merasa lebih baik sekarang' Bottom Button
                      StaggeredEntrance(
                        index: 5,
                        child: GestureDetector(
                          onTap: _handleDismiss,
                          child: Container(
                            width: double.infinity,
                            height: 54,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFFE57373).withValues(alpha: 0.4),
                                width: 1.2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                "Saya merasa lebih baik sekarang",
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
  }

  Widget _buildSupportPillCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconBg,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 15,
              color: AppColors.textLight,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

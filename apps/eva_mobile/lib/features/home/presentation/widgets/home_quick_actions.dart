import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_colors.dart';
import '../../../../widgets/glass_card.dart';

/// Shortcuts grid for core mental health features (Chat, Diary, DASS-21 Assessment).
class HomeQuickActions extends StatelessWidget {
  final VoidCallback onTapChat;
  final VoidCallback onTapDiary;
  final VoidCallback onTapDass;
  final String dassSubtitle;
  final bool showDassNotificationDot;

  const HomeQuickActions({
    super.key,
    required this.onTapChat,
    required this.onTapDiary,
    required this.onTapDass,
    required this.dassSubtitle,
    this.showDassNotificationDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildQuickCard(
          icon: Icons.chat_bubble_outline,
          iconBg: const Color(0xFF5358CB),
          iconColor: Colors.white,
          title: 'Curhat ke EVA',
          subtitle: 'Mulai dialog suara atau teks',
          onTap: onTapChat,
        ),
        const SizedBox(height: 12),
        _buildQuickCard(
          icon: Icons.menu_book_outlined,
          iconBg: const Color(0xFFE2DAFF),
          iconColor: const Color(0xFF5358CB),
          title: 'Jurnal Refleksi AI',
          subtitle: 'Lihat rangkuman emosi harimu',
          onTap: onTapDiary,
        ),
        const SizedBox(height: 12),
        _buildQuickCard(
          icon: Icons.psychology_outlined,
          iconBg: const Color(0xFFE0F4FB),
          iconColor: const Color(0xFF20667B),
          title: 'Asesmen DASS-21',
          subtitle: dassSubtitle,
          showNotificationDot: showDassNotificationDot,
          onTap: onTapDass,
        ),
      ],
    );
  }

  Widget _buildQuickCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    bool showNotificationDot = false,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      width: double.infinity,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (showNotificationDot) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF59E0B),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right,
            size: 20,
            color: AppColors.textLight,
          ),
        ],
      ),
    );
  }
}

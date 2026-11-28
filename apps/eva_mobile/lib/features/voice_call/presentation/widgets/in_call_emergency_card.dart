import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:eva_mobile/theme/app_colors.dart';

/// Bright, accessible in-call emergency support banner displayed during active AI calls
/// when crisis escalation is detected, allowing immediate access to help without ending the call.
class InCallEmergencyCard extends StatefulWidget {
  final String? hotlineSummary;
  final VoidCallback onOpenHotline;
  final VoidCallback onOpenBreathing;
  final VoidCallback onOpenDinkesWhatsapp;
  final VoidCallback onOpenEmergencyContact;

  const InCallEmergencyCard({
    super.key,
    this.hotlineSummary,
    required this.onOpenHotline,
    required this.onOpenBreathing,
    required this.onOpenDinkesWhatsapp,
    required this.onOpenEmergencyContact,
  });

  @override
  State<InCallEmergencyCard> createState() => _InCallEmergencyCardState();
}

class _InCallEmergencyCardState extends State<InCallEmergencyCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final summary = (widget.hotlineSummary != null && widget.hotlineSummary!.trim().isNotEmpty)
        ? widget.hotlineSummary!.trim()
        : 'Kemenkes 119 ext 8 / LISA 0811-3855-472';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFF1F2),
            Color(0xFFFFE4E6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFDA4AF),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFB7185).withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFFD6DB),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFE11D48),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dukungan Darurat Tersedia',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Panggilan EVA tetap berlanjut. Kamu tidak sendirian.',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF881337),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                tooltip: _isExpanded ? 'Ciutkan dukungan darurat' : 'Tampilkan dukungan darurat',
                onPressed: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                icon: Icon(
                  _isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (_isExpanded) ...[
            const SizedBox(height: 8),
            Text(
              summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _QuickActionChip(
                      width: itemWidth,
                      icon: Icons.support_agent_rounded,
                      label: 'Hotline 119 / LISA',
                      onTap: widget.onOpenHotline,
                    ),
                    _QuickActionChip(
                      width: itemWidth,
                      icon: Icons.air_rounded,
                      label: 'Latihan Napas',
                      onTap: widget.onOpenBreathing,
                    ),
                    _QuickActionChip(
                      width: itemWidth,
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'WA Dinkes DKI',
                      onTap: widget.onOpenDinkesWhatsapp,
                    ),
                    _QuickActionChip(
                      width: itemWidth,
                      icon: Icons.perm_contact_calendar_outlined,
                      label: 'Orang Terdekat',
                      onTap: widget.onOpenEmergencyContact,
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.width,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFFECDD3)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: const Color(0xFFE11D48)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

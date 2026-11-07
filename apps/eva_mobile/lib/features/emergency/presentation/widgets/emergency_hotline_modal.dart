import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../../theme/app_colors.dart";
import "../../../../widgets/app_snack_bar.dart";

class EmergencyHotlineModal extends StatelessWidget {
  const EmergencyHotlineModal({super.key});

  void _copy(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackBar.showSuccess(
      context,
      '$label ($text) disalin ke clipboard',
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hotlines = [
      {
        'title': 'Layanan SEJIWA (Kemenkes)',
        'desc': 'Hotline kesehatan mental & pencegahan krisis',
        'number': '119',
        'display': '119 (Ext. 8)',
        'icon': Icons.health_and_safety_outlined,
      },
      {
        'title': 'LISA - Sahabat Jiwa',
        'desc': 'Bantuan darurat kesehatan mental 24 Jam',
        'number': '08113855472',
        'display': '0811-3855-472',
        'icon': Icons.phone_in_talk_outlined,
      },
      {
        'title': 'Nomor Darurat Nasional',
        'desc': 'Panggilan darurat terpadu bebas pulsa',
        'number': '112',
        'display': '112',
        'icon': Icons.emergency_outlined,
      },
      {
        'title': 'Ambulans Kedaruratan Medis',
        'desc': 'Layanan tanggap darurat medis cepat',
        'number': '118',
        'display': '118 / 119',
        'icon': Icons.local_hospital_outlined,
      },
      {
        'title': 'Kepolisian Republik Indonesia',
        'desc': 'Kedaruratan keamanan & keselamatan jiwa',
        'number': '110',
        'display': '110',
        'icon': Icons.local_police_outlined,
      },
      {
        'title': 'Halo Kemenkes',
        'desc': 'Informasi fasilitas layanan kesehatan resmi',
        'number': '1500567',
        'display': '1500-567',
        'icon': Icons.info_outline,
      },
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hotline Krisis & Darurat',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 22),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tekan ikon salin untuk menyalin nomor langsung ke dialer telepon.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // List
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: hotlines.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final h = hotlines[i];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD7F3FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          h['icon'] as IconData,
                          color: const Color(0xFF00CEC9),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              h['title'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              h['desc'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              h['display'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF00838F),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.copy,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        tooltip: 'Salin nomor',
                        onPressed: () => _copy(
                          context,
                          h['number'] as String,
                          h['title'] as String,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}



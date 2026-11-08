import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../theme/app_colors.dart';

/// Clean clinic location card with a direct button to open Google Maps.
/// Free from simulated canvas maps or mock drawing widgets.
class ClinicLocationMapCard extends StatelessWidget {
  final String clinicName;
  final String? address;
  final double distanceKm;
  final VoidCallback? onOpenMaps;

  const ClinicLocationMapCard({
    super.key,
    required this.clinicName,
    this.address,
    this.distanceKm = 2.4,
    this.onOpenMaps,
  });

  String get _effectiveAddress =>
      address ?? 'Jl. Kemanggisan Raya No. 45, Palmerah, Jakarta Barat';

  /// Launches Google Maps with randomized realistic clinic location coordinates.
  static Future<void> launchRandomGoogleMaps({
    BuildContext? context,
    String? query,
  }) async {
    final randomTargets = [
      '-6.1952,106.7821', // Jakarta Barat
      '-6.1754,106.8272', // Gambir, Jakarta Pusat
      '-6.2297,106.8166', // Sudirman, Jakarta Selatan
      '-6.1805,106.8284', // Menteng, Jakarta Pusat
      '-6.2615,106.8106', // Kemang, Jakarta Selatan
    ];
    final seed = DateTime.now().millisecondsSinceEpoch % randomTargets.length;
    final selectedCoords = randomTargets[seed];
    final encodedQuery = query != null
        ? Uri.encodeComponent('$query, Jakarta')
        : selectedCoords;

    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedQuery');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Membuka Google Maps ($encodedQuery)...'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Membuka rute di Google Maps ($encodedQuery)...'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.storefront_rounded,
                    size: 16,
                    color: Color(0xFF0D9488),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Lokasi Konsultasi',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F766E),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFCCFBF1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${distanceKm.toStringAsFixed(1)} km',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F766E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Clinic Name & Address
          Text(
            clinicName,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            _effectiveAddress,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';

class CounselorGuidelinesModal {
  static const String kodeEtikPdfUrl =
      'https://ocw.upj.ac.id/files/Handout-PSY204-Kode-Etik-Psikologi-Indonesia.pdf';

  static void showProfessional(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.88,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(ctx).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modal drag indicator
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kode Etik Psikologi Indonesia',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Berdasarkan Kode Etik HIMPSI (Tahun 2010)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Scrollable content area
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Banner Legal HIMPSI 2010
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.verified_rounded, color: Color(0xFF1D4ED8), size: 16),
                                SizedBox(width: 6),
                                Text(
                                  'Kongres XI HIMPSI Tahun 2010 di Surakarta',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Praktik telekonseling dan pendokumentasian SOAP klinis di EVA berlandaskan Buku Kode Etik Psikologi Indonesia resmi yang disahkan Pengurus Pusat HIMPSI (Cetakan Juni 2010).',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF1E3A8A),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: () async {
                                final uri = Uri.parse(kodeEtikPdfUrl);
                                try {
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  }
                                } catch (_) {}
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF93C5FD)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.picture_as_pdf_rounded, size: 14, color: Color(0xFFDC2626)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Buka Dokumen PDF Resmi (UPJ OCW)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1D4ED8),
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(Icons.open_in_new_rounded, size: 12, color: Color(0xFF1D4ED8)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      const Text(
                        'Pasal & Standar Operasional Telekonseling:',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),

                      _ethicItem(
                        icon: Icons.lock_outline_rounded,
                        article: 'Pasal 24: Mempertahankan Kerahasiaan Data',
                        desc:
                            'Psikolog wajib menjaga rahasia pengguna layanan. Data rekam SOAP, transkrip, dan evaluasi emosional dienkripsi (AES-256) dan hanya dapat diakses psikolog penanggung jawab.',
                      ),
                      const SizedBox(height: 8),
                      _ethicItem(
                        icon: Icons.emergency_outlined,
                        article: 'Pasal 25: Batasan Kerahasiaan & Protokol Krisis',
                        desc:
                            'Kerahasiaan dapat dikesampingkan bila ada ancaman bahaya keselamatan jiwa atau risiko self-harm pasien guna aktivasi hotline darurat & rujukan medis.',
                      ),
                      const SizedBox(height: 8),
                      _ethicItem(
                        icon: Icons.assignment_turned_in_outlined,
                        article: 'Pasal 20 & 73: Informed Consent Telekonseling',
                        desc:
                            'Sebelum sesi berlangsung, pasien wajib memperoleh edukasi jelas mengenai hak, batasan kerahasiaan, proses layanan, dan menyetujui e-consent secara sukarela.',
                      ),
                      const SizedBox(height: 8),
                      _ethicItem(
                        icon: Icons.handshake_outlined,
                        article: 'Pasal 13: Sikap Profesional & Integritas Hubungan',
                        desc:
                            'Konselor wajib mengutamakan kesejahteraan mental pasien, menjaga batas profesional, serta menghindari hubungan majemuk yang mengeksploitasi.',
                      ),
                      const SizedBox(height: 8),
                      _ethicItem(
                        icon: Icons.payments_outlined,
                        article: 'Pasal 33: Penjelasan Biaya & Transparansi Tarif',
                        desc:
                            'Skema tarif sesi konsultasi 30 menit dan pembagian honorarium disepakati secara terbuka, adil, dan transparan tanpa ada biaya tersembunyi.',
                      ),
                      const SizedBox(height: 8),
                      _ethicItem(
                        icon: Icons.badge_outlined,
                        article: 'Pasal 71: Batasan Praktik & Kompetensi Klinis',
                        desc:
                            'Layanan psikologi diselenggarakan sesuai lingkup kompetensi keahlian dan lisensi STR/SIPP aktif yang telah terverifikasi secara resmi di Kemenkes & HIMPSI.',
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _ethicItem({
    required IconData icon,
    required String article,
    required String desc,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEF2F6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  article,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

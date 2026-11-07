import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class CounselorReviewsModal {
  static void show(BuildContext context) {
    final reviews = [
      {
        'name': 'R**** P****',
        'topic': 'Konseling Kecemasan & Insomnia',
        'rating': 5,
        'date': '2 hari lalu',
        'comment': 'dr. Sarah sangat mendengarkan tanpa menghakimi. Teknik regulasi napas dan CBT yang diajarkan sangat membantu mengendalikan serangan panik saya. Terima kasih banyak!',
        'tag': 'Sangat Empatik',
      },
      {
        'name': 'M**** S****',
        'topic': 'Burnout Akademik & Skripsi',
        'rating': 5,
        'date': '5 hari lalu',
        'comment': 'Sesi konsultasi sangat terstruktur dan menenangkan. Saya mendapat sudut pandang baru dan langkah tindak lanjut yang sangat realistis untuk dijalankan.',
        'tag': 'Solutif & Tenang',
      },
      {
        'name': 'A**** N****',
        'topic': 'Regulasi Emosi & Hubungan',
        'rating': 5,
        'date': '1 minggu lalu',
        'comment': 'Dokter sangat ramah, hangat, dan memberikan insight mendalam tentang pola komunikasi saya dengan keluarga.',
        'tag': 'Insight Mendalam',
      },
      {
        'name': 'D**** K****',
        'topic': 'Stres Kerja & Manajemen Waktu',
        'rating': 4,
        'date': '2 minggu lalu',
        'comment': 'Sangat membantu memetakan prioritas hidup. Telekonsultasi tepat waktu dan rangkuman SOAP Luna sangat memudahkan saya mereview kembali.',
        'tag': 'Tepat Waktu',
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ListView(
            controller: scrollController,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E4EB),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ulasan & Penilaian Pasien', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FD),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFECEFF8)),
                ),
                child: Row(
                  children: [
                    Column(
                      children: const [
                        Text('4.9', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                        Row(
                          children: [
                            Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
                            Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
                            Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
                            Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
                            Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
                          ],
                        ),
                        SizedBox(height: 2),
                        Text('140 Ulasan', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        children: [
                          _ratingBar('5 ⭐', 0.92, '130'),
                          const SizedBox(height: 4),
                          _ratingBar('4 ⭐', 0.06, '8'),
                          const SizedBox(height: 4),
                          _ratingBar('3 ⭐', 0.02, '2'),
                          const SizedBox(height: 4),
                          _ratingBar('2 ⭐', 0.0, '0'),
                          const SizedBox(height: 4),
                          _ratingBar('1 ⭐', 0.0, '0'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _reviewTagPill('❤️ Sangat Empatik (98%)'),
                  _reviewTagPill('💡 Solutif (95%)'),
                  _reviewTagPill('⏱️ Tepat Waktu (99%)'),
                ],
              ),
              const SizedBox(height: 18),
              const Text('Testimoni Pasien (Anonim demi Privasi):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 10),
              ...reviews.map((r) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFECEFF8)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.primaryContainer,
                                child: const Icon(Icons.person, size: 16, color: AppColors.primary),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  Text(r['topic'] as String, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                ],
                              ),
                            ],
                          ),
                          Text(r['date'] as String, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ...List.generate(
                            r['rating'] as int,
                            (_) => const Icon(Icons.star_rounded, color: AppColors.warning, size: 14),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              r['tag'] as String,
                              style: const TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        r['comment'] as String,
                        style: const TextStyle(fontSize: 11, height: 1.4, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _ratingBar(String label, double pct, String count) {
    return Row(
      children: [
        SizedBox(width: 26, child: Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: const Color(0xFFE5E9F2),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.warning),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(width: 22, child: Text(count, textAlign: TextAlign.right, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))),
      ],
    );
  }

  static Widget _reviewTagPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/top_toast.dart';
import '../../../auth/domain/entities/psychologist_user_entity.dart';
import '../../domain/entities/eva_certificate_entity.dart';

class CounselorCertificatesModal {
  static List<EvaCertificateEntity> getCertificatesForUser(PsychologistUserEntity? user) {
    final name = user?.displayName ?? 'dr. Sarah Jenkins, M.Psi';
    final isVol = user?.isVolunteer == true;

    if (isVol) {
      return [
        EvaCertificateEntity(
          id: 'CERT-VOL-01',
          title: 'SERTIFIKAT KELULUSAN PEER COUNSELOR',
          subtitle: 'Certified Active Listener & Support Specialist',
          recipientName: name,
          milestoneCriteria: 'Lulus Uji Etika & Pelatihan Konseling Sebaya',
          certificateNumber: 'EVA/CERT/2026/VOL/00094',
          issueDate: '15 Oktober 2026',
          categoryLabel: 'Relawan Teman Sebaya',
          description:
              'Diberikan atas kelulusan program sertifikasi pendampingan emosional, komunikasi empatik non-klinis, dan kepatuhan penuh terhadap etika teman sebaya Eva.',
          badgeColor: const Color(0xFF0284C7),
        ),
        EvaCertificateEntity(
          id: 'CERT-VOL-02',
          title: 'SERTIFIKAT DEDIKASI TEMAN SEBAYA',
          subtitle: 'Community Mental Health Dedication Award',
          recipientName: name,
          milestoneCriteria: 'Menyelesaikan 10 Sesi Curhat Komunitas',
          certificateNumber: 'EVA/CERT/2026/VOL/00148',
          issueDate: '01 November 2026',
          categoryLabel: 'Relawan Teman Sebaya',
          description:
              'Diberikan sebagai penghargaan atas ketulusan mendengarkan aktif dan mendampingi keluhan emosional teman sebaya di ekosistem kesehatan mental Eva.',
          badgeColor: const Color(0xFFD97706),
        ),
        EvaCertificateEntity(
          id: 'CERT-VOL-03',
          title: 'SERTIFIKAT KONTRIBUTOR EMPATI SEBAYA',
          subtitle: 'Excellence in Community Empathy 2026',
          recipientName: name,
          milestoneCriteria: 'Pendampingan 25 Sesi Tanpa Keluhan & Rating 5.0',
          certificateNumber: 'EVA/CERT/2026/VOL/00220',
          issueDate: '05 November 2026',
          categoryLabel: 'Relawan Teman Sebaya',
          description:
              'Diberikan atas kontribusi konsisten menjaga ruang aman bebas penghakiman, memberikan pertolongan pertama psikologis suportif bagi sesama.',
          badgeColor: const Color(0xFF16A34A),
        ),
      ];
    } else {
      return [
        EvaCertificateEntity(
          id: 'CERT-PRO-01',
          title: 'SERTIFIKAT PRAKTIK TELEKONSELING KLINIS',
          subtitle: 'Clinical Tele-Psychology Excellence & Competence',
          recipientName: name,
          milestoneCriteria: 'Penyelesaian 25 Sesi Klinis Terverifikasi',
          certificateNumber: 'EVA/CERT/2026/PRO/00341',
          issueDate: '20 Oktober 2026',
          categoryLabel: user?.isPartner == true ? 'Psikolog Mitra' : 'Psikolog Mandiri',
          description:
              'Diberikan atas dedikasi dan kompetensi klinis prima dalam menyelenggarakan telekonsultasi kesehatan mental dengan standar etika tertinggi.',
          badgeColor: const Color(0xFF2563EB),
        ),
        EvaCertificateEntity(
          id: 'CERT-PRO-02',
          title: 'SERTIFIKAT KEPATUHAN REKAM MEDIS SOAP',
          subtitle: 'Certified Clinical Medical Record Standard',
          recipientName: name,
          milestoneCriteria: 'Kepatuhan Rekam SOAP 100% pada 50 Sesi',
          certificateNumber: 'EVA/CERT/2026/PRO/00512',
          issueDate: '02 November 2026',
          categoryLabel: user?.isPartner == true ? 'Psikolog Mitra' : 'Psikolog Mandiri',
          description:
              'Diberikan atas komitmen integritas dokumentasi SOAP klinis (Subjective, Objective, Assessment, Plan) yang terenkripsi aman demi keselamatan pasien.',
          badgeColor: const Color(0xFFD97706),
        ),
        EvaCertificateEntity(
          id: 'CERT-PRO-03',
          title: 'SERTIFIKAT KONSELOR TELADAN EVA 2026',
          subtitle: 'Distinguished Clinical Practitioner 2026',
          recipientName: name,
          milestoneCriteria: '100+ Sesi Terlaksana dengan Rating Kepuasan 4.9+',
          certificateNumber: 'EVA/CERT/2026/PRO/00789',
          issueDate: '06 November 2026',
          categoryLabel: user?.isPartner == true ? 'Psikolog Mitra' : 'Psikolog Mandiri',
          description:
              'Penghargaan tertinggi platform Eva atas loyalitas pelayanan intervensi krisis, kepuasan pasien bintang lima, dan kontribusi nyata pada kesehatan jiwa bangsa.',
          badgeColor: const Color(0xFF7E22CE),
        ),
      ];
    }
  }

  static void showGallery(BuildContext context, PsychologistUserEntity? user) {
    final certs = getCertificatesForUser(user);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFD97706), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sertifikat & Pencapaian',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${certs.length} Sertifikat resmi diraih berdasarkan milestone',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.textSecondary),
                    splashRadius: 22,
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.65,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: certs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (modalCtx, idx) {
                    final c = certs[idx];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFECEFF8)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: c.badgeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.military_tech_rounded, color: c.badgeColor, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      c.milestoneCriteria,
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  c.issueDate,
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            c.description,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Divider(height: 20, color: Color(0xFFF1F5F9)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'No: ${c.certificateNumber}',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.remove_red_eye_outlined, size: 14),
                                label: const Text('Buka & Unduh', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  Navigator.of(modalCtx).pop();
                                  showOfficialCertificate(context, c);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void showOfficialCertificate(BuildContext context, EvaCertificateEntity cert) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(color: Colors.black38, blurRadius: 28, offset: Offset(0, 10)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 8, left: 16),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium_rounded, size: 18, color: Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Pratinjau Sertifikat Resmi',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.textPrimary),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.textSecondary),
                      splashRadius: 22,
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFDF8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFB45309), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD97706).withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD97706), width: 1.2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('✦', style: TextStyle(color: Color(0xFFB45309), fontSize: 14)),
                              Text('✦', style: TextStyle(color: Color(0xFFB45309), fontSize: 14)),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.spa_rounded, color: AppColors.primary, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'EVA MENTAL HEALTH ECOSYSTEM',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.8,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'LEMBAGA LAYANAN TELEKONSELING & KESEHATAN JIWA TERINTEGRASI',
                            style: TextStyle(
                              fontSize: 7.5,
                              letterSpacing: 0.8,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            cert.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: Color(0xFF1E293B),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cert.subtitle,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFFB45309),
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(width: 40, height: 1.2, color: const Color(0xFFD97706)),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Text('★', style: TextStyle(color: Color(0xFFD97706), fontSize: 10)),
                              ),
                              Container(width: 40, height: 1.2, color: const Color(0xFFD97706)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Diberikan dengan penuh hormat & apresiasi kepada:',
                            style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            cert.recipientName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 4, bottom: 8),
                            height: 1.5,
                            width: 140,
                            color: const Color(0xFFD97706),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '★ ${cert.milestoneCriteria} ★',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              cert.description,
                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF334155), height: 1.45),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No: ${cert.certificateNumber}  •  Diterbitkan di Jakarta, ${cert.issueDate}',
                            style: const TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Column(
                                children: [
                                  const Text(
                                    'dr. Robert W., Sp.KJ',
                                    style: TextStyle(
                                      fontFamily: 'serif',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E3A8A),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  Container(height: 1, width: 85, color: const Color(0xFFCBD5E1)),
                                  const SizedBox(height: 2),
                                  const Text('Ketua Komite Medis', style: TextStyle(fontSize: 8, color: Color(0xFF64748B))),
                                ],
                              ),
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const RadialGradient(
                                    colors: [Color(0xFFFDE68A), Color(0xFFD97706), Color(0xFFB45309)],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFD97706).withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                  border: Border.all(color: const Color(0xFFFEF3C7), width: 1.5),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.workspace_premium_rounded, size: 20, color: Colors.white),
                                      Text(
                                        'VERIFIED',
                                        style: TextStyle(
                                          fontSize: 6,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Column(
                                children: [
                                  const Text(
                                    'Nadine L., M.Psi',
                                    style: TextStyle(
                                      fontFamily: 'serif',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E3A8A),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  Container(height: 1, width: 85, color: const Color(0xFFCBD5E1)),
                                  const SizedBox(height: 2),
                                  const Text('Direktur Konseling', style: TextStyle(fontSize: 8, color: Color(0xFF64748B))),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('✦', style: TextStyle(color: Color(0xFFB45309), fontSize: 14)),
                              Text('✦', style: TextStyle(color: Color(0xFFB45309), fontSize: 14)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Tutup', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Unduh Sertifikat (PDF)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          TopToast.show(
                            context,
                            title: 'Sertifikat Berhasil Diunduh! 📄',
                            message: 'Tersimpan di unduhan: ${cert.certificateNumber.replaceAll("/", "_")}.pdf',
                            type: ToastType.success,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

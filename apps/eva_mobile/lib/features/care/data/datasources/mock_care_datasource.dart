import 'dart:async';
import '../../domain/entities/consultation_session_entity.dart';
import '../../domain/entities/psychologist_entity.dart';
import '../../domain/entities/psychologist_rating_review.dart';
import '../models/psychologist_model.dart';
import '../models/community_status_model.dart';
import '../models/consultation_session_model.dart';
import '../models/counselor_timeline_dto.dart';
import 'care_datasource.dart';

class MockCareDataSource implements CareDataSource {
  // In-memory state for reactive demo & offline support
  CommunityStatusModel _communityStatus = const CommunityStatusModel(
    isMember: false,
    isVipActive: false,
    vipRemainingDays: 0,
    serverName: 'Eva Safe Space ID',
    inviteUrl: 'https://discord.gg/evasafespace',
    memberCount: 1420,
  );

  final List<PsychologistModel> _psychologists = [
    const PsychologistModel(
      id: 'psy_1',
      name: 'Amanda Zahra, M.Psi., Psikolog',
      title: 'Psikolog Klinis Dewasa',
      registrationNumber: 'SIPP: 1988-12-04-2021',
      avatarUrl: 'https://images.unsplash.com/photo-1594824813583-059df30f1484?w=400&auto=format&fit=crop&q=80',
      rating: 4.95,
      reviewCount: 68,
      experienceYears: 6,
      practitionerType: PractitionerType.professional,
      hasPsychologistCertificate: true,
      isVolunteerRole: false,
      levelTier: 3,
      levelName: 'Senior Specialist',
      levelBadgeIcon: 'star',
      strVerified: true,
      sipVerified: true,
      availabilityStatus: CounselorAvailabilityStatus.availableNow,
      nextAvailableSlot: '14:00',
      remainingSlotsToday: 5,
      hasSlotsTomorrow: true,
      nextSlotTomorrow: '08:00',
      specialties: ['Kecemasan', 'Quarter-Life Crisis', 'Burnout Karir', 'Self-Esteem'],
      patientReviewTags: [
        'Sangat Sabar & Empati',
        'Teknik CBT Mudah Dipahami',
        'Slot Jadwal Cepat Penuh',
        'Ruang Cerita Bebas Menghakimi',
      ],
      reviewTags: [
        PatientReviewTag(label: 'Sangat Sabar & Empati', sentiment: ReviewSentiment.positive),
        PatientReviewTag(label: 'Teknik CBT Mudah Dipahami', sentiment: ReviewSentiment.positive),
        PatientReviewTag(label: 'Slot Jadwal Cepat Penuh', sentiment: ReviewSentiment.negative),
        PatientReviewTag(label: 'Ruang Cerita Bebas Menghakimi', sentiment: ReviewSentiment.positive),
        PatientReviewTag(label: 'Waktu 50 Mnt Terasa Singkat', sentiment: ReviewSentiment.negative),
      ],
      testimonials: [
        PatientReviewItem(
          id: 'rev_1_1',
          patientName: 'Pasien Terverifikasi (A. Z.)',
          sentiment: ReviewSentiment.positive,
          label: 'Sangat Sabar & Empati',
          description: 'Kak Amanda sangat sabar mendengarkan ceritaku tanpa menghakimi. Setelah sesi, rasanya beban pikiran berkurang banyak dan overthinking terkontrol.',
          rating: 5.0,
          timeAgo: '2 hari lalu',
        ),
        PatientReviewItem(
          id: 'rev_1_2',
          patientName: 'Pasien Terverifikasi (R. K.)',
          sentiment: ReviewSentiment.positive,
          label: 'Teknik CBT Mudah Dipahami',
          description: 'Latihan grounding dan teknik CBT yang diajarkan sangat membantu meredakan panik saat bekerja di kantor. Penjelasannya sangat runut dan praktis.',
          rating: 5.0,
          timeAgo: '5 hari lalu',
        ),
        PatientReviewItem(
          id: 'rev_1_3',
          patientName: 'Pasien Terverifikasi (M. F.)',
          sentiment: ReviewSentiment.negative,
          label: 'Slot Jadwal Cepat Penuh',
          description: 'Kualitas konselingnya luar biasa bermanfaat, hanya saja antrean slot jadwal cepat sekali penuh sehingga perlu booking dari jauh hari.',
          rating: 4.0,
          timeAgo: '1 minggu lalu',
        ),
        PatientReviewItem(
          id: 'rev_1_4',
          patientName: 'Pasien Terverifikasi (N. D.)',
          sentiment: ReviewSentiment.positive,
          label: 'Ruang Cerita Bebas Menghakimi',
          description: 'Pertama kali konsultasi dan sempat cemas, tapi Kak Amanda langsung menciptakan safe space yang menenangkan untuk membedah luka batin.',
          rating: 5.0,
          timeAgo: '2 minggu lalu',
        ),
        PatientReviewItem(
          id: 'rev_1_5',
          patientName: 'Pasien Terverifikasi (H. P.)',
          sentiment: ReviewSentiment.positive,
          label: 'Rencana Aksi Sangat Konkret',
          description: 'Diberikan action plan mingguan yang realistis untuk mengatasi quarter-life crisis. Sangat terasa perbedaannya dalam 3 sesi berturut-turut.',
          rating: 4.8,
          timeAgo: '1 bulan lalu',
        ),
      ],
      patientReviews: [
        'Kak Amanda sangat sabar mendengarkan ceritaku tanpa menghakimi. Setelah sesi, rasanya beban pikiran berkurang banyak.',
        'Latihan grounding dan teknik CBT yang diajarkan sangat membantu meredakan panik saat bekerja.',
      ],
      patientStats: PatientStatsEntity(
        totalPatientsTreated: 284,
        totalSessionsCompleted: 490,
        satisfactionRate: 98.6,
        positiveReviewRate: 96.2,
        recoveryRate: 94.5,
        avgRecoverySessions: 3.8,
        recoveryDescription: '94.5% pasien merasakan penurunan kecemasan & stres kerja signifikan',
      ),
      certifications: [
        'SIPP: 1988-12-04-2021 (HIMPSI)',
        'Magister Profesi Psikologi Klinis Dewasa (S2)',
        'Sertifikasi CBT Terapan & Regulasi Emosi',
        'Sertifikat Psychological First Aid (PFA) Nasional',
      ],
      coinsPerSession: 50,
      durationMinutes: 50,
      availableOnline: true,
      clinicAffiliation: 'RS Mitra Medika & Klinik Sahabat Jiwa',
      bio: 'Fokus pada pendekatan Cognitive Behavioral Therapy (CBT) dan Acceptance and Commitment Therapy (ACT) untuk membantu individu mengatasi stres kerja, overthinking, dan krisis identitas.',
    ),
    const PsychologistModel(
      id: 'psy_2',
      name: 'Dimas Wicaksono, M.Psi., Psikolog',
      title: 'Psikolog Klinis & Spesialis Karir',
      registrationNumber: 'SIPP: 1985-07-15-2019',
      avatarUrl: 'https://images.unsplash.com/photo-1622253692010-333f2da6031d?w=400&auto=format&fit=crop&q=80',
      rating: 4.92,
      reviewCount: 94,
      experienceYears: 8,
      practitionerType: PractitionerType.professional,
      hasPsychologistCertificate: true,
      isVolunteerRole: false,
      levelTier: 4,
      levelName: 'Master Expert',
      levelBadgeIcon: 'crown',
      strVerified: true,
      sipVerified: true,
      availabilityStatus: CounselorAvailabilityStatus.availableToday,
      nextAvailableSlot: '16:00',
      remainingSlotsToday: 2,
      hasSlotsTomorrow: true,
      nextSlotTomorrow: '09:00',
      specialties: ['Burnout & Stres Kerja', 'Depresi Ringan', 'Resolusi Konflik', 'Manajemen Emosi'],
      patientReviewTags: [
        'Solutif & Terarah',
        'Bikin Pikiran Lebih Terang',
        'Ekspektasi Terlalu Tinggi di Awal',
        'Profesional & Disiplin',
      ],
      reviewTags: [
        PatientReviewTag(label: 'Solutif & Terarah', sentiment: ReviewSentiment.positive),
        PatientReviewTag(label: 'Bikin Pikiran Lebih Terang', sentiment: ReviewSentiment.positive),
        PatientReviewTag(label: 'Ekspektasi Terlalu Tinggi di Awal', sentiment: ReviewSentiment.negative),
        PatientReviewTag(label: 'Profesional & Disiplin', sentiment: ReviewSentiment.positive),
        PatientReviewTag(label: 'Tugas Refleksi Cukup Banyak', sentiment: ReviewSentiment.negative),
      ],
      testimonials: [
        PatientReviewItem(
          id: 'rev_2_1',
          patientName: 'Pasien Terverifikasi (T. B.)',
          sentiment: ReviewSentiment.positive,
          label: 'Solutif & Terarah',
          description: 'Mas Dimas memberikan sudut pandang yang sangat logis dan menenangkan saat aku burnout parah di tempat kerja korporat.',
          rating: 5.0,
          timeAgo: '1 hari lalu',
        ),
        PatientReviewItem(
          id: 'rev_2_2',
          patientName: 'Pasien Terverifikasi (K. W.)',
          sentiment: ReviewSentiment.positive,
          label: 'Bikin Pikiran Lebih Terang',
          description: 'Sesi berjalan sangat terstruktur. Saya langsung dapat rencana aksi konkret untuk menghadapi atasan toxic dan menata ulang work-life balance.',
          rating: 5.0,
          timeAgo: '4 hari lalu',
        ),
        PatientReviewItem(
          id: 'rev_2_3',
          patientName: 'Pasien Terverifikasi (V. J.)',
          sentiment: ReviewSentiment.negative,
          label: 'Tugas Refleksi Cukup Padat',
          description: 'Pendekatannya sangat direct dan berorientasi hasil, namun tugas refleksi mandiri di antara sesi lumayan padat untuk orang yang sedang lelah mental.',
          rating: 4.0,
          timeAgo: '1 minggu lalu',
        ),
        PatientReviewItem(
          id: 'rev_2_4',
          patientName: 'Pasien Terverifikasi (E. L.)',
          sentiment: ReviewSentiment.positive,
          label: 'Profesional & Disiplin',
          description: 'Sangat tepat waktu, komunikatif, dan tidak bertele-tele. Sesi 50 menit dimanfaatkan secara maksimal untuk akar masalah.',
          rating: 5.0,
          timeAgo: '3 minggu lalu',
        ),
        PatientReviewItem(
          id: 'rev_2_5',
          patientName: 'Pasien Terverifikasi (D. S.)',
          sentiment: ReviewSentiment.positive,
          label: 'Regulasi Emosi Terasa Nyata',
          description: 'Teknik SFBT dari Mas Dimas menyelamatkan karir dan relasi saya dengan rekan kantor. Kondisi depresi ringan berangsur pulih.',
          rating: 4.8,
          timeAgo: '1 bulan lalu',
        ),
      ],
      patientReviews: [
        'Mas Dimas memberikan sudut pandang yang sangat logis dan menenangkan saat aku burnout parah.',
        'Sesi berjalan sangat nyaman dan langsung dapat rencana aksi konkret untuk minggu depan.',
      ],
      patientStats: PatientStatsEntity(
        totalPatientsTreated: 412,
        totalSessionsCompleted: 780,
        satisfactionRate: 98.2,
        positiveReviewRate: 95.7,
        recoveryRate: 93.8,
        avgRecoverySessions: 4.1,
        recoveryDescription: '93.8% pasien pulih dari sindrom kelelahan kerja (burnout) & stres kronis',
      ),
      certifications: [
        'SIPP: 1985-07-15-2019 (HIMPSI)',
        'Magister Profesi Psikologi Klinis & Industri (S2)',
        'Sertifikasi Solution-Focused Brief Therapy (SFBT)',
        'Certified Workplace Wellness Specialist',
      ],
      coinsPerSession: 60,
      durationMinutes: 50,
      availableOnline: true,
      clinicAffiliation: 'RS Jiwa & Emosi Harmoni',
      bio: 'Pendekatan solusi terfokus (SFBT) dan regulasi emosi untuk membantu profesional muda menyeimbangkan karir dan kedamaian mental.',
    ),
    const PsychologistModel(
      id: 'psy_3',
      name: 'Rian Pratama, M.Psi., Psikolog',
      title: 'Psikolog Konseling Hubungan & Keluarga',
      registrationNumber: 'SIPP: 1991-05-18-2022',
      avatarUrl: 'https://images.unsplash.com/photo-1537368910025-700350fe46c7?w=400&auto=format&fit=crop&q=80',
      rating: 4.88,
      reviewCount: 45,
      experienceYears: 5,
      practitionerType: PractitionerType.freelance,
      hasPsychologistCertificate: true,
      isVolunteerRole: false,
      levelTier: 2,
      levelName: 'Registered Counselor',
      levelBadgeIcon: 'shield-check',
      strVerified: true,
      sipVerified: true,
      availabilityStatus: CounselorAvailabilityStatus.availableTomorrow,
      nextAvailableSlot: '09:30',
      remainingSlotsToday: 0,
      hasSlotsTomorrow: true,
      nextSlotTomorrow: '09:30',
      specialties: ['Dinamika Hubungan', 'Luka Batin Masa Lalu', 'Komunikasi Pasangan', 'Grief'],
      patientReviewTags: [
        'Pendengar yang Sangat Baik',
        'Suasana Hangat & Terbuka',
        'Waktu Bicara Cepat Usai',
        'Sangat Menghargai Cerita',
      ],
      reviewTags: [
        PatientReviewTag(label: 'Pendengar yang Sangat Baik', sentiment: ReviewSentiment.positive),
        PatientReviewTag(label: 'Suasana Hangat & Terbuka', sentiment: ReviewSentiment.positive),
        PatientReviewTag(label: 'Waktu Bicara Cepat Usai', sentiment: ReviewSentiment.negative),
        PatientReviewTag(label: 'Sangat Menghargai Cerita', sentiment: ReviewSentiment.positive),
        PatientReviewTag(label: 'Jadwal Akhir Pekan Terbatas', sentiment: ReviewSentiment.negative),
      ],
      testimonials: [
        PatientReviewItem(
          id: 'rev_3_1',
          patientName: 'Pasien Terverifikasi (Y. S.)',
          sentiment: ReviewSentiment.positive,
          label: 'Pendengar yang Sangat Baik',
          description: 'Kak Rian sangat hangat dan membuat aku merasa aman untuk menceritakan masalah keluarga yang selama ini kupendam bertahun-tahun.',
          rating: 5.0,
          timeAgo: '3 hari lalu',
        ),
        PatientReviewItem(
          id: 'rev_3_2',
          patientName: 'Pasien Terverifikasi (B. H.)',
          sentiment: ReviewSentiment.positive,
          label: 'Suasana Hangat & Terbuka',
          description: 'Gaya bicaranya tenang dan tidak mendikte, membuat saya secara alami menyadari pola komunikasi saya yang keliru dengan pasangan.',
          rating: 5.0,
          timeAgo: '6 hari lalu',
        ),
        PatientReviewItem(
          id: 'rev_3_3',
          patientName: 'Pasien Terverifikasi (F. M.)',
          sentiment: ReviewSentiment.negative,
          label: 'Waktu Bicara Cepat Usai',
          description: 'Konselingnya luar biasa nyaman, namun karena topiknya mendalam rasanya durasi 50 menit berlalu terlalu cepat sebelum semua tersampaikan.',
          rating: 4.2,
          timeAgo: '1 minggu lalu',
        ),
        PatientReviewItem(
          id: 'rev_3_4',
          patientName: 'Pasien Terverifikasi (R. A.)',
          sentiment: ReviewSentiment.positive,
          label: 'Sangat Menghargai Cerita',
          description: 'Sangat suportif saat mendampingi proses berduka (grief). Tiap tangisan divalidasi dan diberi ruang tanpa dipaksa cepat-cepat move on.',
          rating: 5.0,
          timeAgo: '2 minggu lalu',
        ),
        PatientReviewItem(
          id: 'rev_3_5',
          patientName: 'Pasien Terverifikasi (A. M.)',
          sentiment: ReviewSentiment.positive,
          label: 'Penyembuhan Luka Batin',
          description: 'Latihan rekonsiliasi emosional yang dibimbing Kak Rian sangat membantu saya memaafkan trauma masa kecil secara bertahap.',
          rating: 4.8,
          timeAgo: '1 bulan lalu',
        ),
      ],
      patientReviews: [
        'Kak Rian sangat hangat dan membuat aku merasa aman untuk menceritakan masalah keluarga yang selama ini kupendam.',
        'Gaya bicaranya tenang dan tidak mendikte, membuat saya sadar akar masalah saya sendiri.',
      ],
      patientStats: PatientStatsEntity(
        totalPatientsTreated: 215,
        totalSessionsCompleted: 395,
        satisfactionRate: 97.9,
        positiveReviewRate: 95.3,
        recoveryRate: 92.4,
        avgRecoverySessions: 3.5,
        recoveryDescription: '92.4% pasien melaporkan resolusi konflik hubungan & penerimaan luka batin',
      ),
      certifications: [
        'SIPP: 1991-05-18-2022 (HIMPSI)',
        'Magister Profesi Psikologi Klinis (S2)',
        'Praktisi Psikolog Mandiri / Freelance Terdaftar',
        'Sertifikat Konseling Krisis & Relawan Komunitas',
      ],
      coinsPerSession: 40,
      durationMinutes: 50,
      availableOnline: true,
      clinicAffiliation: 'Freelance',
      bio: 'Menggunakan pendekatan humanistik dan mindfulness untuk memfasilitasi rekonsiliasi emosional serta penyembuhan luka batin relasional.',
    ),
    const PsychologistModel(
      id: 'psy_4',
      name: 'Nathania Stephanie, S.Psi., M.Psi.',
      title: 'Psikolog Konseling & Mindfulness Coach',
      registrationNumber: 'SIPP: 1994-08-22-2023',
      avatarUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=400&auto=format&fit=crop&q=80',
      rating: 4.90,
      reviewCount: 39,
      experienceYears: 4,
      practitionerType: PractitionerType.freelance,
      hasPsychologistCertificate: true,
      isVolunteerRole: false,
      levelTier: 2,
      levelName: 'Registered Counselor',
      levelBadgeIcon: 'shield-check',
      strVerified: true,
      sipVerified: true,
      availabilityStatus: CounselorAvailabilityStatus.availableNow,
      nextAvailableSlot: '14:00',
      remainingSlotsToday: 6,
      hasSlotsTomorrow: true,
      nextSlotTomorrow: '08:30',
      specialties: ['Mindfulness Terapan', 'Manajemen Emosi', 'Inner Child Healing', 'Kecemasan Sosial'],
      patientReviewTags: [
        'Menyejukkan Hati',
        'Latihan Pernapasan Efektif',
        'Perlu Latihan Mandiri Konsisten',
        'Bikin Hati Tenang',
      ],
      reviewTags: [
        PatientReviewTag(label: 'Menyejukkan Hati', sentiment: ReviewSentiment.positive),
        PatientReviewTag(label: 'Latihan Pernapasan Efektif', sentiment: ReviewSentiment.positive),
        PatientReviewTag(label: 'Perlu Latihan Mandiri Konsisten', sentiment: ReviewSentiment.negative),
        PatientReviewTag(label: 'Bikin Hati Tenang', sentiment: ReviewSentiment.positive),
        PatientReviewTag(label: 'Instruksi Awal Butuh Penyesuaian', sentiment: ReviewSentiment.negative),
      ],
      testimonials: [
        PatientReviewItem(
          id: 'rev_4_1',
          patientName: 'Pasien Terverifikasi (C. P.)',
          sentiment: ReviewSentiment.positive,
          label: 'Menyejukkan Hati',
          description: 'Sesi bareng Mbak Nathania beneran bikin tenang, teknik pernapasan somatiknya sangat manjur saat cemas melanda di tengah keramaian.',
          rating: 5.0,
          timeAgo: '2 hari lalu',
        ),
        PatientReviewItem(
          id: 'rev_4_2',
          patientName: 'Pasien Terverifikasi (I. W.)',
          sentiment: ReviewSentiment.positive,
          label: 'Latihan Pernapasan Efektif',
          description: 'Diajarkan metode grounding 5-4-3-2-1 yang disesuaikan dengan kondisi saya. Suara dan pembawaannya sangat menenangkan batin.',
          rating: 5.0,
          timeAgo: '5 hari lalu',
        ),
        PatientReviewItem(
          id: 'rev_4_3',
          patientName: 'Pasien Terverifikasi (J. K.)',
          sentiment: ReviewSentiment.negative,
          label: 'Butuh Pembiasaan Mandiri',
          description: 'Teknik mindfulness-nya bagus, tapi butuh disiplin pribadi yang tinggi di luar sesi agar efek tenangnya tidak cepat luntur.',
          rating: 4.2,
          timeAgo: '1 minggu lalu',
        ),
        PatientReviewItem(
          id: 'rev_4_4',
          patientName: 'Pasien Terverifikasi (S. N.)',
          sentiment: ReviewSentiment.positive,
          label: 'Bikin Hati Tenang',
          description: 'Pendekatan penerimaan diri secara utuh membuka sudut pandang baru bahwa tidak apa-apa jika sesekali merasa lelah dan tidak sempurna.',
          rating: 5.0,
          timeAgo: '2 minggu lalu',
        ),
        PatientReviewItem(
          id: 'rev_4_5',
          patientName: 'Pasien Terverifikasi (G. B.)',
          sentiment: ReviewSentiment.positive,
          label: 'Inner Child Healing Terarah',
          description: 'Sesi penyembuhan inner child sangat mendalam. Rasanya seperti berdamai kembali dengan masa lalu dengan penuh kelembutan.',
          rating: 4.7,
          timeAgo: '1 bulan lalu',
        ),
      ],
      patientReviews: [
        'Sesi bareng Mbak Nathania beneran bikin tenang, teknik pernapasan somatiknya sangat manjur saat cemas melanda.',
      ],
      patientStats: PatientStatsEntity(
        totalPatientsTreated: 168,
        totalSessionsCompleted: 295,
        satisfactionRate: 98.1,
        positiveReviewRate: 96.5,
        recoveryRate: 93.0,
        avgRecoverySessions: 3.4,
        recoveryDescription: '93% pasien merasakan peningkatan kestabilan emosi & regulasi stres somatik',
      ),
      certifications: [
        'SIPP: 1994-08-22-2023 (HIMPSI)',
        'Magister Profesi Psikologi (S2)',
        'Praktisi Psikolog Mandiri / Freelance Terdaftar',
        'Sertifikasi Mindfulness-Based Stress Reduction (MBSR)',
      ],
      coinsPerSession: 35,
      durationMinutes: 50,
      availableOnline: true,
      clinicAffiliation: 'Freelance',
      bio: 'Membimbing individu menemukan kedamaian batin melalui latihan pernapasan, relaksasi somatik, dan penerimaan diri secara utuh.',
    ),
    const PsychologistModel(
      id: 'psy_5',
      name: 'Bayu Aditya, M.Psi., Psikolog',
      title: 'Psikolog Klinis Dewasa Muda',
      registrationNumber: 'SIPP: 1995-03-11-2024',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80',
      rating: 4.85,
      reviewCount: 52,
      experienceYears: 2,
      practitionerType: PractitionerType.professional,
      hasPsychologistCertificate: true,
      isVolunteerRole: false,
      levelTier: 1,
      levelName: 'Junior Practitioner',
      levelBadgeIcon: 'award',
      strVerified: true,
      sipVerified: true,
      availabilityStatus: CounselorAvailabilityStatus.availableToday,
      nextAvailableSlot: '15:30',
      remainingSlotsToday: 3,
      hasSlotsTomorrow: true,
      nextSlotTomorrow: '10:00',
      specialties: ['Stres Akademik & Skripsi', 'Quarter-Life Crisis', 'Overthinking', 'Kesepian'],
      patientReviewTags: [
        'Teman Cerita yang Ramah',
        'Tanpa Menghakimi',
        'Bukan Jalur Klinis Berat',
        'Sangat Relatable',
      ],
      reviewTags: [
        PatientReviewTag(label: 'Teman Cerita yang Ramah', sentiment: ReviewSentiment.positive),
        PatientReviewTag(label: 'Tanpa Menghakimi', sentiment: ReviewSentiment.positive),
        PatientReviewTag(label: 'Bukan Jalur Klinis Berat', sentiment: ReviewSentiment.negative),
        PatientReviewTag(label: 'Sangat Relatable', sentiment: ReviewSentiment.positive),
        PatientReviewTag(label: 'Slot Konseling Cepat Habis', sentiment: ReviewSentiment.negative),
      ],
      testimonials: [
        PatientReviewItem(
          id: 'rev_5_1',
          patientName: 'Pasien Terverifikasi (M. R.)',
          sentiment: ReviewSentiment.positive,
          label: 'Teman Cerita yang Ramah',
          description: 'Kak Bayu berasa kayak teman curhat yang bener-bener dengerin tanpa nge-judge sama sekali. Sangat membantu saat lagi buntu skripsi!',
          rating: 5.0,
          timeAgo: '1 hari lalu',
        ),
        PatientReviewItem(
          id: 'rev_5_2',
          patientName: 'Pasien Terverifikasi (D. F.)',
          sentiment: ReviewSentiment.positive,
          label: 'Tanpa Menghakimi',
          description: 'Senang banget bisa cerita ke Kak Bayu, bahasanya santai tapi tetap berbobot dan menenangkan saat overthinking masa depan.',
          rating: 5.0,
          timeAgo: '3 hari lalu',
        ),
        PatientReviewItem(
          id: 'rev_5_3',
          patientName: 'Pasien Terverifikasi (L. A.)',
          sentiment: ReviewSentiment.negative,
          label: 'Batas Ruang Lingkup Sebaya',
          description: 'Sebagai konselor sebaya sangat bersahabat, tapi jika memiliki trauma klinis kompleks memang disarankan dirujuk ke psikolog berlisensi.',
          rating: 4.1,
          timeAgo: '1 minggu lalu',
        ),
        PatientReviewItem(
          id: 'rev_5_4',
          patientName: 'Pasien Terverifikasi (P. O.)',
          sentiment: ReviewSentiment.positive,
          label: 'Sangat Relatable',
          description: 'Paham banget keresahan anak muda fresh graduate dan quarter-life struggle. Mengobrol 45 menit rasanya sangat melegakan.',
          rating: 5.0,
          timeAgo: '2 minggu lalu',
        ),
        PatientReviewItem(
          id: 'rev_5_5',
          patientName: 'Pasien Terverifikasi (W. K.)',
          sentiment: ReviewSentiment.positive,
          label: 'Respon Cepat & Tulus',
          description: 'Layanan gratis tapi dedikasinya luar biasa tinggi. Saya merasa tidak sendirian lagi dalam perjuangan mental ini.',
          rating: 4.8,
          timeAgo: '1 bulan lalu',
        ),
      ],
      patientReviews: [
        'Kak Bayu berasa kayak teman curhat yang bener-bener dengerin tanpa nge-judge sama sekali. Sangat membantu saat lagi buntu!',
        'Senang banget bisa cerita ke Kak Bayu, bahasanya santai tapi tetap berbobot dan menenangkan.',
      ],
      patientStats: PatientStatsEntity(
        totalPatientsTreated: 195,
        totalSessionsCompleted: 270,
        satisfactionRate: 97.5,
        positiveReviewRate: 94.8,
        recoveryRate: 91.2,
        avgRecoverySessions: 2.8,
        recoveryDescription: '91.2% teman sebaya merasa bebannya terurai & menemukan jalan keluar stres',
      ),
      certifications: [
        'SIPP: 1995-03-11-2024 (HIMPSI)',
        'Magister Profesi Psikologi Klinis (S2)',
        'Sertifikat Psychological First Aid (PFA) - Kemenkes RI',
      ],
      coinsPerSession: 30,
      durationMinutes: 45,
      availableOnline: true,
      clinicAffiliation: 'Klinik Jiwa Muda',
      bio: 'Psikolog klinis yang fokus mendampingi dewasa muda menghadapi transisi karir, tekanan akademik, dan manajemen kecemasan sehari-hari.',
    ),
    const PsychologistModel(
      id: 'psy_6',
      name: 'Nadira Putri, M.Psi., Psikolog',
      title: 'Psikolog Klinis & Pemulihan Trauma',
      registrationNumber: 'SIPP: 1992-09-14-2022',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80',
      rating: 4.93,
      reviewCount: 41,
      experienceYears: 5,
      practitionerType: PractitionerType.professional,
      hasPsychologistCertificate: true,
      isVolunteerRole: false,
      levelTier: 3,
      levelName: 'Senior Specialist',
      levelBadgeIcon: 'star',
      strVerified: true,
      sipVerified: true,
      availabilityStatus: CounselorAvailabilityStatus.availableTomorrow,
      nextAvailableSlot: '08:30',
      remainingSlotsToday: 0,
      hasSlotsTomorrow: true,
      nextSlotTomorrow: '08:30',
      specialties: ['Pemulihan Trauma', 'Regulasi Emosi', 'Validasi Perasaan', 'Krisis Emosional'],
      patientReviewTags: [
        'Sangat Tulus & Peduli',
        'Menenangkan Saat Kalut',
        'Waktu Konseling Terbatas',
        'Selalu Ada untuk Mendengar',
      ],
      reviewTags: [
        PatientReviewTag(label: 'Sangat Tulus & Peduli', sentiment: ReviewSentiment.positive),
        PatientReviewTag(label: 'Menenangkan Saat Kalut', sentiment: ReviewSentiment.positive),
        PatientReviewTag(label: 'Waktu Konseling Terbatas', sentiment: ReviewSentiment.negative),
        PatientReviewTag(label: 'Selalu Ada untuk Mendengar', sentiment: ReviewSentiment.positive),
        PatientReviewTag(label: 'Tersedia di Jam Malam Tertentu', sentiment: ReviewSentiment.negative),
      ],
      testimonials: [
        PatientReviewItem(
          id: 'rev_6_1',
          patientName: 'Pasien Terverifikasi (S. M.)',
          sentiment: ReviewSentiment.positive,
          label: 'Sangat Tulus & Peduli',
          description: 'Di saat lagi ngerasa sendirian banget dan mau nangis di kamar, Kak Nadira nemenin aku dengan penuh kasih sampai tenang kembali.',
          rating: 5.0,
          timeAgo: '1 hari lalu',
        ),
        PatientReviewItem(
          id: 'rev_6_2',
          patientName: 'Pasien Terverifikasi (H. A.)',
          sentiment: ReviewSentiment.positive,
          label: 'Menenangkan Saat Kalut',
          description: 'Validasi emosi yang diberikan Kak Nadira membuat saya berhenti menyalahkan diri sendiri. Ruang dengar yang benar-benar tanpa syarat.',
          rating: 5.0,
          timeAgo: '4 hari lalu',
        ),
        PatientReviewItem(
          id: 'rev_6_3',
          patientName: 'Pasien Terverifikasi (T. R.)',
          sentiment: ReviewSentiment.negative,
          label: 'Durasi Terasa Singkat',
          description: 'Pendampingannya sangat menghibur hati, hanya saja karena keterbatasan jadwal relawan, sesi harus selesai dalam 45 menit.',
          rating: 4.3,
          timeAgo: '1 minggu lalu',
        ),
        PatientReviewItem(
          id: 'rev_6_4',
          patientName: 'Pasien Terverifikasi (F. K.)',
          sentiment: ReviewSentiment.positive,
          label: 'Selalu Ada untuk Mendengar',
          description: 'Sangat sigap dan empatik. Mengetahui ada seseorang yang peduli secara tulus di masa krisis adalah penyelamat hidup.',
          rating: 5.0,
          timeAgo: '3 minggu lalu',
        ),
        PatientReviewItem(
          id: 'rev_6_5',
          patientName: 'Pasien Terverifikasi (N. L.)',
          sentiment: ReviewSentiment.positive,
          label: 'Bikin Adem & Reda',
          description: 'Teknik stabilisasi awal yang diajarkan sangat menolong saya melewati malam-malam cemas yang berat.',
          rating: 4.9,
          timeAgo: '1 bulan lalu',
        ),
      ],
      patientReviews: [
        'Di saat lagi ngerasa sendirian banget dan mau nangis, Kak Nadira nemenin aku sampai tenang kembali. Terima kasih banyak!',
      ],
      patientStats: PatientStatsEntity(
        totalPatientsTreated: 172,
        totalSessionsCompleted: 240,
        satisfactionRate: 98.5,
        positiveReviewRate: 96.0,
        recoveryRate: 94.0,
        avgRecoverySessions: 2.6,
        recoveryDescription: '94% penerima manfaat berhasil melewati fase krisis emosional awal dengan stabil',
      ),
      certifications: [
        'SIPP: 1992-09-14-2022 (HIMPSI)',
        'Magister Profesi Psikologi Klinis (S2)',
        'Sertifikat Trauma-Informed Care & Stabilisasi Emosi',
      ],
      coinsPerSession: 50,
      durationMinutes: 50,
      availableOnline: true,
      clinicAffiliation: 'Klinik Ruang Aman',
      bio: 'Psikolog klinis berlisensi dengan pendekatan trauma-informed care untuk membantu pemulihan emosional dan ketahanan mental.',
    ),
  ];

  late final List<ConsultationSessionModel> _sessions = [
    ConsultationSessionModel(
      id: 'sess_1',
      psychologist: _psychologists[0], // Amanda Zahra
      sessionDateTime: DateTime.now().add(const Duration(minutes: 5)),
      status: ConsultationStatus.upcoming,
      type: ConsultationType.onlineVideo,
      meetingUrl: 'https://meet.eva-care.ai/room-amanda-zahra',
      notes: 'Evaluasi intensitas kecemasan dan overthinking terkait evaluasi kinerja tahunan di kantor.',
      sessionNumber: 2,
      moodBefore: 'Cemas Tinggi (Skala 8/10)',
      adviceList: const [
        'Lakukan relaksasi grounding 5-4-3-2-1 saat merasa kewalahan.',
        'Gunakan format restrukturisasi kognitif di Eva Diary.',
      ],
      actionItems: const [
        'Tulis 3 bukti objektif pencapaian kerja sebelum sesi berikutnya.',
      ],
    ),
    ConsultationSessionModel(
      id: 'sess_2',
      psychologist: _psychologists[1], // Dimas Wicaksono
      sessionDateTime: DateTime.now().add(const Duration(days: 2, hours: 3)),
      status: ConsultationStatus.upcoming,
      type: ConsultationType.onlineVideo,
      meetingUrl: 'https://meet.eva-care.ai/room-dimas-wicaksono',
      notes: 'Strategi mengatasi burnout kerja dan menetapkan batasan (boundary setting) dengan atasan.',
      sessionNumber: 1,
      moodBefore: 'Lelah Mental & Jenuh (Skala 7/10)',
    ),
    ConsultationSessionModel(
      id: 'sess_3',
      psychologist: _psychologists[0], // Amanda Zahra
      sessionDateTime: DateTime.now().subtract(const Duration(days: 7, hours: 2)),
      status: ConsultationStatus.completed,
      type: ConsultationType.onlineVideo,
      meetingUrl: 'https://meet.eva-care.ai/room-amanda-prev-1',
      notes: 'Keluhan awal: Sering sesak napas, gelisah malam hari, dan panik saat deadline kerja menumpuk.',
      diagnosisSummary: 'Kecemasan situasional dengan hiperventilasi psikosomatis ringan.',
      sessionSummary: 'Mengidentifikasi lingkaran setan overthinking malam hari dan membimbing teknik somatic grounding.',
      sessionNumber: 1,
      durationMinutes: 50,
      moodBefore: 'Sangat Cemas & Panik (Skala 9/10)',
      moodAfter: 'Lebih Tenang & Terkendali (Skala 4/10)',
      adviceList: const [
        'Praktikkan teknik relaksasi napas 4-7-8 setiap malam 15 menit sebelum waktu tidur.',
        'Batasi konsumsi berita dan email pekerjaan setelah pukul 19:30 WIB.',
        'Gunakan fitur Jurnal Refleksi Eva untuk meluapkan unek-unek sebelum memejamkan mata.',
      ],
      actionItems: const [
        'Lakukan grounding 5-4-3-2-1 begitu merasakan tanda-tanda awal hiperventilasi.',
        'Catat 3 hal yang berhasil dikendalikan hari ini di diary.',
      ],
    ),
    ConsultationSessionModel(
      id: 'sess_4',
      psychologist: _psychologists[1], // Dimas Wicaksono
      sessionDateTime: DateTime.now().subtract(const Duration(days: 16)),
      status: ConsultationStatus.completed,
      type: ConsultationType.onlineVideo,
      meetingUrl: 'https://meet.eva-care.ai/room-dimas-prev',
      notes: 'Keluhan awal: Sindrom burnout parah akibat lembur terus-menerus dan kesulitan menolak pekerjaan tambahan.',
      diagnosisSummary: 'Exhaustion phase burnout dengan distorsi rasa bersalah tidak rasional.',
      sessionSummary: 'Bedah pemicu workaholism dan latihan komunikasi asertif dalam menolak tugas di luar job desk.',
      sessionNumber: 1,
      durationMinutes: 50,
      moodBefore: 'Burnout Berat & Frustrasi (Skala 8/10)',
      moodAfter: 'Merasa Berdaya & Sadar Batasan Diri (Skala 4/10)',
      adviceList: const [
        'Gunakan teknik asertif "Broken Record": tegaskan kapasitas kerja dengan tenang tanpa merasa bersalah berlebihan.',
        'Jadwalkan "Digital Detox" minimal 4 jam setiap hari Minggu.',
        'Fokus pada 3 prioritas utama harian daripada memaksakan to-do list panjang tak realistis.',
      ],
      actionItems: const [
        'Buat pembagian waktu kerja tegas: jam kerja selesai pukul 18:00 WIB.',
        'Berlatih mengatakan tidak pada satu permintaan non-esensial minggu ini.',
      ],
    ),
    ConsultationSessionModel(
      id: 'sess_5',
      psychologist: _psychologists[2], // Rian Pratama
      sessionDateTime: DateTime.now().subtract(const Duration(days: 28)),
      status: ConsultationStatus.completed,
      type: ConsultationType.onlineVideo,
      meetingUrl: 'https://meet.eva-care.ai/room-rian-prev',
      notes: 'Keluhan awal: Konflik berulang dengan pasangan seputar komunikasi dan perasaan tidak didengar.',
      diagnosisSummary: 'Pola komunikasi defensif dan disregulasi emosi relasional.',
      sessionSummary: 'Mengeksplorasi pemicu luka masa lalu yang terproyeksikan ke pasangan dan latihan active listening.',
      sessionNumber: 1,
      durationMinutes: 50,
      moodBefore: 'Marah & Putus Asa (Skala 8/10)',
      moodAfter: 'Hati Hangat & Memahami Pola Pasangan (Skala 4/10)',
      adviceList: const [
        'Gunakan format "I-statement" saat diskusi: "Aku merasa sedih ketika..." bukan "Kamu selalu...".',
        'Ambil jeda time-out 15 menit jika pembicaraan mulai meninggi sebelum diselesaikan.',
        'Hindari asumsi pikiran pasangan (mind-reading), tanyakan klarifikasi langsung.',
      ],
      actionItems: const [
        'Latih mindful pause 3 detik sebelum menjawab saat sedang emosional.',
        'Agendakan sesi obrolan apresiasi santai berdua tanpa gadget.',
      ],
    ),
  ];

  @override
  Future<List<PsychologistModel>> getPsychologists({
    String? availability,
    int? levelTier,
    String? sortBy,
    String? query,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    var result = List<PsychologistModel>.from(_psychologists);

    final avail = (availability ?? 'all').trim().toLowerCase();
    if (avail == 'available_now') {
      result = result.where((p) => p.isAvailableNow).toList();
    } else if (avail == 'available_today') {
      result = result.where((p) => p.isAvailableToday).toList();
    } else if (avail == 'available_tomorrow') {
      result = result.where((p) => p.hasSlotsTomorrow).toList();
    }

    if (levelTier != null) {
      result = result.where((p) => p.levelTier == levelTier).toList();
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase().trim();
      result = result.where((p) {
        final matchesName = p.name.toLowerCase().contains(q);
        final matchesTitle = p.title.toLowerCase().contains(q);
        final matchesSpecialty = p.specialties.any((s) => s.toLowerCase().contains(q));
        final matchesReviewTag = p.patientReviewTags.any((t) => t.toLowerCase().contains(q));
        final matchesLevel = p.levelName?.toLowerCase().contains(q) ?? false;
        final matchesClinic = p.clinicAffiliation?.toLowerCase().contains(q) ?? false;
        return matchesName ||
            matchesTitle ||
            matchesSpecialty ||
            matchesReviewTag ||
            matchesLevel ||
            matchesClinic;
      }).toList();
    }

    if (sortBy == 'rating') {
      result.sort((a, b) {
        final ratingCmp = b.rating.compareTo(a.rating);
        if (ratingCmp != 0) return ratingCmp;
        return b.reviewCount.compareTo(a.reviewCount);
      });
    } else if (sortBy == 'experience') {
      result.sort((a, b) => b.experienceYears.compareTo(a.experienceYears));
    } else {
      const rank = {
        CounselorAvailabilityStatus.availableNow: 0,
        CounselorAvailabilityStatus.availableToday: 1,
        CounselorAvailabilityStatus.availableTomorrow: 2,
        CounselorAvailabilityStatus.unavailable: 3,
      };
      result.sort((a, b) {
        final rCmp = (rank[a.availabilityStatus] ?? 3).compareTo(rank[b.availabilityStatus] ?? 3);
        if (rCmp != 0) return rCmp;
        return b.rating.compareTo(a.rating);
      });
    }

    return result;
  }

  @override
  Future<List<ConsultationSessionModel>> getConsultationSessions() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List<ConsultationSessionModel>.from(_sessions);
  }

  @override
  Future<CounselorTimelineDto> getCounselorTimeline({
    required String counselorId,
    required DateTime date,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final dateString =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final isFriday = date.weekday == DateTime.friday;

    final blockedRanges = isFriday
        ? const [
            BlockedRangeDto(
              start: '09:30',
              end: '10:30',
              type: 'booked',
              label: 'Sesi Pasien Terjadwal',
            ),
            BlockedRangeDto(
              start: '10:30',
              end: '10:45',
              type: 'buffer',
              label: 'Jeda Konseling',
            ),
            BlockedRangeDto(
              start: '11:30',
              end: '13:00',
              type: 'break',
              label: 'Shalat Jumat & Istirahat',
            ),
            BlockedRangeDto(
              start: '15:30',
              end: '16:00',
              type: 'break',
              label: 'Istirahat Sore',
            ),
          ]
        : const [
            BlockedRangeDto(
              start: '10:00',
              end: '11:00',
              type: 'booked',
              label: 'Sesi Pasien Terjadwal',
            ),
            BlockedRangeDto(
              start: '11:00',
              end: '11:15',
              type: 'buffer',
              label: 'Jeda Konseling',
            ),
            BlockedRangeDto(
              start: '12:00',
              end: '13:00',
              type: 'break',
              label: 'Istirahat Siang',
            ),
            BlockedRangeDto(
              start: '15:00',
              end: '15:30',
              type: 'break',
              label: 'Coffee Break',
            ),
          ];

    final availableWindows = isFriday
        ? const [
            TimeRangeDto(start: '08:00', end: '09:30'),
            TimeRangeDto(start: '10:45', end: '11:30'),
            TimeRangeDto(start: '13:00', end: '15:30'),
            TimeRangeDto(start: '16:00', end: '17:00'),
          ]
        : const [
            TimeRangeDto(start: '08:00', end: '10:00'),
            TimeRangeDto(start: '11:15', end: '12:00'),
            TimeRangeDto(start: '13:00', end: '15:00'),
            TimeRangeDto(start: '15:30', end: '17:00'),
          ];

    return CounselorTimelineDto(
      counselorId: counselorId,
      date: dateString,
      operatingHours: const OperatingHoursDto(start: '08:00', end: '17:00'),
      blockedRanges: blockedRanges,
      availableWindows: availableWindows,
    );
  }

  @override
  Future<ConsultationSessionModel> bookConsultation({
    required String psychologistId,
    required DateTime preferredDateTime,
    required ConsultationType sessionType,
    int sessionCount = 1,
    int durationMinutes = 30,
    String? complaints,
    bool shareAiChatHistory = false,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final targetPsy = _psychologists.firstWhere(
      (p) => p.id == psychologistId,
      orElse: () => _psychologists.first,
    );

    final newSession = ConsultationSessionModel(
      id: 'sess_${DateTime.now().millisecondsSinceEpoch}',
      psychologist: targetPsy,
      sessionDateTime: preferredDateTime,
      status: ConsultationStatus.upcoming,
      type: ConsultationType.onlineVideo,
      durationMinutes: durationMinutes > 0 ? durationMinutes : sessionCount * 30,
      meetingUrl: 'https://meet.google.com/eva-consult-${DateTime.now().millisecondsSinceEpoch}',
      notes: complaints,
      shareAiChatHistory: shareAiChatHistory,
    );

    _sessions.insert(0, newSession);
    return newSession;
  }

  @override
  Future<CommunityStatusModel> getCommunityStatus() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _communityStatus;
  }

  @override
  Future<CommunityStatusModel> joinCommunityWithVipTrial() async {
    await Future.delayed(const Duration(milliseconds: 400));
    _communityStatus = _communityStatus.copyWith(
      isMember: true,
      isVipActive: true,
      vipRemainingDays: 30,
    );
    return _communityStatus;
  }

  @override
  Future<PsychologistModel> getCounselorDetail(String counselorId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _psychologists.firstWhere(
      (p) => p.id == counselorId,
      orElse: () => _psychologists.first,
    );
  }

  @override
  Future<List<PatientReviewItem>> getCounselorReviews(String counselorId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final psy = _psychologists.firstWhere(
      (p) => p.id == counselorId,
      orElse: () => _psychologists.first,
    );
    return List<PatientReviewItem>.from(psy.effectiveTestimonials);
  }

  @override
  Future<PsychologistRatingReview> submitSessionReview({
    required String sessionId,
    required String psychologistId,
    required double rating,
    String? highlightLabel,
    String? reviewText,
    bool isAnonymous = true,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final review = PsychologistRatingReview(
      psychologistId: psychologistId,
      rating: rating,
      isPositive: rating >= 4.0,
      label: (highlightLabel ?? '').trim(),
      description: (reviewText ?? '').trim(),
      tags: (highlightLabel ?? '').trim().isNotEmpty ? [highlightLabel!.trim()] : const [],
      createdAt: DateTime.now(),
      isAnonymous: isAnonymous,
    );
    final idx = _sessions.indexWhere((s) => s.id == sessionId);
    if (idx != -1) {
      final old = _sessions[idx];
      _sessions[idx] = ConsultationSessionModel(
        id: old.id,
        psychologist: old.psychologist,
        sessionDateTime: old.sessionDateTime,
        status: old.status,
        type: old.type,
        meetingUrl: old.meetingUrl,
        notes: old.notes,
        diagnosisSummary: old.diagnosisSummary,
        sessionNumber: old.sessionNumber,
        adviceList: old.adviceList,
        actionItems: old.actionItems,
        moodBefore: old.moodBefore,
        moodAfter: old.moodAfter,
        durationMinutes: old.durationMinutes,
        sessionSummary: old.sessionSummary,
        shareAiChatHistory: old.shareAiChatHistory,
        isExtended: old.isExtended,
        hasReview: true,
        myReview: review,
      );
    }
    return review;
  }
}

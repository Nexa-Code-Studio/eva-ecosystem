import 'dart:async';
import '../../domain/entities/consultation_session_entity.dart';
import '../models/psychologist_model.dart';
import '../models/clinic_model.dart';
import '../models/community_status_model.dart';
import '../models/consultation_session_model.dart';
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
      specialties: ['Kecemasan', 'Quarter-Life Crisis', 'Burnout Karir', 'Self-Esteem'],
      feePerSession: 140000,
      durationMinutes: 50,
      availableOnline: true,
      clinicAffiliation: 'Klinik Sahabat Jiwa Jakarta',
      bio: 'Fokus pada pendekatan Cognitive Behavioral Therapy (CBT) dan Acceptance and Commitment Therapy (ACT) untuk membantu individu mengatasi stres kerja, overthinking, dan krisis identitas.',
    ),
    const PsychologistModel(
      id: 'psy_2',
      name: 'dr. Hendra Kusuma, Sp.KJ',
      title: 'Dokter Spesialis Kedokteran Jiwa (Psikiater)',
      registrationNumber: 'STR: 31.1.1.100.2.20.123456',
      avatarUrl: 'https://images.unsplash.com/photo-1622253692010-333f2da6031d?w=400&auto=format&fit=crop&q=80',
      rating: 4.98,
      reviewCount: 112,
      experienceYears: 10,
      specialties: ['Gangguan Mood / Bipolar', 'Depresi Berat', 'Insomnia Kronis', 'Farmakoterapi'],
      feePerSession: 250000,
      durationMinutes: 45,
      availableOnline: true,
      clinicAffiliation: 'RS Jiwa & Emosi Harmoni',
      bio: 'Menangani gangguan afektif, kecemasan akut, dan depresi berat dengan kombinasi intervensi psikofarmaka rasional serta psikoedukasi holistik.',
    ),
    const PsychologistModel(
      id: 'psy_3',
      name: 'Rian Pratama, M.Psi., Psikolog',
      title: 'Psikolog Klinis & Konselor Hubungan',
      registrationNumber: 'SIPP: 1991-05-18-2022',
      avatarUrl: 'https://images.unsplash.com/photo-1537368910025-700350fe46c7?w=400&auto=format&fit=crop&q=80',
      rating: 4.88,
      reviewCount: 45,
      experienceYears: 5,
      specialties: ['Dinamika Keluarga', 'Trauma Masa Lalu', 'Komunikasi Pasangan', 'Grief'],
      feePerSession: 130000,
      durationMinutes: 50,
      availableOnline: true,
      clinicAffiliation: 'Pusat Konseling Bina Jiwa',
      bio: 'Menggunakan pendekatan humanistik dan mindfulness untuk memfasilitasi rekonsiliasi emosional serta penyembuhan luka batin relasional.',
    ),
    const PsychologistModel(
      id: 'psy_4',
      name: 'dr. Citra Lestari, Sp.KJ, Subsp.AR(K)',
      title: 'Psikiater Konsultan Adiksi & Remaja',
      registrationNumber: 'STR: 32.2.1.200.3.19.876543',
      avatarUrl: 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?w=400&auto=format&fit=crop&q=80',
      rating: 4.92,
      reviewCount: 54,
      experienceYears: 8,
      specialties: ['Adiksi Digital/Gadget', 'Kecemasan Remaja', 'ADHD Dewasa', 'Panic Disorder'],
      feePerSession: 275000,
      durationMinutes: 45,
      availableOnline: true,
      clinicAffiliation: 'Klinik Sahabat Jiwa Jakarta',
      bio: 'Spesialis kesehatan mental transisi usia muda dan dewasa, pemulihan regulasi dopamin, dan manajemen serangan panik.',
    ),
    const PsychologistModel(
      id: 'psy_5',
      name: 'Nathania Stephanie, S.Psi., M.Psi.',
      title: 'Psikolog Anak & Mindfulness Coach',
      registrationNumber: 'SIPP: 1994-08-22-2023',
      avatarUrl: 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=400&auto=format&fit=crop&q=80',
      rating: 4.90,
      reviewCount: 39,
      experienceYears: 4,
      specialties: ['Mindfulness Based Therapy', 'Manajemen Emosi', 'Inner Child Healing', 'Burnout'],
      feePerSession: 125000,
      durationMinutes: 50,
      availableOnline: true,
      clinicAffiliation: 'Ruang Tumbuh Jiwa',
      bio: 'Membimbing individu menemukan kedamaian batin melalui latihan pernapasan, relaksasi somatik, dan penerimaan diri secara utuh.',
    ),
  ];

  final List<ClinicModel> _clinics = [
    const ClinicModel(
      id: 'clinic_1',
      name: 'Klinik Utama Sahabat Jiwa',
      address: 'Jl. Tebet Barat Raya No. 42, Tebet, Jakarta Selatan',
      city: 'Jakarta Selatan',
      distanceKm: 2.3,
      photoUrl: 'https://images.unsplash.com/photo-1519494026892-80bbd2d6fd0d?w=400&auto=format&fit=crop&q=80',
      phone: '021-83701234',
      facilities: ['Ruang Konseling Privat', 'Farmasi Jiwa', 'Ruang Meditasi', 'Parkir Luas'],
      rating: 4.9,
    ),
    const ClinicModel(
      id: 'clinic_2',
      name: 'RS Jiwa & Emosi Harmoni',
      address: 'Jl. Dr. Saharjo No. 108, Setiabudi, Jakarta Selatan',
      city: 'Jakarta Selatan',
      distanceKm: 4.1,
      photoUrl: 'https://images.unsplash.com/photo-1586773860418-d37222d8fce3?w=400&auto=format&fit=crop&q=80',
      phone: '021-82909988',
      facilities: ['UGD Psikiatri 24 Jam', 'Laboratorium Tes', 'Konseling Pasangan', 'Ambulans'],
      rating: 4.8,
    ),
    const ClinicModel(
      id: 'clinic_3',
      name: 'Pusat Konseling Bina Jiwa Bandung',
      address: 'Jl. Cihampelas No. 156, Coblong, Bandung',
      city: 'Bandung',
      distanceKm: 128.0,
      photoUrl: 'https://images.unsplash.com/photo-1629909613654-28e377c37b09?w=400&auto=format&fit=crop&q=80',
      phone: '022-2031122',
      facilities: ['Konseling Komunitas', 'Workshop Art Therapy', 'Taman Terbuka'],
      rating: 4.7,
    ),
  ];

  late final List<ConsultationSessionModel> _sessions = [
    ConsultationSessionModel(
      id: 'sess_1',
      psychologist: _psychologists[0], // Amanda Zahra
      sessionDateTime: DateTime.now().add(const Duration(days: 1, hours: 3)),
      status: ConsultationStatus.upcoming,
      type: ConsultationType.onlineVideo,
      meetingUrl: 'https://meet.google.com/eva-care-session',
      notes: 'Fokus sesi: Evaluasi kecemasan menjelang presentasi kerja & latihan grounding 5-4-3-2-1.',
    ),
    ConsultationSessionModel(
      id: 'sess_2',
      psychologist: _psychologists[1], // dr. Hendra Kusuma
      sessionDateTime: DateTime.now().subtract(const Duration(days: 12)),
      status: ConsultationStatus.completed,
      type: ConsultationType.onlineVideo,
      meetingUrl: 'https://meet.google.com/eva-care-prev',
      notes: 'Diagnosis awal: Mild somatic anxiety dengan gangguan pola tidur. Disarankan melanjutkan relaksasi pernapasan 4-7-8 dan pencatatan diary rutin di Eva.',
      diagnosisSummary: 'Rekomendasi kontrol 1 bulan atau saat ada lonjakan stres signifikan.',
    ),
  ];

  @override
  Future<List<PsychologistModel>> getPsychologists({String? category, String? query}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    var result = List<PsychologistModel>.from(_psychologists);

    if (category != null && category.isNotEmpty && category != 'all') {
      if (category == 'psychiatrist') {
        result = result.where((p) => p.isPsychiatrist).toList();
      } else if (category == 'psychologist') {
        result = result.where((p) => !p.isPsychiatrist).toList();
      }
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase().trim();
      result = result.where((p) {
        final matchesName = p.name.toLowerCase().contains(q);
        final matchesSpecialty = p.specialties.any((s) => s.toLowerCase().contains(q));
        final matchesClinic = p.clinicAffiliation?.toLowerCase().contains(q) ?? false;
        return matchesName || matchesSpecialty || matchesClinic;
      }).toList();
    }

    return result;
  }

  @override
  Future<List<ClinicModel>> getClinics({String? query}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    var result = List<ClinicModel>.from(_clinics);
    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase().trim();
      result = result.where((c) {
        return c.name.toLowerCase().contains(q) ||
            c.city.toLowerCase().contains(q) ||
            c.address.toLowerCase().contains(q);
      }).toList();
    }
    return result;
  }

  @override
  Future<CommunityStatusModel> getCommunityStatus() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return _communityStatus;
  }

  @override
  Future<CommunityStatusModel> joinCommunityWithVipTrial() async {
    await Future.delayed(const Duration(milliseconds: 400));
    _communityStatus = _communityStatus.copyWith(
      isMember: true,
      isVipActive: true,
      vipRemainingDays: 30,
      joinedAt: DateTime.now(),
      memberCount: _communityStatus.memberCount + 1,
    );
    return _communityStatus;
  }

  @override
  Future<List<ConsultationSessionModel>> getConsultationSessions() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List<ConsultationSessionModel>.from(_sessions);
  }

  @override
  Future<ConsultationSessionModel> bookConsultation({
    required String psychologistId,
    required DateTime preferredDateTime,
    required ConsultationType sessionType,
    String? complaints,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final psychologist = _psychologists.firstWhere(
      (p) => p.id == psychologistId,
      orElse: () => _psychologists.first,
    );

    final newSession = ConsultationSessionModel(
      id: 'sess_${DateTime.now().millisecondsSinceEpoch}',
      psychologist: psychologist,
      sessionDateTime: preferredDateTime,
      status: ConsultationStatus.upcoming,
      type: sessionType,
      meetingUrl: sessionType == ConsultationType.onlineVideo
          ? 'https://meet.google.com/eva-care-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}'
          : null,
      locationName: sessionType == ConsultationType.offlineClinic
          ? (psychologist.clinicAffiliation ?? 'Klinik Rekanan Eva')
          : null,
      notes: complaints != null && complaints.isNotEmpty
          ? 'Keluhan awal: $complaints'
          : 'Sesi konsultasi pendampingan emosi.',
    );

    _sessions.insert(0, newSession);
    return newSession;
  }
}

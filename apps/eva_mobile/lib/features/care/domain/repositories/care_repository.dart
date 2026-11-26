import '../entities/psychologist_entity.dart';
import '../entities/psychologist_rating_review.dart';
import '../entities/community_status_entity.dart';
import '../entities/consultation_session_entity.dart';
import '../entities/counselor_timeline_entity.dart';

abstract class CareRepository {
  /// Mendapatkan daftar psikolog berlisensi dengan opsi filter availability, level, sort, dan pencarian.
  Future<List<PsychologistEntity>> getPsychologists({
    String? availability,
    int? levelTier,
    String? sortBy,
    String? query,
  });

  /// Mendapatkan detail kredensial & profil konselor terverifikasi dari backend.
  Future<PsychologistEntity> getCounselorDetail(String counselorId);

  /// Mendapatkan daftar ulasan & testimoni pasien terverifikasi dari backend.
  Future<List<PatientReviewItem>> getCounselorReviews(String counselorId);

  /// Mengirim rating & ulasan untuk satu sesi konsultasi selesai (1 sesi = 1 review).
  Future<PsychologistRatingReview> submitSessionReview({
    required String sessionId,
    required String psychologistId,
    required double rating,
    String? highlightLabel,
    String? reviewText,
    bool isAnonymous = true,
  });

  /// Mendapatkan status keanggotaan komunitas Discord pengguna.
  Future<CommunityStatusEntity> getCommunityStatus();

  /// Memproses pembelian tiket masuk komunitas sekali bayar + 1 bulan trial VIP event.
  Future<CommunityStatusEntity> joinCommunityWithVipTrial();

  /// Mendapatkan riwayat dan jadwal sesi konsultasi pengguna.
  Future<List<ConsultationSessionEntity>> getConsultationSessions();

  /// Mendapatkan timeline ketersediaan harian psikolog (jam buka, break, slot terisi).
  Future<CounselorTimelineEntity> getCounselorTimeline({
    required String counselorId,
    required DateTime date,
  });

  /// Melakukan booking sesi konsultasi baru (telekonsultasi video online).
  Future<ConsultationSessionEntity> bookConsultation({
    required String psychologistId,
    required DateTime preferredDateTime,
    required ConsultationType sessionType,
    int sessionCount = 1,
    int durationMinutes = 30,
    String? complaints,
    bool shareAiChatHistory = false,
  });
}

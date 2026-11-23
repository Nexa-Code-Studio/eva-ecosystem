import '../entities/psychologist_entity.dart';
import '../entities/clinic_entity.dart';
import '../entities/community_status_entity.dart';
import '../entities/consultation_session_entity.dart';
import '../entities/counselor_timeline_entity.dart';

abstract class CareRepository {
  /// Mendapatkan daftar psikolog & psikiater dengan opsi filter kategori dan pencarian nama.
  Future<List<PsychologistEntity>> getPsychologists({
    String? category, // 'all', 'psychologist', 'psychiatrist'
    String? query,
  });

  /// Mendapatkan daftar klinik rekanan.
  Future<List<ClinicEntity>> getClinics({String? query});

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

  /// Melakukan booking sesi konsultasi baru.
  Future<ConsultationSessionEntity> bookConsultation({
    required String psychologistId,
    required DateTime preferredDateTime,
    required ConsultationType sessionType,
    int sessionCount = 1,
    int durationMinutes = 30,
    String? complaints,
    bool shareAiChatHistory = true,
  });
}

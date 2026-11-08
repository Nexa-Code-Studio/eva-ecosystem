import '../../domain/entities/consultation_session_entity.dart';
import '../models/psychologist_model.dart';
import '../models/clinic_model.dart';
import '../models/community_status_model.dart';
import '../models/consultation_session_model.dart';

abstract class CareDataSource {
  Future<List<PsychologistModel>> getPsychologists({String? category, String? query});
  Future<List<ClinicModel>> getClinics({String? query});
  Future<CommunityStatusModel> getCommunityStatus();
  Future<CommunityStatusModel> joinCommunityWithVipTrial();
  Future<List<ConsultationSessionModel>> getConsultationSessions();
  Future<ConsultationSessionModel> bookConsultation({
    required String psychologistId,
    required DateTime preferredDateTime,
    required ConsultationType sessionType,
    String? complaints,
  });
}

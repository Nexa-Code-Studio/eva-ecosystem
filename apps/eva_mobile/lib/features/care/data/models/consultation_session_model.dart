import '../../domain/entities/consultation_session_entity.dart';
import 'psychologist_model.dart';

class ConsultationSessionModel extends ConsultationSessionEntity {
  const ConsultationSessionModel({
    required super.id,
    required super.psychologist,
    required super.sessionDateTime,
    required super.status,
    super.type = ConsultationType.onlineVideo,
    super.meetingUrl,
    super.locationName,
    super.notes,
    super.diagnosisSummary,
  });

  factory ConsultationSessionModel.fromJson(Map<String, dynamic> json) {
    return ConsultationSessionModel(
      id: json['id'] as String? ?? '',
      psychologist: PsychologistModel.fromJson(
        json['psychologist'] as Map<String, dynamic>? ?? {},
      ),
      sessionDateTime: DateTime.tryParse(json['session_datetime'] as String? ?? '') ??
          DateTime.now(),
      status: _parseStatus(json['status'] as String?),
      type: _parseType(json['type'] as String?),
      meetingUrl: json['meeting_url'] as String?,
      locationName: json['location_name'] as String?,
      notes: json['notes'] as String?,
      diagnosisSummary: json['diagnosis_summary'] as String?,
    );
  }

  static ConsultationStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return ConsultationStatus.completed;
      case 'cancelled':
        return ConsultationStatus.cancelled;
      default:
        return ConsultationStatus.upcoming;
    }
  }

  static ConsultationType _parseType(String? type) {
    switch (type?.toLowerCase()) {
      case 'offline_clinic':
      case 'offline':
        return ConsultationType.offlineClinic;
      default:
        return ConsultationType.onlineVideo;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'psychologist': (psychologist as PsychologistModel).toJson(),
      'session_datetime': sessionDateTime.toIso8601String(),
      'status': status.name,
      'type': type.name,
      'meeting_url': meetingUrl,
      'location_name': locationName,
      'notes': notes,
      'diagnosis_summary': diagnosisSummary,
    };
  }
}

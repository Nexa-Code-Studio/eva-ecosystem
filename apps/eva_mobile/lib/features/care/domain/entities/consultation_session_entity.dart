import 'package:flutter/foundation.dart';
import 'psychologist_entity.dart';

enum ConsultationStatus {
  upcoming,
  completed,
  cancelled,
}

enum ConsultationType {
  onlineVideo,
  offlineClinic,
}

@immutable
class ConsultationSessionEntity {
  final String id;
  final PsychologistEntity psychologist;
  final DateTime sessionDateTime;
  final ConsultationStatus status;
  final ConsultationType type;
  final String? meetingUrl;
  final String? locationName;
  final String? notes;
  final String? diagnosisSummary;

  const ConsultationSessionEntity({
    required this.id,
    required this.psychologist,
    required this.sessionDateTime,
    required this.status,
    this.type = ConsultationType.onlineVideo,
    this.meetingUrl,
    this.locationName,
    this.notes,
    this.diagnosisSummary,
  });

  bool get isUpcoming => status == ConsultationStatus.upcoming;
  bool get isCompleted => status == ConsultationStatus.completed;
}

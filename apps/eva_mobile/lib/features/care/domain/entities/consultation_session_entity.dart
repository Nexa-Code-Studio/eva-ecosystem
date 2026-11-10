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
  final int sessionNumber;
  final List<String> adviceList;
  final List<String> actionItems;
  final String? moodBefore;
  final String? moodAfter;
  final int durationMinutes;
  final String? sessionSummary;
  final bool shareAiChatHistory;

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
    this.sessionNumber = 1,
    this.adviceList = const [],
    this.actionItems = const [],
    this.moodBefore,
    this.moodAfter,
    this.durationMinutes = 50,
    this.sessionSummary,
    this.shareAiChatHistory = true,
  });

  bool get isUpcoming => status == ConsultationStatus.upcoming;
  bool get isCompleted => status == ConsultationStatus.completed;
  bool get isCancelled => status == ConsultationStatus.cancelled;
  bool get isOnlineVideo => type == ConsultationType.onlineVideo;
  bool get isOfflineClinic => type == ConsultationType.offlineClinic;

  ConsultationSessionEntity copyWith({
    String? id,
    PsychologistEntity? psychologist,
    DateTime? sessionDateTime,
    ConsultationStatus? status,
    ConsultationType? type,
    String? meetingUrl,
    String? locationName,
    String? notes,
    String? diagnosisSummary,
    int? sessionNumber,
    List<String>? adviceList,
    List<String>? actionItems,
    String? moodBefore,
    String? moodAfter,
    int? durationMinutes,
    String? sessionSummary,
    bool? shareAiChatHistory,
  }) {
    return ConsultationSessionEntity(
      id: id ?? this.id,
      psychologist: psychologist ?? this.psychologist,
      sessionDateTime: sessionDateTime ?? this.sessionDateTime,
      status: status ?? this.status,
      type: type ?? this.type,
      meetingUrl: meetingUrl ?? this.meetingUrl,
      locationName: locationName ?? this.locationName,
      notes: notes ?? this.notes,
      diagnosisSummary: diagnosisSummary ?? this.diagnosisSummary,
      sessionNumber: sessionNumber ?? this.sessionNumber,
      adviceList: adviceList ?? this.adviceList,
      actionItems: actionItems ?? this.actionItems,
      moodBefore: moodBefore ?? this.moodBefore,
      moodAfter: moodAfter ?? this.moodAfter,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      sessionSummary: sessionSummary ?? this.sessionSummary,
      shareAiChatHistory: shareAiChatHistory ?? this.shareAiChatHistory,
    );
  }
}

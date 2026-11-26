import 'package:flutter/foundation.dart';
import 'psychologist_entity.dart';
import 'psychologist_rating_review.dart';

enum ConsultationStatus {
  upcoming,
  completed,
  cancelled,
  missed,
}

enum ConsultationType {
  onlineVideo,
}

@immutable
class ConsultationSessionEntity {
  final String id;
  final PsychologistEntity psychologist;
  final DateTime sessionDateTime;
  final ConsultationStatus status;
  final ConsultationType type;
  final String? meetingUrl;
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
  final bool isExtended;
  final bool hasReview;
  final PsychologistRatingReview? myReview;

  const ConsultationSessionEntity({
    required this.id,
    required this.psychologist,
    required this.sessionDateTime,
    required this.status,
    this.type = ConsultationType.onlineVideo,
    this.meetingUrl,
    this.notes,
    this.diagnosisSummary,
    this.sessionNumber = 1,
    this.adviceList = const [],
    this.actionItems = const [],
    this.moodBefore,
    this.moodAfter,
    this.durationMinutes = 30,
    this.sessionSummary,
    this.shareAiChatHistory = false,
    this.isExtended = false,
    this.hasReview = false,
    this.myReview,
  });

  bool get isUpcoming => status == ConsultationStatus.upcoming;
  bool get isCompleted => status == ConsultationStatus.completed;
  bool get isCancelled => status == ConsultationStatus.cancelled;
  bool get isMissed => status == ConsultationStatus.missed;
  bool get isOnlineVideo => type == ConsultationType.onlineVideo;

  ConsultationSessionEntity copyWith({
    String? id,
    PsychologistEntity? psychologist,
    DateTime? sessionDateTime,
    ConsultationStatus? status,
    ConsultationType? type,
    String? meetingUrl,
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
    bool? isExtended,
    bool? hasReview,
    PsychologistRatingReview? myReview,
  }) {
    return ConsultationSessionEntity(
      id: id ?? this.id,
      psychologist: psychologist ?? this.psychologist,
      sessionDateTime: sessionDateTime ?? this.sessionDateTime,
      status: status ?? this.status,
      type: type ?? this.type,
      meetingUrl: meetingUrl ?? this.meetingUrl,
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
      isExtended: isExtended ?? this.isExtended,
      hasReview: hasReview ?? this.hasReview,
      myReview: myReview ?? this.myReview,
    );
  }
}

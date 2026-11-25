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
    super.notes,
    super.diagnosisSummary,
    super.sessionNumber = 1,
    super.adviceList = const [],
    super.actionItems = const [],
    super.moodBefore,
    super.moodAfter,
    super.durationMinutes = 30,
    super.sessionSummary,
    super.shareAiChatHistory = false,
    super.isExtended = false,
  });

  factory ConsultationSessionModel.fromJson(Map<String, dynamic> json) {
    final rawDateStr = json['session_datetime']?.toString() ??
        json['scheduled_start_time']?.toString() ??
        '';
    final psyJson = json['psychologist'] as Map<String, dynamic>?;
    final fallbackPsy = psyJson != null
        ? PsychologistModel.fromJson(psyJson)
        : PsychologistModel(
            id: json['counselor_id']?.toString() ?? '',
            name: json['counselor_name']?.toString() ?? 'Psikolog Eva',
            title: 'Psikolog Klinis',
            registrationNumber: '',
            avatarUrl: '',
            rating: 5.0,
            reviewCount: 0,
            experienceYears: 1,
            specialties: const [],
            bio: '',
          );

    return ConsultationSessionModel(
      id: json['id']?.toString() ?? '',
      psychologist: fallbackPsy,
      sessionDateTime: DateTime.tryParse(rawDateStr)?.toLocal() ?? DateTime.now(),
      status: _parseStatus(json['status'] as String?),
      type: ConsultationType.onlineVideo,
      meetingUrl: json['meeting_url'] as String?,
      notes: json['notes'] as String?,
      diagnosisSummary: json['diagnosis_summary'] as String?,
      sessionNumber: (json['session_number'] as num?)?.toInt() ?? 1,
      adviceList: (json['advice_list'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      actionItems: (json['action_items'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      moodBefore: json['mood_before'] as String?,
      moodAfter: json['mood_after'] as String?,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 30,
      sessionSummary: json['session_summary'] as String?,
      shareAiChatHistory: json['share_ai_chat_history'] as bool? ?? false,
      isExtended: json['is_extended'] as bool? ??
          ((json['duration_minutes'] as num?)?.toInt() ?? 30) >= 60,
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'psychologist': (psychologist as PsychologistModel).toJson(),
      'session_datetime': sessionDateTime.toIso8601String(),
      'status': status.name,
      'type': type.name,
      'meeting_url': meetingUrl,
      'notes': notes,
      'diagnosis_summary': diagnosisSummary,
      'session_number': sessionNumber,
      'advice_list': adviceList,
      'action_items': actionItems,
      'mood_before': moodBefore,
      'mood_after': moodAfter,
      'duration_minutes': durationMinutes,
      'session_summary': sessionSummary,
      'share_ai_chat_history': shareAiChatHistory,
      'is_extended': isExtended,
    };
  }
}

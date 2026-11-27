import '../../domain/entities/clinical_note_entity.dart';

class CreateClinicalNoteRequestDto {
  final String patientId;
  final String sessionId;
  final String subjective;
  final String objective;
  final String assessment;
  final String plan;
  final List<String> recommendedTasks;
  final List<String> points;
  final String narrative;

  const CreateClinicalNoteRequestDto({
    required this.patientId,
    required this.sessionId,
    required this.subjective,
    required this.objective,
    required this.assessment,
    required this.plan,
    required this.recommendedTasks,
    this.points = const [],
    this.narrative = '',
  });

  Map<String, dynamic> toJson() => {
        'patient_id': patientId,
        'session_id': sessionId,
        'subjective': subjective,
        'objective': objective,
        'assessment': assessment,
        'plan': plan,
        'recommended_tasks': recommendedTasks,
        'points': points,
        'narrative': narrative,
      };
}

class ClinicalNoteResponseDto {
  final String id;
  final String patientId;
  final String sessionId;
  final String createdAt;
  final String subjective;
  final String objective;
  final String assessment;
  final String plan;
  final List<String> recommendedTasks;
  final List<String> points;
  final String narrative;
  final int coinsAwarded;
  final int? coinBalance;
  final String? soapEditDeadline;
  final bool isSoapEditable;

  const ClinicalNoteResponseDto({
    required this.id,
    required this.patientId,
    required this.sessionId,
    required this.createdAt,
    required this.subjective,
    required this.objective,
    required this.assessment,
    required this.plan,
    required this.recommendedTasks,
    this.points = const [],
    this.narrative = '',
    this.coinsAwarded = 0,
    this.coinBalance,
    this.soapEditDeadline,
    this.isSoapEditable = true,
  });

  factory ClinicalNoteResponseDto.fromJson(Map<String, dynamic> json) {
    final soap = json['soap_notes'] as Map<String, dynamic>?;
    final rawPoints = json['points'] as List<dynamic>? ?? soap?['points'] as List<dynamic>?;
    final points = rawPoints?.map((e) => e.toString()).toList() ?? <String>[];
    final narrative = json['narrative']?.toString() ?? soap?['narrative']?.toString() ?? '';

    return ClinicalNoteResponseDto(
      id: json['id']?.toString() ?? json['session_id']?.toString() ?? '',
      patientId: json['patient_id']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ??
          json['scheduled_start_time']?.toString() ??
          DateTime.now().toIso8601String(),
      subjective: json['subjective']?.toString() ?? soap?['subjective']?.toString() ?? '',
      objective: json['objective']?.toString() ?? soap?['objective']?.toString() ?? '',
      assessment: json['assessment']?.toString() ?? soap?['assessment']?.toString() ?? '',
      plan: json['plan']?.toString() ?? soap?['plan']?.toString() ?? '',
      recommendedTasks: (json['recommended_tasks'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          (soap?['recommended_tasks'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      points: points,
      narrative: narrative,
      coinsAwarded: (json['coins_awarded'] as num?)?.toInt() ?? 0,
      coinBalance: (json['coin_balance'] as num?)?.toInt(),
      soapEditDeadline: json['soap_edit_deadline']?.toString(),
      isSoapEditable: json['is_soap_editable'] as bool? ?? true,
    );
  }

  ClinicalNoteEntity toEntity() {
    return ClinicalNoteEntity(
      id: id,
      patientId: patientId,
      sessionId: sessionId,
      createdAt: DateTime.tryParse(createdAt) ?? DateTime.now(),
      subjective: subjective,
      objective: objective,
      assessment: assessment,
      plan: plan,
      recommendedTasks: recommendedTasks,
      points: points,
      narrative: narrative,
      coinsAwarded: coinsAwarded,
      coinBalance: coinBalance,
      soapEditDeadline: soapEditDeadline != null ? DateTime.tryParse(soapEditDeadline!) : null,
      isSoapEditable: isSoapEditable,
    );
  }
}

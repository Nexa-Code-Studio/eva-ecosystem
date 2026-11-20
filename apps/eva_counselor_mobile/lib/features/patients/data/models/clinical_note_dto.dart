import '../../domain/entities/clinical_note_entity.dart';

class CreateClinicalNoteRequestDto {
  final String patientId;
  final String sessionId;
  final String subjective;
  final String objective;
  final String assessment;
  final String plan;
  final List<String> recommendedTasks;

  const CreateClinicalNoteRequestDto({
    required this.patientId,
    required this.sessionId,
    required this.subjective,
    required this.objective,
    required this.assessment,
    required this.plan,
    required this.recommendedTasks,
  });

  Map<String, dynamic> toJson() => {
        'patient_id': patientId,
        'session_id': sessionId,
        'subjective': subjective,
        'objective': objective,
        'assessment': assessment,
        'plan': plan,
        'recommended_tasks': recommendedTasks,
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
  });

  factory ClinicalNoteResponseDto.fromJson(Map<String, dynamic> json) {
    final soap = json['soap_notes'] as Map<String, dynamic>?;
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
    );
  }
}

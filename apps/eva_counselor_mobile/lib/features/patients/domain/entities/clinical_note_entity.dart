class ClinicalNoteEntity {
  final String id;
  final String patientId;
  final String sessionId;
  final DateTime createdAt;
  final String subjective; // Keluhan pasien
  final String objective; // Observasi afek & perilaku
  final String assessment; // Analisis klinis
  final String plan; // Terapi lanjutan & PR
  final List<String> recommendedTasks;

  const ClinicalNoteEntity({
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
}

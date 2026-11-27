import 'coping_exercise_definition.dart';

/// Tutorial payload displayed inside the entry modal on coping exercise pages.
class CopingTutorialData {
  final String title;
  final String category;
  final String duration;
  final String difficulty;
  final String description;
  final String rationale;
  final List<String> instructions;
  final bool isCompleted;

  const CopingTutorialData({
    required this.title,
    required this.category,
    required this.duration,
    required this.difficulty,
    required this.description,
    required this.rationale,
    required this.instructions,
    this.isCompleted = false,
  });

  factory CopingTutorialData.fromDefinition(
    CopingExerciseDefinition definition, {
    String difficulty = 'Pemula',
    bool isCompleted = false,
  }) {
    return CopingTutorialData(
      title: definition.title,
      category: definition.category,
      duration: definition.estimatedDurationLabel,
      difficulty: difficulty,
      description: definition.subtitle,
      rationale: definition.defaultRationale,
      instructions: definition.defaultInstructions,
      isCompleted: isCompleted,
    );
  }
}

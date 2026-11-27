/// Lifecycle completion outcome returned by a coping exercise route.
enum CopingSessionStatus { completed, cancelled }

/// Typed result emitted when leaving an interactive coping exercise.
class CopingSessionResult {
  final String exerciseId;
  final CopingSessionStatus status;
  final Duration elapsed;
  final bool isVisualOnly;

  const CopingSessionResult({
    required this.exerciseId,
    required this.status,
    required this.elapsed,
    this.isVisualOnly = false,
  });

  const CopingSessionResult.completed({
    required String exerciseId,
    required Duration elapsed,
    bool isVisualOnly = false,
  }) : this(
         exerciseId: exerciseId,
         status: CopingSessionStatus.completed,
         elapsed: elapsed,
         isVisualOnly: isVisualOnly,
       );

  const CopingSessionResult.cancelled({
    required String exerciseId,
    required Duration elapsed,
    bool isVisualOnly = false,
  }) : this(
         exerciseId: exerciseId,
         status: CopingSessionStatus.cancelled,
         elapsed: elapsed,
         isVisualOnly: isVisualOnly,
       );

  bool get isCompleted => status == CopingSessionStatus.completed;
}

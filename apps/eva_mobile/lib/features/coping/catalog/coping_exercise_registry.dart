import '../exercises/breathing/breathing.dart';
import '../exercises/gratitude_journal/gratitude_journal.dart';
import '../exercises/grounding_54321/grounding_54321.dart';
import '../exercises/mindful_walk/mindful_walk.dart';
import '../exercises/notice_and_name/notice_and_name.dart';
import '../exercises/stop_think_go/stop_think_go.dart';
import '../shared/domain/coping_exercise_definition.dart';
import '../shared/domain/coping_exercise_id.dart';

/// Composition root registering every independent coping exercise module.
/// Catalog depends solely on public entry descriptors, never module internals.
class CopingExerciseRegistry {
  CopingExerciseRegistry._();

  static final List<CopingExerciseDefinition> all = List.unmodifiable([
    BreathingExerciseModule.definition,
    Grounding54321Exercise.definition,
    GratitudeJournalExercise.definition,
    NoticeAndNameExercise.definition,
    StopThinkGoExercise.definition,
    MindfulWalkExercise.definition,
  ]);

  static final Map<String, CopingExerciseDefinition> _byId = (() {
    final map = <String, CopingExerciseDefinition>{};
    for (final def in all) {
      assert(
        !map.containsKey(def.id),
        'Duplicate coping exercise id: ${def.id}',
      );
      map[def.id] = def;
    }
    return Map<String, CopingExerciseDefinition>.unmodifiable(map);
  })();

  static CopingExerciseDefinition? findById(String id) => _byId[id];

  static CopingExerciseDefinition? findByRawRecommendation({
    String? rawId,
    String? category,
    String? title,
  }) {
    final canonicalId = CopingExerciseId.fromRaw(
      rawId,
      category: category,
      title: title,
    );
    if (canonicalId == null) return null;
    return _byId[canonicalId];
  }
}

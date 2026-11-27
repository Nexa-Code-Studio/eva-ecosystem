# EVA Mobile Coping Exercises Module Architecture

## Structure
- `catalog/`: Typed metadata registry (`CopingExerciseRegistry`) and catalog page (`CopingCatalogPage`, `/coping`). Catalog knows only public `CopingExerciseDefinition` descriptors and route names.
- `shared/`: Canonical ID mapping (`CopingExerciseId`), session outcomes (`CopingSessionResult`), and shared guidance shell for text/step modules (`CopingGuidanceSheet`, `CopingStepExercisePage`).
- `exercises/`: Self-contained per-exercise modules (`breathing`, `grounding_54321`, `gratitude_journal`, `notice_and_name`, `stop_think_go`, `mindful_walk`). No exercise imports another exercise's internals.

## Adding a New Coping Exercise
1. Create `lib/features/coping/exercises/<exercise_id>/` with its public entry descriptor (`CopingExerciseDefinition`), UI/domain/state, local tests under `test/features/coping/exercises/<exercise_id>/`, and any local assets.
2. Add its route in `lib/core/routes/app_router.dart`.
3. Register its `definition` in `CopingExerciseRegistry.all` (`catalog/coping_exercise_registry.dart`).
   - Do not modify `exercises/breathing/` when adding new exercises.

## Guided Breathing Assets & ElevenLabs Audio Workflow
Currently **no ElevenLabs MP3 or `.riv` asset is bundled** in `assets/coping/breathing/`, so `BreathingExperiencePage` automatically runs in explicit **Visual-Only Mode** using `BreathingTimeline.defaultGuidedId()` (`4s` preparation, 4 cycles of `4s` inhale / `4s` exhale, `4s` outro).

To attach an approved production narration later:
1. Outside the mobile app, generate Indonesian speech clips with an authorized EVA voice on ElevenLabs (no runtime API calls or keys in the client) and assemble them with clean silence intervals into `assets/coping/breathing/audio/guided_breathing_id.mp3`.
2. Measure the actual audible cue onsets/endpoints on the assembled waveform (including encoder padding) and save the matching timeline at `assets/coping/breathing/timelines/guided_breathing_id.json` using schema v1 (`schemaVersion: 1`, contiguous `[startMs, endMs)` segments, exact `durationMs` matching measured audio duration within +/-150 ms).
3. Register both asset files under `flutter.assets` in `apps/eva_mobile/pubspec.yaml` and run unit/widget + device audition checks to confirm cue synchronization.
4. Notice: `BreathingHumanPainter` renders native layered Flutter paths cleanly when no `.riv` file exists. If a verified authored `.riv` illustration is later supplied, feed `motionListenable.value.breathAmount` (`0.0..1.0`) directly into the numeric Rive input rather than using an independent animation loop.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eva_mobile/core/routes/app_router.dart';
import 'package:eva_mobile/features/coping/catalog/coping_exercise_registry.dart';
import 'package:eva_mobile/features/coping/shared/domain/coping_exercise_id.dart';

void main() {
  group('CopingExerciseRegistry & Module Isolation', () {
    test(
      'all registered coping exercise IDs and routes are unique and resolve cleanly',
      () {
        final exercises = CopingExerciseRegistry.all;
        expect(exercises.length, 6);

        final ids = exercises.map((e) => e.id).toSet();
        final routes = exercises.map((e) => e.routeName).toSet();
        expect(ids.length, exercises.length);
        expect(routes.length, exercises.length);

        for (final exercise in exercises) {
          final route = AppRouter.onGenerateRoute(
            RouteSettings(name: exercise.routeName),
          );
          expect(
            route,
            isNotNull,
            reason: '${exercise.routeName} must resolve',
          );
        }

        expect(
          AppRouter.onGenerateRoute(const RouteSettings(name: '/coping')),
          isNotNull,
        );
      },
    );

    test(
      'preserves all legacy recommendation IDs and maps cleanly via registry',
      () {
        const expectedMappings = <String, String>{
          'c1': CopingExerciseId.breathing,
          'rec_1': CopingExerciseId.breathing,
          'c2': CopingExerciseId.grounding54321,
          'c3': CopingExerciseId.gratitudeJournal,
          'rec_2': CopingExerciseId.gratitudeJournal,
          'c4': CopingExerciseId.mindfulWalk,
          'rec_3': CopingExerciseId.mindfulWalk,
          'c9': CopingExerciseId.noticeAndName,
          'c10': CopingExerciseId.stopThinkGo,
          'rec_4': CopingExerciseId.stopThinkGo,
        };

        for (final entry in expectedMappings.entries) {
          final resolved = CopingExerciseRegistry.findByRawRecommendation(
            rawId: entry.key,
          );
          expect(
            resolved?.id,
            entry.value,
            reason: 'Failed for rawId=${entry.key}',
          );
        }
      },
    );

    test('coping exercises have zero cross-exercise imports', () {
      final exercisesDir = Directory('lib/features/coping/exercises');
      expect(exercisesDir.existsSync(), isTrue);

      final exerciseDirs = exercisesDir
          .listSync()
          .whereType<Directory>()
          .toList();

      for (final dir in exerciseDirs) {
        final ownName = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
        final otherNames = exerciseDirs
            .map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last)
            .where((name) => name != ownName)
            .toList();

        for (final file in dir.listSync(recursive: true).whereType<File>()) {
          if (!file.path.endsWith('.dart')) continue;
          final contents = file.readAsStringSync();
          for (final other in otherNames) {
            expect(
              contents.contains('/$other/') || contents.contains('../$other'),
              isFalse,
              reason:
                  'Exercise $ownName (${file.path}) must not import sibling $other',
            );
          }
        }
      }
    });
  });
}

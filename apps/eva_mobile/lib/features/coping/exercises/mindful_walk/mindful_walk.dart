import 'package:flutter/material.dart';
import '../../shared/domain/coping_exercise_definition.dart';
import '../../shared/domain/coping_exercise_id.dart';

/// Isolated definition for the existing mindful walking movement module.
class MindfulWalkExercise {
  MindfulWalkExercise._();

  static const String routeName = '/coping/mindful_walk';

  static const CopingExerciseDefinition definition = CopingExerciseDefinition(
    id: CopingExerciseId.mindfulWalk,
    routeName: routeName,
    title: 'Jalan Santai Mindful',
    subtitle:
        'Berjalan santai sambil memperhatikan sensasi setiap langkah kaki.',
    category: 'Fisik & Gerak',
    estimatedDurationLabel: '10 Menit',
    icon: Icons.directions_walk_rounded,
    defaultInstructions: [
      'Berdiri tegak, rilekskan bahu dan rahangmu.',
      'Mulai melangkah dengan ritme santai dan perlahan.',
      'Fokuskan perhatian pada telapak kakimu yang menyentuh tanah pada setiap langkah.',
      'Jika pikiranmu melayang, dengan lembut bawa kembali perhatianmu pada langkah kaki.',
    ],
    defaultRationale:
        'Menggabungkan gerakan fisik ringan dengan perhatian sadar untuk menyegarkan pikiran.',
  );
}

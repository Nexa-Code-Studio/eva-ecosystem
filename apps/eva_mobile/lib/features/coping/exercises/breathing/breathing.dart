import 'package:flutter/material.dart';

import '../../shared/domain/coping_exercise_definition.dart';
import '../../shared/domain/coping_exercise_id.dart';

export 'application/breathing_controller.dart';
export 'application/breathing_state.dart';
export 'domain/breathing_phase.dart';
export 'domain/breathing_session.dart';
export 'domain/breathing_timeline.dart';
export 'infrastructure/breathing_audio_adapter.dart';
export 'infrastructure/breathing_timeline_loader.dart';
export 'presentation/pages/breathing_experience_page.dart';

/// Narrow public module entry point for the guided breathing coping exercise.
class BreathingExerciseModule {
  BreathingExerciseModule._();

  static const String routeName = '/coping/breathing';

  static const CopingExerciseDefinition definition = CopingExerciseDefinition(
    id: CopingExerciseId.breathing,
    routeName: routeName,
    title: 'Latihan Pernapasan Terpandu',
    subtitle:
        'Bernapas tenang mengikuti lingkaran pemandu (4 detik tarik, 4 detik hembus).',
    category: 'Mindfulness',
    estimatedDurationLabel: 'Sekitar 1 Menit',
    icon: Icons.air_rounded,
    hasImmersiveSession: true,
    defaultInstructions: [
      'Temukan posisi duduk atau berbaring yang nyaman.',
      'Rilekskan bahu dan rahangmu.',
      'Tarik napas perlahan selama 4 detik saat lingkaran mengecil ke pusat.',
      'Hembuskan perlahan selama 4 detik saat lingkaran membesar kembali.',
      'Berhenti kapan saja bila terasa kurang nyaman.',
    ],
    defaultRationale:
        'Memberi jeda tenang yang dapat diikuti sesuai ritme nyamanmu tanpa paksaan menahan napas.',
  );
}

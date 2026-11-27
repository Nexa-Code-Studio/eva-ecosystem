import 'package:flutter/material.dart';
import '../../shared/domain/coping_exercise_definition.dart';
import '../../shared/domain/coping_exercise_id.dart';

/// Isolated definition for the existing Stop-Think-Go problem-solving module.
class StopThinkGoExercise {
  StopThinkGoExercise._();

  static const String routeName = '/coping/stop_think_go';

  static const CopingExerciseDefinition definition = CopingExerciseDefinition(
    id: CopingExerciseId.stopThinkGo,
    routeName: routeName,
    title: 'Metode Stop-Think-Go',
    subtitle: 'Langkah terarah saat pikiran terasa menumpuk dan membebani.',
    category: 'CBT',
    estimatedDurationLabel: '5 Menit',
    icon: Icons.track_changes_rounded,
    defaultInstructions: [
      'STOP: Berhenti sejenak dari aktivitasmu, letakkan ponsel, dan ambil satu napas panjang.',
      'THINK: Uraikan apa yang sebenarnya sedang terjadi dan apa yang bisa kamu kendalikan saat ini.',
      'GO: Pilih 1 tindakan terkecil yang bisa kamu lakukan sekarang tanpa perlu menyelesaikan semuanya sekaligus.',
    ],
    defaultRationale:
        'Membantu memecah situasi berat menjadi satu langkah kecil yang terasa lebih terkendali.',
  );
}

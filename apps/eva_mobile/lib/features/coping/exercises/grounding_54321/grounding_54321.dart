import 'package:flutter/material.dart';
import '../../shared/domain/coping_exercise_definition.dart';
import '../../shared/domain/coping_exercise_id.dart';

/// Isolated definition for the existing 5-4-3-2-1 cognitive grounding module.
class Grounding54321Exercise {
  Grounding54321Exercise._();

  static const String routeName = '/coping/grounding_54321';

  static const CopingExerciseDefinition definition = CopingExerciseDefinition(
    id: CopingExerciseId.grounding54321,
    routeName: routeName,
    title: 'Teknik Grounding 5-4-3-2-1',
    subtitle:
        'Sadarilah 5 hal yang dilihat, 4 yang disentuh, 3 suara, 2 aroma, dan 1 rasa.',
    category: 'CBT',
    estimatedDurationLabel: '5 Menit',
    icon: Icons.psychology_outlined,
    defaultInstructions: [
      'Lihat ke sekitarmu: Sebutkan 5 benda yang dapat kamu lihat saat ini.',
      'Sentuh benda di dekatmu: Rasakan 4 tekstur berbeda (pakaian, meja, jari tangan).',
      'Dengarkan secara saksama: Sadari 3 suara di sekitarmu (kipas, kendaraan, napas).',
      'Hirup udara: Sadari 2 aroma di sekitarmu.',
      'Rasakan mulutmu: Sadari 1 rasa di lidahmu saat ini.',
    ],
    defaultRationale:
        'Mengalihkan fokus dari pikiran cemas berlebih kembali ke sensasi fisik saat ini.',
  );
}

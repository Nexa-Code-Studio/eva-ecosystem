import 'package:flutter/material.dart';
import '../../shared/domain/coping_exercise_definition.dart';
import '../../shared/domain/coping_exercise_id.dart';

/// Isolated definition for the existing daily gratitude reflection module.
class GratitudeJournalExercise {
  GratitudeJournalExercise._();

  static const String routeName = '/coping/gratitude_journal';

  static const CopingExerciseDefinition definition = CopingExerciseDefinition(
    id: CopingExerciseId.gratitudeJournal,
    routeName: routeName,
    title: 'Catatan Syukur Harian',
    subtitle:
        'Tuliskan hal sederhana yang memberi kehangatan atau rasa nyaman hari ini.',
    category: 'Refleksi',
    estimatedDurationLabel: '3 Menit',
    icon: Icons.edit_note_rounded,
    defaultInstructions: [
      'Ambil buku catatan kecil atau gunakan catatan di ponselmu.',
      'Pikirkan 1 hingga 3 hal kecil yang terjadi hari ini (misal: secangkir teh hangat, udara sejuk).',
      'Tuliskan secara singkat mengapa hal itu terasa bermakna bagimu.',
      'Rasakan sensasi lega dan hangat di dalam hatimu sejenak.',
    ],
    defaultRationale:
        'Membantu melatih fokus pada hal positif sederhana yang menenangkan suasana hati.',
  );
}

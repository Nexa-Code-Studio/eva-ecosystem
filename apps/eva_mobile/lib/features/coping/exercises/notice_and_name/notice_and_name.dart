import 'package:flutter/material.dart';
import '../../shared/domain/coping_exercise_definition.dart';
import '../../shared/domain/coping_exercise_id.dart';

/// Isolated definition for the existing Notice and Name cognitive defusion module.
class NoticeAndNameExercise {
  NoticeAndNameExercise._();

  static const String routeName = '/coping/notice_and_name';

  static const CopingExerciseDefinition definition = CopingExerciseDefinition(
    id: CopingExerciseId.noticeAndName,
    routeName: routeName,
    title: 'Metode Notice and Name',
    subtitle:
        'Lepaskan diri dari pikiran cemas dengan mengenali dan menamainya.',
    category: 'CBT',
    estimatedDurationLabel: '4 Menit',
    icon: Icons.psychology_alt_rounded,
    defaultInstructions: [
      'Ketika pikiran cemas muncul, berhenti sejenak tanpa menghakiminya.',
      'Katakan pada diri sendiri: "Aku sedang menyadari pikiran bahwa..."',
      'Ingat bahwa pikiran hanyalah kata-kata atau gambaran mental, bukan fakta pasti.',
      'Bernapas perlahan dan biarkan pikiran tersebut berlalu seperti awan di langit.',
    ],
    defaultRationale:
        'Membantu menjaga jarak sehat dari pikiran berulang agar tidak terasa membebani.',
  );
}

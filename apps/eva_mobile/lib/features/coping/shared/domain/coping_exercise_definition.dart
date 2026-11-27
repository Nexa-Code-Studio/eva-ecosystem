import 'package:flutter/material.dart';

/// Immutable metadata descriptor registered by each isolated coping exercise module.
class CopingExerciseDefinition {
  final String id;
  final String routeName;
  final String title;
  final String subtitle;
  final String category;
  final String estimatedDurationLabel;
  final IconData icon;
  final bool hasImmersiveSession;
  final List<String> defaultInstructions;
  final String defaultRationale;

  const CopingExerciseDefinition({
    required this.id,
    required this.routeName,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.estimatedDurationLabel,
    required this.icon,
    this.hasImmersiveSession = false,
    this.defaultInstructions = const [],
    this.defaultRationale = '',
  });
}

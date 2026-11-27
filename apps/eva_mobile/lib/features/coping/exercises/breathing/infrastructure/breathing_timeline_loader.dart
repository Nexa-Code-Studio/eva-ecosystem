import 'package:flutter/services.dart';

import '../domain/breathing_session.dart';
import '../domain/breathing_timeline.dart';

/// Loaded breathing exercise program paired with explicit timing authority metadata.
class BreathingLoadedProgram {
  final BreathingTimeline timeline;
  final BreathingGuidanceSource source;
  final String? audioUnavailableReason;

  const BreathingLoadedProgram({
    required this.timeline,
    required this.source,
    this.audioUnavailableReason,
  });
}

/// Resolves validated breathing timelines and verifies whether production MP3 assets exist.
class BreathingTimelineLoader {
  static const String defaultTimelineAsset =
      'assets/coping/breathing/timelines/guided_breathing_id.json';

  final AssetBundle _bundle;

  BreathingTimelineLoader({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  /// Attempts to load and validate [timelineAsset] and checks whether its referenced
  /// audio asset is bundled; falls back explicitly to visual-only guidance if absent.
  Future<BreathingLoadedProgram> loadProgram({
    String timelineAsset = defaultTimelineAsset,
    bool forceVisualOnly = false,
  }) async {
    if (forceVisualOnly) {
      return BreathingLoadedProgram(
        timeline: BreathingTimeline.defaultGuidedId(),
        source: BreathingGuidanceSource.visualOnly,
        audioUnavailableReason: 'Berjalan dalam mode panduan visual.',
      );
    }

    String rawJson;
    try {
      rawJson = await _bundle.loadString(timelineAsset);
    } catch (_) {
      return BreathingLoadedProgram(
        timeline: BreathingTimeline.defaultGuidedId(),
        source: BreathingGuidanceSource.visualOnly,
        audioUnavailableReason:
            'Narasi audio belum tersedia di paket aplikasi; memakai panduan visual.',
      );
    }

    final timeline = BreathingTimeline.fromJsonString(rawJson);
    final audioPath = timeline.audioAsset;
    if (audioPath == null || audioPath.isEmpty) {
      return BreathingLoadedProgram(
        timeline: timeline,
        source: BreathingGuidanceSource.visualOnly,
        audioUnavailableReason:
            'Narasi audio belum tersedia; memakai panduan visual.',
      );
    }

    final hasAudioAsset = await _assetExists(audioPath);
    if (!hasAudioAsset) {
      return BreathingLoadedProgram(
        timeline: timeline,
        source: BreathingGuidanceSource.visualOnly,
        audioUnavailableReason:
            'File narasi MP3 ($audioPath) belum tersedia; memakai panduan visual.',
      );
    }

    return BreathingLoadedProgram(
      timeline: timeline,
      source: BreathingGuidanceSource.audioGuided,
    );
  }

  Future<bool> _assetExists(String assetPath) async {
    try {
      final data = await _bundle.load(assetPath);
      return data.lengthInBytes > 0;
    } catch (_) {
      return false;
    }
  }
}

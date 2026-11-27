/// Canonical coping exercise IDs and helpers mapping legacy recommendation IDs.
class CopingExerciseId {
  CopingExerciseId._();

  static const String breathing = 'breathing';
  static const String grounding54321 = 'grounding_54321';
  static const String gratitudeJournal = 'gratitude_journal';
  static const String noticeAndName = 'notice_and_name';
  static const String stopThinkGo = 'stop_think_go';
  static const String mindfulWalk = 'mindful_walk';

  static const Map<String, String> _legacyIdAliases = {
    'c1': breathing,
    'rec_1': breathing,
    'c2': grounding54321,
    'c3': gratitudeJournal,
    'rec_2': gratitudeJournal,
    'c4': mindfulWalk,
    'rec_3': mindfulWalk,
    'c9': noticeAndName,
    'c10': stopThinkGo,
    'rec_4': stopThinkGo,
  };

  /// Maps raw recommendation or legacy IDs to a canonical coping module ID,
  /// returning null when an unknown ad-hoc recommendation does not match a dedicated module.
  static String? fromRaw(String? rawId, {String? category, String? title}) {
    final normalizedId = (rawId ?? '').trim().toLowerCase();
    if (_legacyIdAliases.containsKey(normalizedId)) {
      return _legacyIdAliases[normalizedId];
    }

    switch (normalizedId) {
      case breathing:
      case grounding54321:
      case gratitudeJournal:
      case noticeAndName:
      case stopThinkGo:
      case mindfulWalk:
        return normalizedId;
    }

    final normalizedTitle = (title ?? '').toLowerCase();
    final normalizedCat = (category ?? '').toLowerCase();
    if (normalizedTitle.contains('napas') ||
        normalizedTitle.contains('breath') ||
        normalizedCat == 'breathing' ||
        normalizedCat.contains('napas')) {
      return breathing;
    }
    if (normalizedTitle.contains('grounding') ||
        normalizedTitle.contains('5-4-3-2-1')) {
      return grounding54321;
    }
    if (normalizedTitle.contains('syukur') ||
        normalizedTitle.contains('refleksi')) {
      return gratitudeJournal;
    }
    if (normalizedTitle.contains('notice and name')) {
      return noticeAndName;
    }
    if (normalizedTitle.contains('stop-think-go') ||
        normalizedTitle.contains('reframing')) {
      return stopThinkGo;
    }
    if (normalizedTitle.contains('jalan')) {
      return mindfulWalk;
    }

    return null;
  }
}

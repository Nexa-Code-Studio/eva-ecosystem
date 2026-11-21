import '../../domain/entities/memory_item_entity.dart';

/// Selects bounded, relevant memory context items (maximum 3–5) for session personalization.
class MemoryContextSelector {
  static const int defaultMaxItems = 5;

  /// Selects up to [maxItems] active memory items prioritizing high-utility categories
  /// (`interaction_preference`, `coping_strategy`, and recency).
  List<MemoryItemEntity> selectContext(
    List<MemoryItemEntity> allItems, {
    int maxItems = defaultMaxItems,
    String? currentInput,
  }) {
    // 1. Filter only active, non-deleted items
    final activeItems = allItems.where((item) => item.status == MemoryStatus.active && !item.isDeleted).toList();

    if (activeItems.isEmpty) return [];

    // 2. Score items based on category priority, recency, and simple keyword matching
    final scored = activeItems.map((item) {
      double score = 0.0;

      // Category Weighting
      switch (item.category) {
        case MemoryCategory.interactionPreference:
          score += 50.0;
          break;
        case MemoryCategory.copingStrategy:
          score += 40.0;
          break;
        case MemoryCategory.psychologicalComplaint:
          score += 30.0;
          break;
        case MemoryCategory.emotionalTrigger:
          score += 25.0;
          break;
        case MemoryCategory.professionalDiagnosis:
          score += 20.0;
          break;
        case MemoryCategory.socialSupport:
          score += 15.0;
          break;
      }

      // Recency Weighting (last confirmed within 30 days receives bonus)
      final referenceDate = item.lastConfirmedAt ?? item.updatedAt;
      final daysAgo = DateTime.now().difference(referenceDate).inDays;
      if (daysAgo < 7) {
        score += 20.0;
      } else if (daysAgo < 30) {
        score += 10.0;
      }

      // Keyword match with current input if provided
      if (currentInput != null && currentInput.isNotEmpty) {
        final inputWords = currentInput.toLowerCase().split(RegExp(r'\s+'));
        final factWords = item.factText.toLowerCase().split(RegExp(r'\s+'));
        final matches = factWords.where((w) => w.length > 3 && inputWords.contains(w)).length;
        score += (matches * 15.0);
      }

      return MapEntry(item, score);
    }).toList();

    // 3. Sort by score descending
    scored.sort((a, b) => b.value.compareTo(a.value));

    // 4. Return top bounded slice
    final takeCount = maxItems > 0 ? maxItems : defaultMaxItems;
    return scored.take(takeCount).map((e) => e.key).toList();
  }
}

import '../../domain/entities/memory_item_entity.dart';

class MemoryValidationResult {
  final bool isValid;
  final String? rejectionReason;
  final MemoryItemEntity? sanitizedEntity;

  const MemoryValidationResult.valid(this.sanitizedEntity)
      : isValid = true,
        rejectionReason = null;

  const MemoryValidationResult.invalid(this.rejectionReason)
      : isValid = false,
        sanitizedEntity = null;
}

/// Validates memory candidates extracted after a session before prompting user confirmation.
class MemoryCandidateValidator {
  static const int maxFactLength = 500;

  static final List<RegExp> _injectionPatterns = [
    RegExp(r'ignore\s+(all\s+)?(previous\s+)?instructions', caseSensitive: false),
    RegExp(r'system\s*:', caseSensitive: false),
    RegExp(r'you\s+are\s+now\s+a', caseSensitive: false),
    RegExp(r'sekarang\s+kamu\s+adalah', caseSensitive: false),
    RegExp(r'abaikan\s+(seluruh\s+)?instruksi', caseSensitive: false),
  ];

  /// Validates a raw memory item candidate.
  MemoryValidationResult validate(MemoryItemEntity candidate) {
    final text = candidate.factText.trim();

    if (text.isEmpty) {
      return const MemoryValidationResult.invalid('Teks fakta memori tidak boleh kosong.');
    }

    if (text.length > maxFactLength) {
      return MemoryValidationResult.invalid(
        'Panjang fakta ($text.length) melebihi batas maksimal $maxFactLength karakter.',
      );
    }

    // Check for prompt injection attempts
    for (final pattern in _injectionPatterns) {
      if (pattern.hasMatch(text)) {
        return const MemoryValidationResult.invalid(
          'Terdeteksi pola teks yang melanggar kebijakan keamanan instruksi AI.',
        );
      }
    }

    // Enforce diagnosis constraint: AI extraction cannot declare verified diagnosis
    var sourceVerification = candidate.sourceVerification;
    if (candidate.category == MemoryCategory.professionalDiagnosis &&
        candidate.sourceType == MemorySourceType.assistantCandidate) {
      // Must be downgraded to unverified until user confirms
      sourceVerification = MemorySourceVerification.unverified;
    }

    final sanitized = candidate.copyWith(
      factText: text,
      sourceVerification: sourceVerification,
    );

    return MemoryValidationResult.valid(sanitized);
  }
}

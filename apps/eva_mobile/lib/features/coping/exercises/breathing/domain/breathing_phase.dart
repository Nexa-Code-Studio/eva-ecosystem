/// Discrete guided breathing phases supported by timeline schema v1.
enum BreathingPhase {
  preparation,
  inhale,
  exhale,
  outro;

  static BreathingPhase? tryParse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'preparation':
        return BreathingPhase.preparation;
      case 'inhale':
        return BreathingPhase.inhale;
      case 'exhale':
        return BreathingPhase.exhale;
      case 'outro':
        return BreathingPhase.outro;
      default:
        return null;
    }
  }

  /// Primary localized heading displayed in the lower HUD.
  String get localizedTitle {
    switch (this) {
      case BreathingPhase.preparation:
        return 'Siapkan dirimu';
      case BreathingPhase.inhale:
        return 'Tarik napas';
      case BreathingPhase.exhale:
        return 'Hembuskan napas';
      case BreathingPhase.outro:
        return 'Latihan selesai';
    }
  }

  /// Secondary calm instruction under the phase heading.
  String get localizedInstruction {
    switch (this) {
      case BreathingPhase.preparation:
        return 'Temukan posisi nyaman. Berhenti kapan saja jika merasa pusing.';
      case BreathingPhase.inhale:
        return 'Perlahan melalui hidung';
      case BreathingPhase.exhale:
        return 'Lepaskan perlahan melalui mulut';
      case BreathingPhase.outro:
        return 'Kembali bernapas seperti biasa dengan tenang';
    }
  }

  /// Screen-reader announcement spoken once on phase transition.
  String get accessibilityAnnouncement =>
      '$localizedTitle. $localizedInstruction';
}

enum MemoryCategory {
  psychologicalComplaint('psychological_complaint', 'Keluhan Psikologis'),
  emotionalTrigger('emotional_trigger', 'Pemicu Emosi'),
  copingStrategy('coping_strategy', 'Strategi Coping'),
  professionalDiagnosis('professional_diagnosis', 'Diagnosis Profesional'),
  socialSupport('social_support', 'Dukungan Sosial'),
  interactionPreference('interaction_preference', 'Preferensi Interaksi');

  final String value;
  final String label;
  const MemoryCategory(this.value, this.label);

  static MemoryCategory fromString(String raw) {
    return MemoryCategory.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => MemoryCategory.psychologicalComplaint,
    );
  }
}

enum MemoryStatus {
  pendingConfirmation('pending_confirmation', 'Menunggu Konfirmasi'),
  active('active', 'Aktif'),
  historical('historical', 'Historis / Membaik'),
  needsReview('needs_review', 'Perlu Ditinjau');

  final String value;
  final String label;
  const MemoryStatus(this.value, this.label);

  static MemoryStatus fromString(String raw) {
    return MemoryStatus.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => MemoryStatus.pendingConfirmation,
    );
  }
}

enum MemorySourceType {
  userReported('user_reported'),
  clinicianDocument('clinician_document'),
  assistantCandidate('assistant_candidate');

  final String value;
  const MemorySourceType(this.value);

  static MemorySourceType fromString(String raw) {
    return MemorySourceType.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => MemorySourceType.userReported,
    );
  }
}

enum MemorySourceVerification {
  unverified('unverified', 'Belum Terverifikasi'),
  userConfirmed('user_confirmed', 'Dikonfirmasi Pasien'),
  verifiedDocument('verified_document', 'Dokumen Terverifikasi');

  final String value;
  final String label;
  const MemorySourceVerification(this.value, this.label);

  static MemorySourceVerification fromString(String raw) {
    return MemorySourceVerification.values.firstWhere(
      (e) => e.value == raw,
      orElse: () => MemorySourceVerification.unverified,
    );
  }
}

class MemoryItemEntity {
  final String id;
  final String localAccountKey;
  final MemoryCategory category;
  final String factText;
  final MemoryStatus status;
  final MemorySourceType sourceType;
  final MemorySourceVerification sourceVerification;
  final String? sourceSessionId;
  final String? sourceJournalId;
  final String? consentRecordId;
  final String sensitivity;
  final DateTime firstSeenAt;
  final DateTime? lastConfirmedAt;
  final DateTime? reviewDueAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  const MemoryItemEntity({
    required this.id,
    required this.localAccountKey,
    required this.category,
    required this.factText,
    required this.status,
    required this.sourceType,
    required this.sourceVerification,
    this.sourceSessionId,
    this.sourceJournalId,
    this.consentRecordId,
    this.sensitivity = 'health',
    required this.firstSeenAt,
    this.lastConfirmedAt,
    this.reviewDueAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  bool get isDeleted => deletedAt != null;

  MemoryItemEntity copyWith({
    String? id,
    String? localAccountKey,
    MemoryCategory? category,
    String? factText,
    MemoryStatus? status,
    MemorySourceType? sourceType,
    MemorySourceVerification? sourceVerification,
    String? sourceSessionId,
    String? sourceJournalId,
    String? consentRecordId,
    String? sensitivity,
    DateTime? firstSeenAt,
    DateTime? lastConfirmedAt,
    DateTime? reviewDueAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return MemoryItemEntity(
      id: id ?? this.id,
      localAccountKey: localAccountKey ?? this.localAccountKey,
      category: category ?? this.category,
      factText: factText ?? this.factText,
      status: status ?? this.status,
      sourceType: sourceType ?? this.sourceType,
      sourceVerification: sourceVerification ?? this.sourceVerification,
      sourceSessionId: sourceSessionId ?? this.sourceSessionId,
      sourceJournalId: sourceJournalId ?? this.sourceJournalId,
      consentRecordId: consentRecordId ?? this.consentRecordId,
      sensitivity: sensitivity ?? this.sensitivity,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      lastConfirmedAt: lastConfirmedAt ?? this.lastConfirmedAt,
      reviewDueAt: reviewDueAt ?? this.reviewDueAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}

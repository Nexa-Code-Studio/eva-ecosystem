import '../../domain/entities/memory_item_entity.dart';

class MemoryItemModel extends MemoryItemEntity {
  const MemoryItemModel({
    required super.id,
    required super.localAccountKey,
    required super.category,
    required super.factText,
    required super.status,
    required super.sourceType,
    required super.sourceVerification,
    super.sourceSessionId,
    super.sourceJournalId,
    super.consentRecordId,
    super.sensitivity = 'health',
    required super.firstSeenAt,
    super.lastConfirmedAt,
    super.reviewDueAt,
    required super.createdAt,
    required super.updatedAt,
    super.deletedAt,
  });

  factory MemoryItemModel.fromMap(Map<String, dynamic> map) {
    return MemoryItemModel(
      id: map['id'] as String,
      localAccountKey: map['local_account_key'] as String,
      category: MemoryCategory.fromString(map['category'] as String),
      factText: map['fact_text'] as String,
      status: MemoryStatus.fromString(map['status'] as String),
      sourceType: MemorySourceType.fromString(map['source_type'] as String),
      sourceVerification: MemorySourceVerification.fromString(map['source_verification'] as String),
      sourceSessionId: map['source_session_id'] as String?,
      sourceJournalId: map['source_journal_id'] as String?,
      consentRecordId: map['consent_record_id'] as String?,
      sensitivity: (map['sensitivity'] as String?) ?? 'health',
      firstSeenAt: DateTime.parse(map['first_seen_at'] as String),
      lastConfirmedAt: map['last_confirmed_at'] != null ? DateTime.parse(map['last_confirmed_at'] as String) : null,
      reviewDueAt: map['review_due_at'] != null ? DateTime.parse(map['review_due_at'] as String) : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      deletedAt: map['deleted_at'] != null ? DateTime.parse(map['deleted_at'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'local_account_key': localAccountKey,
      'category': category.value,
      'fact_text': factText,
      'status': status.value,
      'source_type': sourceType.value,
      'source_verification': sourceVerification.value,
      'source_session_id': sourceSessionId,
      'source_journal_id': sourceJournalId,
      'consent_record_id': consentRecordId,
      'sensitivity': sensitivity,
      'first_seen_at': firstSeenAt.toIso8601String(),
      'last_confirmed_at': lastConfirmedAt?.toIso8601String(),
      'review_due_at': reviewDueAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  factory MemoryItemModel.fromEntity(MemoryItemEntity entity) {
    return MemoryItemModel(
      id: entity.id,
      localAccountKey: entity.localAccountKey,
      category: entity.category,
      factText: entity.factText,
      status: entity.status,
      sourceType: entity.sourceType,
      sourceVerification: entity.sourceVerification,
      sourceSessionId: entity.sourceSessionId,
      sourceJournalId: entity.sourceJournalId,
      consentRecordId: entity.consentRecordId,
      sensitivity: entity.sensitivity,
      firstSeenAt: entity.firstSeenAt,
      lastConfirmedAt: entity.lastConfirmedAt,
      reviewDueAt: entity.reviewDueAt,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      deletedAt: entity.deletedAt,
    );
  }
}

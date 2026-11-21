class MemoryConsentEntity {
  final String id;
  final String localAccountKey;
  final String scope; // memory_persist | cloud_context | clinical_share
  final String policyVersion;
  final DateTime? grantedAt;
  final DateTime? revokedAt;
  final String consentSnapshotJson;
  final DateTime createdAt;

  const MemoryConsentEntity({
    required this.id,
    required this.localAccountKey,
    required this.scope,
    required this.policyVersion,
    this.grantedAt,
    this.revokedAt,
    required this.consentSnapshotJson,
    required this.createdAt,
  });

  bool get isGranted => grantedAt != null && revokedAt == null;
}

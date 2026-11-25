class BankItemEntity {
  final String code;
  final String name;

  const BankItemEntity({
    required this.code,
    required this.name,
  });
}

class BankValidationEntity {
  final String validationId;
  final String bankCode;
  final String bankName;
  final String accountNumberMasked;
  final String accountHolderName;
  final String status; // verified | not_found | review_required | unavailable
  final String nameMatch; // matched | mismatch | review_required | unknown
  final DateTime? expiresAt;

  const BankValidationEntity({
    required this.validationId,
    required this.bankCode,
    required this.bankName,
    required this.accountNumberMasked,
    required this.accountHolderName,
    required this.status,
    required this.nameMatch,
    this.expiresAt,
  });

  bool get isVerified => status == 'verified' && nameMatch == 'matched';
  bool get isNotFound => status == 'not_found';
  bool get isMismatch => nameMatch == 'mismatch';
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
}

class BankAccountEntity {
  final String id;
  final String bankCode;
  final String bankName;
  final String accountNumberMasked;
  final String accountHolderName;
  final String verificationStatus; // unverified | verified | review_required | inactive | rejected
  final DateTime? verifiedAt;
  final bool isActive;

  const BankAccountEntity({
    required this.id,
    required this.bankCode,
    required this.bankName,
    required this.accountNumberMasked,
    required this.accountHolderName,
    required this.verificationStatus,
    this.verifiedAt,
    this.isActive = true,
  });

  bool get isVerified => verificationStatus == 'verified';
  bool get isUnverified => verificationStatus == 'unverified';
}

import '../../domain/entities/bank_account_entity.dart';

class BankItemDto {
  final String code;
  final String name;

  const BankItemDto({
    required this.code,
    required this.name,
  });

  factory BankItemDto.fromJson(Map<String, dynamic> json) {
    return BankItemDto(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
      };

  BankItemEntity toEntity() => BankItemEntity(code: code, name: name);
}

class BankValidationDto {
  final String validationId;
  final String bankCode;
  final String bankName;
  final String accountNumberMasked;
  final String accountHolderName;
  final String status;
  final String nameMatch;
  final String? expiresAt;

  const BankValidationDto({
    required this.validationId,
    required this.bankCode,
    required this.bankName,
    required this.accountNumberMasked,
    required this.accountHolderName,
    required this.status,
    required this.nameMatch,
    this.expiresAt,
  });

  factory BankValidationDto.fromJson(Map<String, dynamic> json) {
    return BankValidationDto(
      validationId: json['validation_id']?.toString() ?? '',
      bankCode: json['bank_code']?.toString() ?? '',
      bankName: json['bank_name']?.toString() ?? '',
      accountNumberMasked: json['account_number_masked']?.toString() ?? '',
      accountHolderName: json['account_holder_name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'unavailable',
      nameMatch: json['name_match']?.toString() ?? 'unknown',
      expiresAt: json['expires_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'validation_id': validationId,
        'bank_code': bankCode,
        'bank_name': bankName,
        'account_number_masked': accountNumberMasked,
        'account_holder_name': accountHolderName,
        'status': status,
        'name_match': nameMatch,
        'expires_at': expiresAt,
      };

  BankValidationEntity toEntity() => BankValidationEntity(
        validationId: validationId,
        bankCode: bankCode,
        bankName: bankName,
        accountNumberMasked: accountNumberMasked,
        accountHolderName: accountHolderName,
        status: status,
        nameMatch: nameMatch,
        expiresAt: expiresAt != null ? DateTime.tryParse(expiresAt!) : null,
      );
}

class BankAccountDto {
  final String id;
  final String bankCode;
  final String bankName;
  final String accountNumberMasked;
  final String accountHolderName;
  final String verificationStatus;
  final String? verifiedAt;
  final bool isActive;

  const BankAccountDto({
    required this.id,
    required this.bankCode,
    required this.bankName,
    required this.accountNumberMasked,
    required this.accountHolderName,
    required this.verificationStatus,
    this.verifiedAt,
    this.isActive = true,
  });

  factory BankAccountDto.fromJson(Map<String, dynamic> json) {
    return BankAccountDto(
      id: json['id']?.toString() ?? '',
      bankCode: json['bank_code']?.toString() ?? '',
      bankName: json['bank_name']?.toString() ?? '',
      accountNumberMasked: json['account_number_masked']?.toString() ?? '',
      accountHolderName: json['account_holder_name']?.toString() ?? '',
      verificationStatus: json['verification_status']?.toString() ?? 'unverified',
      verifiedAt: json['verified_at']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'bank_code': bankCode,
        'bank_name': bankName,
        'account_number_masked': accountNumberMasked,
        'account_holder_name': accountHolderName,
        'verification_status': verificationStatus,
        'verified_at': verifiedAt,
        'is_active': isActive,
      };

  BankAccountEntity toEntity() => BankAccountEntity(
        id: id,
        bankCode: bankCode,
        bankName: bankName,
        accountNumberMasked: accountNumberMasked,
        accountHolderName: accountHolderName,
        verificationStatus: verificationStatus,
        verifiedAt: verifiedAt != null ? DateTime.tryParse(verifiedAt!) : null,
        isActive: isActive,
      );
}

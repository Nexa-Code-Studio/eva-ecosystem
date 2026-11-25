import '../../domain/entities/payout_entity.dart';
import 'bank_account_dto.dart';

class PayoutPolicyDto {
  final int minAmountIdr;
  final int maxAmountIdr;
  final int feeIdr;
  final int dailyLimitIdr;
  final bool isPayoutEnabled;

  const PayoutPolicyDto({
    required this.minAmountIdr,
    required this.maxAmountIdr,
    required this.feeIdr,
    required this.dailyLimitIdr,
    required this.isPayoutEnabled,
  });

  factory PayoutPolicyDto.fromJson(Map<String, dynamic> json) {
    return PayoutPolicyDto(
      minAmountIdr: (json['min_amount_idr'] as num?)?.toInt() ?? 50000,
      maxAmountIdr: (json['max_amount_idr'] as num?)?.toInt() ?? 10000000,
      feeIdr: (json['fee_idr'] as num?)?.toInt() ?? 5000,
      dailyLimitIdr: (json['daily_limit_idr'] as num?)?.toInt() ?? 20000000,
      isPayoutEnabled: json['is_payout_enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'min_amount_idr': minAmountIdr,
        'max_amount_idr': maxAmountIdr,
        'fee_idr': feeIdr,
        'daily_limit_idr': dailyLimitIdr,
        'is_payout_enabled': isPayoutEnabled,
      };

  PayoutPolicyEntity toEntity() => PayoutPolicyEntity(
        minAmountIdr: minAmountIdr,
        maxAmountIdr: maxAmountIdr,
        feeIdr: feeIdr,
        dailyLimitIdr: dailyLimitIdr,
        isPayoutEnabled: isPayoutEnabled,
      );
}

class PayoutQuoteDto {
  final String quoteId;
  final String bankAccountId;
  final int amountIdr;
  final int feeIdr;
  final String feeBearer;
  final int netAmountIdr;
  final int walletDebitIdr;
  final String expiresAt;
  final String currency;

  const PayoutQuoteDto({
    required this.quoteId,
    required this.bankAccountId,
    required this.amountIdr,
    required this.feeIdr,
    required this.feeBearer,
    required this.netAmountIdr,
    required this.walletDebitIdr,
    required this.expiresAt,
    this.currency = 'IDR',
  });

  factory PayoutQuoteDto.fromJson(Map<String, dynamic> json) {
    return PayoutQuoteDto(
      quoteId: json['quote_id']?.toString() ?? '',
      bankAccountId: json['bank_account_id']?.toString() ?? '',
      amountIdr: (json['amount_idr'] as num?)?.toInt() ?? 0,
      feeIdr: (json['fee_idr'] as num?)?.toInt() ?? 0,
      feeBearer: json['fee_bearer']?.toString() ?? 'counselor',
      netAmountIdr: (json['net_amount_idr'] as num?)?.toInt() ?? 0,
      walletDebitIdr: (json['wallet_debit_idr'] as num?)?.toInt() ?? 0,
      expiresAt: json['expires_at']?.toString() ?? DateTime.now().toIso8601String(),
      currency: json['currency']?.toString() ?? 'IDR',
    );
  }

  Map<String, dynamic> toJson() => {
        'quote_id': quoteId,
        'bank_account_id': bankAccountId,
        'amount_idr': amountIdr,
        'fee_idr': feeIdr,
        'fee_bearer': feeBearer,
        'net_amount_idr': netAmountIdr,
        'wallet_debit_idr': walletDebitIdr,
        'expires_at': expiresAt,
        'currency': currency,
      };

  PayoutQuoteEntity toEntity() => PayoutQuoteEntity(
        quoteId: quoteId,
        bankAccountId: bankAccountId,
        amountIdr: amountIdr,
        feeIdr: feeIdr,
        feeBearer: feeBearer,
        netAmountIdr: netAmountIdr,
        walletDebitIdr: walletDebitIdr,
        expiresAt: DateTime.tryParse(expiresAt) ?? DateTime.now(),
        currency: currency,
      );
}

class PayoutRecordDto {
  final String id;
  final String referenceId;
  final String status;
  final int amountIdr;
  final int feeIdr;
  final String feeBearer;
  final int netAmountIdr;
  final int walletDebitIdr;
  final String currency;
  final BankAccountDto? bankAccount;
  final String createdAt;
  final String updatedAt;
  final String? completedAt;
  final String? failureCode;
  final String? failureMessage;

  const PayoutRecordDto({
    required this.id,
    required this.referenceId,
    required this.status,
    required this.amountIdr,
    required this.feeIdr,
    required this.feeBearer,
    required this.netAmountIdr,
    required this.walletDebitIdr,
    required this.currency,
    this.bankAccount,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.failureCode,
    this.failureMessage,
  });

  factory PayoutRecordDto.fromJson(Map<String, dynamic> json) {
    return PayoutRecordDto(
      id: json['id']?.toString() ?? '',
      referenceId: json['reference_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'requested',
      amountIdr: (json['amount_idr'] as num?)?.toInt() ?? 0,
      feeIdr: (json['fee_idr'] as num?)?.toInt() ?? 0,
      feeBearer: json['fee_bearer']?.toString() ?? 'counselor',
      netAmountIdr: (json['net_amount_idr'] as num?)?.toInt() ?? 0,
      walletDebitIdr: (json['wallet_debit_idr'] as num?)?.toInt() ?? 0,
      currency: json['currency']?.toString() ?? 'IDR',
      bankAccount: json['bank_account'] != null && json['bank_account'] is Map<String, dynamic>
          ? BankAccountDto.fromJson(json['bank_account'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      updatedAt: json['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
      completedAt: json['completed_at']?.toString(),
      failureCode: json['failure_code']?.toString(),
      failureMessage: json['failure_message']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'reference_id': referenceId,
        'status': status,
        'amount_idr': amountIdr,
        'fee_idr': feeIdr,
        'fee_bearer': feeBearer,
        'net_amount_idr': netAmountIdr,
        'wallet_debit_idr': walletDebitIdr,
        'currency': currency,
        'bank_account': bankAccount?.toJson(),
        'created_at': createdAt,
        'updated_at': updatedAt,
        'completed_at': completedAt,
        'failure_code': failureCode,
        'failure_message': failureMessage,
      };

  PayoutRecordEntity toEntity() => PayoutRecordEntity(
        id: id,
        referenceId: referenceId,
        status: status,
        amountIdr: amountIdr,
        feeIdr: feeIdr,
        feeBearer: feeBearer,
        netAmountIdr: netAmountIdr,
        walletDebitIdr: walletDebitIdr,
        currency: currency,
        bankAccount: bankAccount?.toEntity(),
        createdAt: DateTime.tryParse(createdAt) ?? DateTime.now(),
        updatedAt: DateTime.tryParse(updatedAt) ?? DateTime.now(),
        completedAt: completedAt != null ? DateTime.tryParse(completedAt!) : null,
        failureCode: failureCode,
        failureMessage: failureMessage,
      );
}

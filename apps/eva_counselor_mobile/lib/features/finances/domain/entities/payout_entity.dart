import 'bank_account_entity.dart';

class PayoutPolicyEntity {
  final int minAmountIdr;
  final int maxAmountIdr;
  final int feeIdr;
  final int dailyLimitIdr;
  final bool isPayoutEnabled;

  const PayoutPolicyEntity({
    required this.minAmountIdr,
    required this.maxAmountIdr,
    required this.feeIdr,
    required this.dailyLimitIdr,
    required this.isPayoutEnabled,
  });
}

class PayoutQuoteEntity {
  final String quoteId;
  final String bankAccountId;
  final int amountIdr;
  final int feeIdr;
  final String feeBearer;
  final int netAmountIdr;
  final int walletDebitIdr;
  final DateTime expiresAt;
  final String currency;

  const PayoutQuoteEntity({
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

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class PayoutRecordEntity {
  final String id;
  final String referenceId;
  final String status; // requested | waiting_approval | processing | completed | failed | rejected | cancelled | reversed | review_required
  final int amountIdr;
  final int feeIdr;
  final String feeBearer;
  final int netAmountIdr;
  final int walletDebitIdr;
  final String currency;
  final BankAccountEntity? bankAccount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final String? failureCode;
  final String? failureMessage;

  const PayoutRecordEntity({
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

  String get statusIndonesianLabel {
    switch (status.toLowerCase()) {
      case 'requested':
        return 'Diajukan';
      case 'waiting_approval':
        return 'Menunggu Persetujuan';
      case 'processing':
        return 'Sedang Diproses';
      case 'completed':
        return 'Berhasil Dikirim';
      case 'failed':
        return 'Gagal';
      case 'rejected':
        return 'Ditolak';
      case 'cancelled':
        return 'Dibatalkan';
      case 'reversed':
        return 'Dikembalikan';
      case 'review_required':
        return 'Perlu Peninjauan';
      default:
        return status;
    }
  }

  bool get isTerminalSuccess => status.toLowerCase() == 'completed';
  bool get isTerminalFailure =>
      status.toLowerCase() == 'failed' ||
      status.toLowerCase() == 'rejected' ||
      status.toLowerCase() == 'cancelled';
  bool get isPendingOrProcessing =>
      status.toLowerCase() == 'requested' ||
      status.toLowerCase() == 'waiting_approval' ||
      status.toLowerCase() == 'processing' ||
      status.toLowerCase() == 'review_required';
}

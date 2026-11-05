import '../../domain/entities/transaction_entity.dart';

class FinancialSummaryResponseDto {
  final int availableBalance;
  final int pendingClearingBalance;
  final int totalEarningsThisMonth;
  final int totalWithdrawn;

  const FinancialSummaryResponseDto({
    required this.availableBalance,
    required this.pendingClearingBalance,
    required this.totalEarningsThisMonth,
    required this.totalWithdrawn,
  });

  factory FinancialSummaryResponseDto.fromJson(Map<String, dynamic> json) {
    return FinancialSummaryResponseDto(
      availableBalance: json['available_balance'] as int? ?? 0,
      pendingClearingBalance: json['pending_clearing_balance'] as int? ?? 0,
      totalEarningsThisMonth: json['total_earnings_this_month'] as int? ?? 0,
      totalWithdrawn: json['total_withdrawn'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'available_balance': availableBalance,
        'pending_clearing_balance': pendingClearingBalance,
        'total_earnings_this_month': totalEarningsThisMonth,
        'total_withdrawn': totalWithdrawn,
      };

  FinancialSummaryEntity toEntity() {
    return FinancialSummaryEntity(
      availableBalance: availableBalance,
      pendingClearingBalance: pendingClearingBalance,
      totalEarningsThisMonth: totalEarningsThisMonth,
      totalWithdrawn: totalWithdrawn,
    );
  }
}

class TransactionResponseDto {
  final String id;
  final String patientName;
  final String sessionType;
  final String date;
  final int amount;
  final int adminFee;
  final int netEarnings;
  final String status;
  final String? bankAccountInfo;

  const TransactionResponseDto({
    required this.id,
    required this.patientName,
    required this.sessionType,
    required this.date,
    required this.amount,
    required this.adminFee,
    required this.netEarnings,
    required this.status,
    this.bankAccountInfo,
  });

  factory TransactionResponseDto.fromJson(Map<String, dynamic> json) {
    return TransactionResponseDto(
      id: json['id']?.toString() ?? '',
      patientName: json['patient_name']?.toString() ?? 'Pasien',
      sessionType: json['session_type']?.toString() ?? 'Konsultasi Video 50 Menit',
      date: json['date']?.toString() ?? DateTime.now().toIso8601String(),
      amount: json['amount'] as int? ?? 0,
      adminFee: json['admin_fee'] as int? ?? 0,
      netEarnings: json['net_earnings'] as int? ?? 0,
      status: json['status']?.toString() ?? 'completed',
      bankAccountInfo: json['bank_account_info']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patient_name': patientName,
        'session_type': sessionType,
        'date': date,
        'amount': amount,
        'admin_fee': adminFee,
        'net_earnings': netEarnings,
        'status': status,
        'bank_account_info': bankAccountInfo,
      };

  TransactionEntity toEntity() {
    TransactionStatus s;
    switch (status.toLowerCase()) {
      case 'pending':
        s = TransactionStatus.pending;
        break;
      case 'payout_requested':
        s = TransactionStatus.payoutRequested;
        break;
      case 'refunded':
        s = TransactionStatus.refunded;
        break;
      case 'completed':
      default:
        s = TransactionStatus.completed;
        break;
    }

    return TransactionEntity(
      id: id,
      patientName: patientName,
      sessionType: sessionType,
      date: DateTime.tryParse(date) ?? DateTime.now(),
      amount: amount,
      adminFee: adminFee,
      netEarnings: netEarnings,
      status: s,
      bankAccountInfo: bankAccountInfo,
    );
  }
}

enum TransactionStatus { completed, pending, payoutRequested, refunded }

class FinancialSummaryEntity {
  final int availableBalance; // Rp saldo siap tarik
  final int pendingClearingBalance; // Rp menunggu kliring
  final int totalEarningsThisMonth; // Rp total bulan ini
  final int totalWithdrawn; // Rp sudah ditarik

  const FinancialSummaryEntity({
    required this.availableBalance,
    required this.pendingClearingBalance,
    required this.totalEarningsThisMonth,
    required this.totalWithdrawn,
  });
}

class TransactionEntity {
  final String id;
  final String patientName;
  final String sessionType; // e.g. 'Telekonsultasi Video 50 Menit'
  final DateTime date;
  final int amount; // Rp
  final int adminFee; // Rp
  final int netEarnings; // Rp
  final TransactionStatus status;
  final String? bankAccountInfo;

  const TransactionEntity({
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
}

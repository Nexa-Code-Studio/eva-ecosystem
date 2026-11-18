import '../models/transaction_dto.dart';
import 'finance_datasource.dart';

class MockFinanceDataSource implements FinanceDataSource {
  @override
  Future<FinancialSummaryResponseDto> fetchSummary() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const FinancialSummaryResponseDto(
      availableBalance: 2450000,
      pendingClearingBalance: 400000,
      totalEarningsThisMonth: 4850000,
      totalWithdrawn: 2000000,
    );
  }

  @override
  Future<List<TransactionResponseDto>> fetchTransactions() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return [
      TransactionResponseDto(
        id: 'TRX-2026-0091',
        patientName: 'Rian Pratama',
        sessionType: 'Telekonsultasi Video (30 Menit)',
        date: DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
        amount: 150000,
        adminFee: 30000,
        netEarnings: 120000,
        status: 'completed',
      ),
      TransactionResponseDto(
        id: 'TRX-2026-0089',
        patientName: 'Rian Pratama',
        sessionType: 'Perpanjangan In-Call (+30 Menit)',
        date: DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
        amount: 150000,
        adminFee: 30000,
        netEarnings: 120000,
        status: 'completed',
      ),
      TransactionResponseDto(
        id: 'TRX-2026-0084',
        patientName: 'Dinda Kirana',
        sessionType: 'Telekonsultasi Video Darurat (30 Menit)',
        date: DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        amount: 150000,
        adminFee: 30000,
        netEarnings: 120000,
        status: 'completed',
      ),
      TransactionResponseDto(
        id: 'TRX-2026-0072',
        patientName: 'Maya Lestari',
        sessionType: 'Sesi Evaluasi Kognitif CBT (30 Menit)',
        date: DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        amount: 150000,
        adminFee: 30000,
        netEarnings: 120000,
        status: 'completed',
      ),
      TransactionResponseDto(
        id: 'TRX-2026-0060',
        patientName: 'Penarikan Dana (BCA ****8192)',
        sessionType: 'Transfer Bank Pencairan Honorarium',
        date: DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
        amount: 1500000,
        adminFee: 0,
        netEarnings: 1500000,
        status: 'payout_requested',
        bankAccountInfo: 'BCA • dr. Sarah Jenkins, M.Psi • 8192039182',
      ),
    ];
  }

  @override
  Future<bool> submitPayoutRequest(Map<String, dynamic> payload) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return true;
  }
}

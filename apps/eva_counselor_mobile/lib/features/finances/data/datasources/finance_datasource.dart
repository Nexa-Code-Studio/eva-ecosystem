import '../models/transaction_dto.dart';

abstract class FinanceDataSource {
  Future<FinancialSummaryResponseDto> fetchSummary();
  Future<List<TransactionResponseDto>> fetchTransactions();
  Future<bool> submitPayoutRequest(Map<String, dynamic> payload);
}

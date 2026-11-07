import '../entities/transaction_entity.dart';

abstract class IFinanceRepository {
  Future<FinancialSummaryEntity> getSummary();
  Future<List<TransactionEntity>> getTransactions();
  Future<bool> requestPayout({
    required int amount,
    required String bankName,
    required String accountNumber,
    required String accountHolderName,
  });
}

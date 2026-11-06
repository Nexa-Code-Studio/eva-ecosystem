import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/finance_repository.dart';
import '../datasources/finance_datasource.dart';

class FinanceRepositoryImpl implements IFinanceRepository {
  final FinanceDataSource _dataSource;

  FinanceRepositoryImpl({required FinanceDataSource dataSource})
      : _dataSource = dataSource;

  @override
  Future<FinancialSummaryEntity> getSummary() async {
    final dto = await _dataSource.fetchSummary();
    return dto.toEntity();
  }

  @override
  Future<List<TransactionEntity>> getTransactions() async {
    final list = await _dataSource.fetchTransactions();
    return list.map((dto) => dto.toEntity()).toList();
  }

  @override
  Future<bool> requestPayout({
    required int amount,
    required String bankName,
    required String accountNumber,
    required String accountHolderName,
  }) async {
    return await _dataSource.submitPayoutRequest({
      'amount': amount,
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_holder_name': accountHolderName,
    });
  }
}

import '../../domain/entities/bank_account_entity.dart';
import '../../domain/entities/payout_entity.dart';
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
  Future<List<BankItemEntity>> getSupportedBanks() async {
    final list = await _dataSource.fetchSupportedBanks();
    return list.map((dto) => dto.toEntity()).toList();
  }

  @override
  Future<BankValidationEntity> validateBankAccount({
    required String bankCode,
    required String accountNumber,
  }) async {
    final dto = await _dataSource.validateBankAccount(
      bankCode: bankCode,
      accountNumber: accountNumber,
    );
    return dto.toEntity();
  }

  @override
  Future<BankAccountEntity?> getCurrentBankAccount() async {
    final dto = await _dataSource.fetchCurrentBankAccount();
    return dto?.toEntity();
  }

  @override
  Future<BankAccountEntity> saveCurrentBankAccount({
    required String validationId,
  }) async {
    final dto = await _dataSource.saveCurrentBankAccount(
      validationId: validationId,
    );
    return dto.toEntity();
  }

  @override
  Future<PayoutPolicyEntity> getPayoutPolicy() async {
    final dto = await _dataSource.fetchPayoutPolicy();
    return dto.toEntity();
  }

  @override
  Future<PayoutQuoteEntity> createPayoutQuote({
    required String bankAccountId,
    required int amountIdr,
  }) async {
    final dto = await _dataSource.createPayoutQuote(
      bankAccountId: bankAccountId,
      amountIdr: amountIdr,
    );
    return dto.toEntity();
  }

  @override
  Future<PayoutRecordEntity> submitPayout({
    required String quoteId,
    required String idempotencyKey,
  }) async {
    final dto = await _dataSource.submitPayout(
      quoteId: quoteId,
      idempotencyKey: idempotencyKey,
    );
    return dto.toEntity();
  }

  @override
  Future<PayoutRecordEntity> getPayoutDetail(String payoutId) async {
    final dto = await _dataSource.fetchPayoutDetail(payoutId);
    return dto.toEntity();
  }

  @override
  Future<List<PayoutRecordEntity>> getPayouts() async {
    final list = await _dataSource.fetchPayouts();
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

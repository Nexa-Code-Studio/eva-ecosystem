import '../entities/bank_account_entity.dart';
import '../entities/payout_entity.dart';
import '../entities/transaction_entity.dart';

abstract class IFinanceRepository {
  Future<FinancialSummaryEntity> getSummary();
  Future<List<TransactionEntity>> getTransactions();

  // Bank Account & Inquiry (Issue #137)
  Future<List<BankItemEntity>> getSupportedBanks();
  Future<BankValidationEntity> validateBankAccount({
    required String bankCode,
    required String accountNumber,
  });
  Future<BankAccountEntity?> getCurrentBankAccount();
  Future<BankAccountEntity> saveCurrentBankAccount({
    required String validationId,
  });

  // Payout Policy & Idempotent Execution (Issue #137)
  Future<PayoutPolicyEntity> getPayoutPolicy();
  Future<PayoutQuoteEntity> createPayoutQuote({
    required String bankAccountId,
    required int amountIdr,
  });
  Future<PayoutRecordEntity> submitPayout({
    required String quoteId,
    required String idempotencyKey,
  });
  Future<PayoutRecordEntity> getPayoutDetail(String payoutId);
  Future<List<PayoutRecordEntity>> getPayouts();

  // Backward compatibility helper
  Future<bool> requestPayout({
    required int amount,
    required String bankName,
    required String accountNumber,
    required String accountHolderName,
  });
}

import '../models/bank_account_dto.dart';
import '../models/payout_dto.dart';
import '../models/transaction_dto.dart';

abstract class FinanceDataSource {
  Future<FinancialSummaryResponseDto> fetchSummary();
  Future<List<TransactionResponseDto>> fetchTransactions();

  // Bank Account & Inquiry (Issue #137)
  Future<List<BankItemDto>> fetchSupportedBanks();
  Future<BankValidationDto> validateBankAccount({
    required String bankCode,
    required String accountNumber,
  });
  Future<BankAccountDto?> fetchCurrentBankAccount();
  Future<BankAccountDto> saveCurrentBankAccount({
    required String validationId,
  });

  // Payout Policy & Execution (Issue #137)
  Future<PayoutPolicyDto> fetchPayoutPolicy();
  Future<PayoutQuoteDto> createPayoutQuote({
    required String bankAccountId,
    required int amountIdr,
  });
  Future<PayoutRecordDto> submitPayout({
    required String quoteId,
    required String idempotencyKey,
  });
  Future<PayoutRecordDto> fetchPayoutDetail(String payoutId);
  Future<List<PayoutRecordDto>> fetchPayouts();

  // Backward compatibility
  Future<bool> submitPayoutRequest(Map<String, dynamic> payload);
}

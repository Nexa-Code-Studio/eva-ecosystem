import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/bank_account_dto.dart';
import '../models/payout_dto.dart';
import '../models/transaction_dto.dart';
import 'finance_datasource.dart';

class RemoteFinanceDataSource implements FinanceDataSource {
  final ApiClient _client;

  RemoteFinanceDataSource({ApiClient? client}) : _client = client ?? ApiClient();

  @override
  Future<FinancialSummaryResponseDto> fetchSummary() async {
    final response = await _client.get(ApiEndpoints.financialSummary);
    return FinancialSummaryResponseDto.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<List<TransactionResponseDto>> fetchTransactions() async {
    final response = await _client.get(ApiEndpoints.transactions);
    if (response is List<dynamic>) {
      return response
          .map((t) => TransactionResponseDto.fromJson(t as Map<String, dynamic>))
          .toList();
    }
    if (response is Map<String, dynamic> && response['items'] is List<dynamic>) {
      return (response['items'] as List<dynamic>)
          .map((t) => TransactionResponseDto.fromJson(t as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  @override
  Future<List<BankItemDto>> fetchSupportedBanks() async {
    final response = await _client.get(ApiEndpoints.supportedBanks);
    if (response is List<dynamic>) {
      return response
          .map((b) => BankItemDto.fromJson(b as Map<String, dynamic>))
          .toList();
    }
    if (response is Map<String, dynamic> && response['items'] is List<dynamic>) {
      return (response['items'] as List<dynamic>)
          .map((b) => BankItemDto.fromJson(b as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  @override
  Future<BankValidationDto> validateBankAccount({
    required String bankCode,
    required String accountNumber,
  }) async {
    final response = await _client.post(
      ApiEndpoints.validateBankAccount,
      body: {
        'bank_code': bankCode,
        'account_number': accountNumber,
      },
    );
    return BankValidationDto.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<BankAccountDto?> fetchCurrentBankAccount() async {
    try {
      final response = await _client.get(ApiEndpoints.currentBankAccount);
      if (response == null) return null;
      if (response is Map<String, dynamic>) {
        if (response.containsKey('bank_account') && response['bank_account'] != null) {
          return BankAccountDto.fromJson(response['bank_account'] as Map<String, dynamic>);
        }
        if (response.containsKey('id') || response.containsKey('bank_code')) {
          return BankAccountDto.fromJson(response);
        }
      }
      return null;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<BankAccountDto> saveCurrentBankAccount({required String validationId}) async {
    final response = await _client.put(
      ApiEndpoints.currentBankAccount,
      body: {'validation_id': validationId},
    );
    if (response is Map<String, dynamic>) {
      if (response.containsKey('bank_account') && response['bank_account'] != null) {
        return BankAccountDto.fromJson(response['bank_account'] as Map<String, dynamic>);
      }
      return BankAccountDto.fromJson(response);
    }
    throw ApiException(
      statusCode: 500,
      message: 'Format respon penyimpanan rekening bank tidak valid.',
    );
  }

  @override
  Future<PayoutPolicyDto> fetchPayoutPolicy() async {
    final response = await _client.get(ApiEndpoints.payoutPolicy);
    return PayoutPolicyDto.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<PayoutQuoteDto> createPayoutQuote({
    required String bankAccountId,
    required int amountIdr,
  }) async {
    final response = await _client.post(
      ApiEndpoints.createPayoutQuote,
      body: {
        'bank_account_id': bankAccountId,
        'amount_idr': amountIdr,
      },
    );
    return PayoutQuoteDto.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<PayoutRecordDto> submitPayout({
    required String quoteId,
    required String idempotencyKey,
  }) async {
    final response = await _client.post(
      ApiEndpoints.requestPayout,
      body: {'quote_id': quoteId},
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return PayoutRecordDto.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<PayoutRecordDto> fetchPayoutDetail(String payoutId) async {
    final response = await _client.get(ApiEndpoints.payoutDetail(payoutId));
    return PayoutRecordDto.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<List<PayoutRecordDto>> fetchPayouts() async {
    final response = await _client.get(ApiEndpoints.payoutsHistory);
    if (response is List<dynamic>) {
      return response
          .map((p) => PayoutRecordDto.fromJson(p as Map<String, dynamic>))
          .toList();
    }
    if (response is Map<String, dynamic> && response['items'] is List<dynamic>) {
      return (response['items'] as List<dynamic>)
          .map((p) => PayoutRecordDto.fromJson(p as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  @override
  Future<bool> submitPayoutRequest(Map<String, dynamic> payload) async {
    final response = await _client.post(ApiEndpoints.requestPayout, body: payload);
    return (response as Map<String, dynamic>?)?['success'] as bool? ?? true;
  }
}

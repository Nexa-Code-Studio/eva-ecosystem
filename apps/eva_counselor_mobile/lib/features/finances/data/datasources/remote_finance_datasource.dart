import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
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
    return (response as List<dynamic>)
        .map((t) => TransactionResponseDto.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<bool> submitPayoutRequest(Map<String, dynamic> payload) async {
    final response = await _client.post(ApiEndpoints.requestPayout, body: payload);
    return (response as Map<String, dynamic>?)?['success'] as bool? ?? true;
  }
}

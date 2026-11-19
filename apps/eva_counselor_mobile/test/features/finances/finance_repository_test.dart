import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eva_counselor_mobile/core/network/api_client.dart';
import 'package:eva_counselor_mobile/features/finances/data/datasources/mock_finance_datasource.dart';
import 'package:eva_counselor_mobile/features/finances/data/datasources/remote_finance_datasource.dart';
import 'package:eva_counselor_mobile/features/finances/data/repositories/finance_repository_impl.dart';
import 'package:eva_counselor_mobile/features/finances/domain/entities/transaction_entity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FinanceRepository Tests (Mock)', () {
    late FinanceRepositoryImpl repository;
    late MockFinanceDataSource mockDataSource;

    setUp(() {
      mockDataSource = MockFinanceDataSource();
      repository = FinanceRepositoryImpl(dataSource: mockDataSource);
    });

    test('getSummary returns accurate balance breakdown', () async {
      final summary = await repository.getSummary();
      expect(summary.availableBalance, 2450000);
      expect(summary.pendingClearingBalance, 400000);
      expect(summary.totalEarningsThisMonth, 4850000);
    });

    test('getTransactions returns list with net earnings and status', () async {
      final transactions = await repository.getTransactions();
      expect(transactions.isNotEmpty, true);
      expect(transactions.first.status, TransactionStatus.completed);
      expect(transactions.first.netEarnings, 120000);
    });

    test('requestPayout succeeds with valid banking parameters', () async {
      final result = await repository.requestPayout(
        amount: 2000000,
        bankName: 'BCA',
        accountNumber: '8192039182',
        accountHolderName: 'Sarah Anindya',
      );
      expect(result, true);
    });
  });

  group('RemoteFinanceDataSource Tests (Live API Contract)', () {
    test('fetchSummary queries /finances/summary and parses DTO', () async {
      final mockHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/finances/summary')) {
          return http.Response(
            jsonEncode({
              'available_balance': 3500000,
              'pending_clearing_balance': 150000,
              'total_earnings_this_month': 5000000,
              'total_withdrawn': 1500000,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final apiClient = ApiClient(client: mockHttpClient);
      final remoteSource = RemoteFinanceDataSource(client: apiClient);
      final summary = await remoteSource.fetchSummary();

      expect(summary.availableBalance, 3500000);
      expect(summary.pendingClearingBalance, 150000);
      expect(summary.totalEarningsThisMonth, 5000000);
      expect(summary.totalWithdrawn, 1500000);
    });

    test('fetchTransactions queries /finances/transactions and parses list', () async {
      final mockHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/finances/transactions')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'TRX-2026-0099',
                'patient_name': 'Budi Santoso',
                'session_type': 'Telekonsultasi Video (30 Menit)',
                'date': '2026-11-18T10:00:00Z',
                'amount': 150000,
                'admin_fee': 30000,
                'net_earnings': 120000,
                'status': 'completed',
              }
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final apiClient = ApiClient(client: mockHttpClient);
      final remoteSource = RemoteFinanceDataSource(client: apiClient);
      final transactions = await remoteSource.fetchTransactions();

      expect(transactions.length, 1);
      expect(transactions.first.id, 'TRX-2026-0099');
      expect(transactions.first.netEarnings, 120000);
    });

    test('submitPayoutRequest sends payload to /finances/payout', () async {
      final mockHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/finances/payout')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['amount'], 1000000);
          expect(body['bank_name'], 'Mandiri');
          return http.Response(
            jsonEncode({'success': true, 'transaction_id': 'TRX-2026-WD01', 'message': 'OK'}),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final apiClient = ApiClient(client: mockHttpClient);
      final remoteSource = RemoteFinanceDataSource(client: apiClient);
      final success = await remoteSource.submitPayoutRequest({
        'amount': 1000000,
        'bank_name': 'Mandiri',
        'account_number': '1234567890',
        'account_holder_name': 'Sarah Anindya',
      });

      expect(success, true);
    });
  });
}

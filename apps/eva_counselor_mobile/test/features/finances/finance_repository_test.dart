import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eva_counselor_mobile/core/network/api_client.dart';
import 'package:eva_counselor_mobile/features/finances/data/datasources/mock_finance_datasource.dart';
import 'package:eva_counselor_mobile/features/finances/data/datasources/remote_finance_datasource.dart';
import 'package:eva_counselor_mobile/features/finances/data/models/bank_account_dto.dart';
import 'package:eva_counselor_mobile/features/finances/data/models/payout_dto.dart';
import 'package:eva_counselor_mobile/features/finances/data/repositories/finance_repository_impl.dart';
import 'package:eva_counselor_mobile/features/finances/domain/entities/transaction_entity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DTO Serialization & Mapping Tests (Contracts C1, C3, C4)', () {
    test('BankItemDto parses from and to JSON accurately', () {
      final json = {'code': 'bca', 'name': 'Bank Central Asia'};
      final dto = BankItemDto.fromJson(json);
      expect(dto.code, 'bca');
      expect(dto.name, 'Bank Central Asia');
      expect(dto.toJson(), json);
      final entity = dto.toEntity();
      expect(entity.code, 'bca');
    });

    test('BankValidationDto parses verified and mismatch states', () {
      final verifiedJson = {
        'validation_id': 'val-uuid-1',
        'bank_code': 'mandiri',
        'bank_name': 'Bank Mandiri',
        'account_number_masked': '****3333',
        'account_holder_name': 'BUDI SANTOSO',
        'status': 'verified',
        'name_match': 'matched',
        'expires_at': '2026-11-25T02:10:00Z',
      };
      final dto = BankValidationDto.fromJson(verifiedJson);
      expect(dto.validationId, 'val-uuid-1');
      expect(dto.status, 'verified');
      expect(dto.nameMatch, 'matched');

      final entity = dto.toEntity();
      expect(entity.isVerified, true);
      expect(entity.isMismatch, false);
      expect(entity.isNotFound, false);
    });

    test('BankAccountDto parses active verified bank account', () {
      final accountJson = {
        'id': 'bank-acc-uuid-1',
        'bank_code': 'mandiri',
        'bank_name': 'Bank Mandiri',
        'account_number_masked': '****3333',
        'account_holder_name': 'BUDI SANTOSO',
        'verification_status': 'verified',
        'verified_at': '2026-11-25T02:01:00Z',
        'is_active': true,
      };
      final dto = BankAccountDto.fromJson(accountJson);
      expect(dto.id, 'bank-acc-uuid-1');
      expect(dto.verificationStatus, 'verified');
      final entity = dto.toEntity();
      expect(entity.isVerified, true);
      expect(entity.isUnverified, false);
    });

    test('PayoutQuoteDto and PolicyDto parse accurately with fees and expiration', () {
      final policyJson = {
        'min_amount_idr': 50000,
        'max_amount_idr': 10000000,
        'fee_idr': 5000,
        'daily_limit_idr': 20000000,
        'is_payout_enabled': true,
      };
      final policyDto = PayoutPolicyDto.fromJson(policyJson);
      expect(policyDto.minAmountIdr, 50000);
      expect(policyDto.feeIdr, 5000);

      final quoteJson = {
        'quote_id': 'quote-uuid-1',
        'bank_account_id': 'bank-acc-uuid-1',
        'amount_idr': 250000,
        'fee_idr': 5000,
        'fee_bearer': 'counselor',
        'net_amount_idr': 245000,
        'wallet_debit_idr': 250000,
        'expires_at': '2026-11-25T02:10:00Z',
        'currency': 'IDR',
      };
      final quoteDto = PayoutQuoteDto.fromJson(quoteJson);
      expect(quoteDto.netAmountIdr, 245000);
      expect(quoteDto.walletDebitIdr, 250000);
    });

    test('PayoutRecordEntity status mapping produces accurate Indonesian labels', () {
      final payoutJson = {
        'id': 'withdrawal-uuid',
        'reference_id': 'EVA-WD-001',
        'status': 'waiting_approval',
        'amount_idr': 250000,
        'fee_idr': 5000,
        'fee_bearer': 'counselor',
        'net_amount_idr': 245000,
        'wallet_debit_idr': 250000,
        'currency': 'IDR',
        'bank_account': {
          'id': 'bank-account-uuid',
          'bank_code': 'mandiri',
          'bank_name': 'Bank Mandiri',
          'account_number_masked': '****3333',
          'account_holder_name': 'BUDI SANTOSO',
        },
        'created_at': '2026-11-25T02:02:00Z',
        'updated_at': '2026-11-25T02:02:00Z',
      };
      final dto = PayoutRecordDto.fromJson(payoutJson);
      final entity = dto.toEntity();
      expect(entity.statusIndonesianLabel, 'Menunggu Persetujuan');
      expect(entity.isPendingOrProcessing, true);
      expect(entity.isTerminalSuccess, false);
    });
  });

  group('FinanceRepository Tests (Mock & Clean Architecture)', () {
    late FinanceRepositoryImpl repository;
    late MockFinanceDataSource mockDataSource;

    setUp(() {
      mockDataSource = MockFinanceDataSource();
      repository = FinanceRepositoryImpl(dataSource: mockDataSource);
    });

    test('getSummary returns accurate balance breakdown matching C4 fixture', () async {
      final summary = await repository.getSummary();
      expect(summary.availableBalance, 850000);
      expect(summary.pendingClearingBalance, 127500);
      expect(summary.lockedWithdrawalBalance, 0);
      expect(summary.totalEarningsThisMonth, 977500);
    });

    test('getSupportedBanks returns list of valid Indonesian banks', () async {
      final banks = await repository.getSupportedBanks();
      expect(banks.isNotEmpty, true);
      expect(banks.any((b) => b.code == 'bca'), true);
      expect(banks.any((b) => b.code == 'mandiri'), true);
    });

    test('validateBankAccount returns verified for valid account and not_found for dummy 0s', () async {
      final valid = await repository.validateBankAccount(
        bankCode: 'mandiri',
        accountNumber: '1234567890',
      );
      expect(valid.isVerified, true);
      expect(valid.accountHolderName, 'BUDI SANTOSO');

      final notFound = await repository.validateBankAccount(
        bankCode: 'mandiri',
        accountNumber: '0000000000',
      );
      expect(notFound.isNotFound, true);
      expect(notFound.isVerified, false);

      final mismatch = await repository.validateBankAccount(
        bankCode: 'mandiri',
        accountNumber: '9999999999',
      );
      expect(mismatch.isMismatch, true);
      expect(mismatch.isVerified, false);
    });

    test('getCurrentBankAccount and saveCurrentBankAccount persist verified bank', () async {
      final current = await repository.getCurrentBankAccount();
      expect(current, isNotNull);
      expect(current!.isVerified, true);
      expect(current.bankCode, 'mandiri');

      final val = await repository.validateBankAccount(bankCode: 'bca', accountNumber: '8830192831');
      final saved = await repository.saveCurrentBankAccount(validationId: val.validationId);
      expect(saved.bankCode, 'bca');
      expect(saved.isVerified, true);
    });

    test('createPayoutQuote and submitPayout execute with balance locking and idempotency', () async {
      final policy = await repository.getPayoutPolicy();
      expect(policy.isPayoutEnabled, true);

      final current = await repository.getCurrentBankAccount();
      final quote = await repository.createPayoutQuote(
        bankAccountId: current!.id,
        amountIdr: 250000,
      );
      expect(quote.amountIdr, 250000);
      expect(quote.feeIdr, 5000);
      expect(quote.netAmountIdr, 245000);

      const idempotencyKey = 'IDEMP-TEST-KEY-001';
      final payout = await repository.submitPayout(
        quoteId: quote.quoteId,
        idempotencyKey: idempotencyKey,
      );
      expect(payout.status, 'waiting_approval');
      expect(payout.amountIdr, 250000);

      // Verify balance was moved from available to locked
      final afterSummary = await repository.getSummary();
      expect(afterSummary.availableBalance, 600000); // 850000 - 250000
      expect(afterSummary.lockedWithdrawalBalance, 250000);

      // Verify Idempotency: repeated call with same key does not double-debit
      final repeatedPayout = await repository.submitPayout(
        quoteId: quote.quoteId,
        idempotencyKey: idempotencyKey,
      );
      expect(repeatedPayout.id, payout.id);
      final repeatedSummary = await repository.getSummary();
      expect(repeatedSummary.availableBalance, 600000);
    });

    test('submitPayout throws when balance is insufficient', () async {
      final current = await repository.getCurrentBankAccount();
      final quote = await repository.createPayoutQuote(
        bankAccountId: current!.id,
        amountIdr: 10000000, // Exceeds 850000
      );

      expect(
        () => repository.submitPayout(quoteId: quote.quoteId, idempotencyKey: 'IDEMP-EXCEED'),
        throwsA(isA<Exception>()),
      );
    });

    test('getTransactions returns list with net earnings and status', () async {
      final transactions = await repository.getTransactions();
      expect(transactions.isNotEmpty, true);
      expect(transactions.first.status, TransactionStatus.completed);
      expect(transactions.first.netEarnings, 120000);
    });
  });

  group('RemoteFinanceDataSource Tests (Live API Contract & Idempotency)', () {
    test('fetchSummary queries /finances/summary and parses DTO', () async {
      final mockHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/finances/summary')) {
          return http.Response(
            jsonEncode({
              'available_balance': 850000,
              'pending_clearing_balance': 127500,
              'locked_withdrawal_balance': 0,
              'total_earnings_this_month': 977500,
              'total_withdrawn': 0,
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

      expect(summary.availableBalance, 850000);
      expect(summary.pendingClearingBalance, 127500);
      expect(summary.lockedWithdrawalBalance, 0);
    });

    test('validateBankAccount posts to /finances/bank-accounts/validate', () async {
      final mockHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/finances/bank-accounts/validate')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['bank_code'], 'mandiri');
          expect(body['account_number'], '1234567890');
          return http.Response(
            jsonEncode({
              'validation_id': 'val-uuid-99',
              'bank_code': 'mandiri',
              'bank_name': 'Bank Mandiri',
              'account_number_masked': '****7890',
              'account_holder_name': 'BUDI SANTOSO',
              'status': 'verified',
              'name_match': 'matched',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final apiClient = ApiClient(client: mockHttpClient);
      final remoteSource = RemoteFinanceDataSource(client: apiClient);
      final res = await remoteSource.validateBankAccount(bankCode: 'mandiri', accountNumber: '1234567890');

      expect(res.validationId, 'val-uuid-99');
      expect(res.accountHolderName, 'BUDI SANTOSO');
      expect(res.status, 'verified');
    });

    test('submitPayout sends Idempotency-Key header to /finances/payouts', () async {
      final mockHttpClient = MockClient((request) async {
        if (request.url.path.endsWith('/finances/payouts')) {
          expect(request.headers['Idempotency-Key'], 'MY-STABLE-KEY-123');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['quote_id'], 'quote-uuid-42');

          return http.Response(
            jsonEncode({
              'id': 'wd-uuid-1',
              'reference_id': 'EVA-WD-001',
              'status': 'waiting_approval',
              'amount_idr': 250000,
              'fee_idr': 5000,
              'fee_bearer': 'counselor',
              'net_amount_idr': 245000,
              'wallet_debit_idr': 250000,
              'currency': 'IDR',
              'created_at': '2026-11-25T02:02:00Z',
              'updated_at': '2026-11-25T02:02:00Z',
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not found', 404);
      });

      final apiClient = ApiClient(client: mockHttpClient);
      final remoteSource = RemoteFinanceDataSource(client: apiClient);
      final payout = await remoteSource.submitPayout(
        quoteId: 'quote-uuid-42',
        idempotencyKey: 'MY-STABLE-KEY-123',
      );

      expect(payout.referenceId, 'EVA-WD-001');
      expect(payout.status, 'waiting_approval');
    });

    test('ApiClient correctly extracts error envelope with code and message', () async {
      final mockHttpClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'detail': {
              'code': 'INSUFFICIENT_BALANCE',
              'message': 'Saldo siap tarik tidak mencukupi untuk penarikan ini.',
            }
          }),
          400,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(client: mockHttpClient);
      final remoteSource = RemoteFinanceDataSource(client: apiClient);

      try {
        await remoteSource.createPayoutQuote(bankAccountId: 'bank-1', amountIdr: 1000000);
        fail('Should throw ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 400);
        expect(e.errorCode, 'INSUFFICIENT_BALANCE');
        expect(e.message, 'Saldo siap tarik tidak mencukupi untuk penarikan ini.');
      }
    });
  });
}

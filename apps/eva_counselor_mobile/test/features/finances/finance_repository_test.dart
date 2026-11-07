import 'package:flutter_test/flutter_test.dart';
import 'package:eva_counselor_mobile/features/finances/data/datasources/mock_finance_datasource.dart';
import 'package:eva_counselor_mobile/features/finances/data/repositories/finance_repository_impl.dart';
import 'package:eva_counselor_mobile/features/finances/domain/entities/transaction_entity.dart';

void main() {
  group('FinanceRepository Tests', () {
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
      expect(transactions.first.netEarnings, 180000);
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
}

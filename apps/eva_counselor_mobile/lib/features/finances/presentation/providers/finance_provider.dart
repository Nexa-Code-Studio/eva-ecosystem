import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/finance_repository.dart';
import '../../data/datasources/finance_datasource.dart';
import '../../data/datasources/mock_finance_datasource.dart';
import '../../data/datasources/remote_finance_datasource.dart';
import '../../data/repositories/finance_repository_impl.dart';

final financeDataSourceProvider = Provider<FinanceDataSource>((ref) {
  if (AppConfig.useMockData) {
    return MockFinanceDataSource();
  }
  return RemoteFinanceDataSource();
});

final financeRepositoryProvider = Provider<IFinanceRepository>((ref) {
  final ds = ref.watch(financeDataSourceProvider);
  return FinanceRepositoryImpl(dataSource: ds);
});

final financialSummaryProvider = FutureProvider<FinancialSummaryEntity>((ref) async {
  final repo = ref.watch(financeRepositoryProvider);
  return await repo.getSummary();
});

final transactionsListProvider = FutureProvider<List<TransactionEntity>>((ref) async {
  final repo = ref.watch(financeRepositoryProvider);
  return await repo.getTransactions();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eva_mobile/config/app_config.dart';
import '../../../../features/memory/presentation/providers/memory_provider.dart';
import '../../domain/repositories/monitoring_repository.dart';
import '../../domain/entities/monitoring_data_entity.dart';
import '../../data/datasources/mock_monitoring_datasource.dart';
import '../../data/datasources/local_monitoring_datasource.dart';
import '../../data/repositories/monitoring_repository_impl.dart';

final localMonitoringDataSourceProvider = Provider<LocalMonitoringDataSource>((ref) {
  final localDb = ref.watch(encryptedLocalDatabaseProvider);
  return LocalMonitoringDataSource(localDb);
});

final monitoringRepositoryProvider = Provider<MonitoringRepository>((ref) {
  final mockRepo = MonitoringRepositoryImpl(MockMonitoringDataSource());
  final localSource = ref.watch(localMonitoringDataSourceProvider);
  final localRepo = MonitoringRepositoryImpl(localSource);

  if (AppConfig.useMockData) {
    return mockRepo;
  } else {
    // Local-First: On-device encrypted aggregation from SQLCipher is primary
    return localRepo;
  }
});

final selectedPeriodProvider = StateProvider<String>((ref) => 'today');

final monitoringDataProvider = FutureProvider<MonitoringDataEntity>((ref) async {
  final repo = ref.watch(monitoringRepositoryProvider);
  final period = ref.watch(selectedPeriodProvider);
  return repo.getMonitoringData(period);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';
import '../../domain/repositories/monitoring_repository.dart';
import '../../domain/entities/monitoring_data_entity.dart';
import '../../data/datasources/mock_monitoring_datasource.dart';
import '../../data/datasources/remote_monitoring_datasource.dart';
import '../../data/repositories/monitoring_repository_impl.dart';
import '../../data/repositories/fallback_monitoring_repository.dart';

final monitoringRepositoryProvider = Provider<MonitoringRepository>((ref) {
  final mockRepo = MonitoringRepositoryImpl(MockMonitoringDataSource());
  final remoteRepo = MonitoringRepositoryImpl(RemoteMonitoringDataSource());

  if (AppConfig.useMockData) {
    return mockRepo;
  } else if (AppConfig.useHybridFallback) {
    return FallbackMonitoringRepository(remote: remoteRepo, mock: mockRepo);
  } else {
    return remoteRepo;
  }
});

final selectedPeriodProvider = StateProvider<String>((ref) => 'today');

final monitoringDataProvider = FutureProvider<MonitoringDataEntity>((ref) async {
  final repo = ref.watch(monitoringRepositoryProvider);
  final period = ref.watch(selectedPeriodProvider);
  return repo.getMonitoringData(period);
});

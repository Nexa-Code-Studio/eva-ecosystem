import '../../domain/repositories/monitoring_repository.dart';
import '../../domain/entities/monitoring_data_entity.dart';
import '../../../../core/network/fallback_policy.dart';

class FallbackMonitoringRepository implements MonitoringRepository {
  final MonitoringRepository _remote;
  final MonitoringRepository _mock;

  FallbackMonitoringRepository({
    required MonitoringRepository remote,
    required MonitoringRepository mock,
  })  : _remote = remote,
        _mock = mock;

  @override
  Future<MonitoringDataEntity> getMonitoringData(String periodKey) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.getMonitoringData(periodKey),
      mockCall: () => _mock.getMonitoringData(periodKey),
      operationName: 'getMonitoringData($periodKey)',
    );
  }
}

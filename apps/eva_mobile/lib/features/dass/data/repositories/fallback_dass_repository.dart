import '../../domain/repositories/dass_repository.dart';
import '../../domain/entities/dass_assessment_entity.dart';
import '../../../../core/network/fallback_policy.dart';

class FallbackDASSRepository implements DASSRepository {
  final DASSRepository _remote;
  final DASSRepository _mock;

  FallbackDASSRepository({
    required DASSRepository remote,
    required DASSRepository mock,
  })  : _remote = remote,
        _mock = mock;

  @override
  Future<DASSAssessmentEntity> getTodayAssessment() {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.getTodayAssessment(),
      mockCall: () => _mock.getTodayAssessment(),
      operationName: 'getTodayAssessment',
    );
  }

  @override
  Future<DASSAssessmentEntity> updateAssessment(List<Map<String, dynamic>> items) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.updateAssessment(items),
      mockCall: () => _mock.updateAssessment(items),
      operationName: 'updateAssessment',
    );
  }

  @override
  Future<DASSAssessmentEntity> extractTodayAssessment() {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.extractTodayAssessment(),
      mockCall: () => _mock.extractTodayAssessment(),
      operationName: 'extractTodayAssessment',
    );
  }
}

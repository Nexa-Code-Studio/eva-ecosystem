import '../../../../core/network/fallback_policy.dart';
import '../../domain/entities/consultation_session_entity.dart';
import '../../domain/entities/extension_availability_entity.dart';
import '../../domain/entities/video_call_state_entity.dart';
import '../../domain/repositories/video_call_repository.dart';

class FallbackVideoCallRepository implements VideoCallRepository {
  final VideoCallRepository _remote;
  final VideoCallRepository _mock;

  FallbackVideoCallRepository({
    required VideoCallRepository remote,
    required VideoCallRepository mock,
  })  : _remote = remote,
        _mock = mock;

  @override
  Future<VideoCallStateEntity> joinCall(ConsultationSessionEntity session) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.joinCall(session),
      mockCall: () => _mock.joinCall(session),
      operationName: 'joinCall',
    );
  }

  @override
  Future<void> endCall(String sessionId) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.endCall(sessionId),
      mockCall: () => _mock.endCall(sessionId),
      operationName: 'endCall',
    );
  }

  @override
  Future<ExtensionAvailabilityEntity> checkExtensionAvailability(
      String sessionId) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.checkExtensionAvailability(sessionId),
      mockCall: () => _mock.checkExtensionAvailability(sessionId),
      operationName: 'checkExtensionAvailability',
    );
  }

  @override
  Future<ConsultationSessionEntity> extendSession(String sessionId) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.extendSession(sessionId),
      mockCall: () => _mock.extendSession(sessionId),
      operationName: 'extendSession',
    );
  }
}

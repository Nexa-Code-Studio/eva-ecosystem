import '../../domain/repositories/voice_call_repository.dart';
import '../../domain/entities/voice_session_entity.dart';
import '../../../../core/network/fallback_policy.dart';

class FallbackVoiceCallRepository implements VoiceCallRepository {
  final VoiceCallRepository _remote;
  final VoiceCallRepository _mock;

  FallbackVoiceCallRepository({
    required VoiceCallRepository remote,
    required VoiceCallRepository mock,
  })  : _remote = remote,
        _mock = mock;

  @override
  Future<VoiceSessionEntity> startCall() {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.startCall(),
      mockCall: () => _mock.startCall(),
      operationName: 'startCall',
    );
  }

  @override
  Future<VoiceSessionEntity> endCall(String sessionId, int durationSeconds) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.endCall(sessionId, durationSeconds),
      mockCall: () => _mock.endCall(sessionId, durationSeconds),
      operationName: 'endCall($sessionId)',
    );
  }

  @override
  Future<VoiceSessionEntity?> getSessionSummary(String sessionId) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.getSessionSummary(sessionId),
      mockCall: () => _mock.getSessionSummary(sessionId),
      operationName: 'getSessionSummary($sessionId)',
    );
  }
}

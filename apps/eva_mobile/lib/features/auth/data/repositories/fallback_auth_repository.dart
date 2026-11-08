import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/emergency_contact_entity.dart';
import '../../../../core/network/fallback_policy.dart';

class FallbackAuthRepository implements AuthRepository {
  final AuthRepository _remote;
  final AuthRepository _mock;

  FallbackAuthRepository({
    required AuthRepository remote,
    required AuthRepository mock,
  })  : _remote = remote,
        _mock = mock;

  @override
  Future<UserEntity?> getCurrentUser() {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.getCurrentUser(),
      mockCall: () => _mock.getCurrentUser(),
      operationName: 'getCurrentUser',
    );
  }

  @override
  Future<UserEntity> login(String email, String password) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.login(email, password),
      mockCall: () => _mock.login(email, password),
      operationName: 'login',
    );
  }

  @override
  Future<UserEntity> register(String name, String email, String password) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.register(name, email, password),
      mockCall: () => _mock.register(name, email, password),
      operationName: 'register',
    );
  }

  @override
  Future<bool> checkEmailAvailability(String email) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.checkEmailAvailability(email),
      mockCall: () => _mock.checkEmailAvailability(email),
      operationName: 'checkEmailAvailability',
    );
  }

  @override
  Future<void> logout() {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.logout(),
      mockCall: () => _mock.logout(),
      operationName: 'logout',
    );
  }

  @override
  Future<List<EmergencyContactEntity>> getEmergencyContacts() {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.getEmergencyContacts(),
      mockCall: () => _mock.getEmergencyContacts(),
      operationName: 'getEmergencyContacts',
    );
  }

  @override
  Future<EmergencyContactEntity> addEmergencyContact(EmergencyContactEntity contact) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.addEmergencyContact(contact),
      mockCall: () => _mock.addEmergencyContact(contact),
      operationName: 'addEmergencyContact',
    );
  }

  @override
  Future<void> deleteEmergencyContact(String id) {
    return FallbackExecutor.execute(
      remoteCall: () => _remote.deleteEmergencyContact(id),
      mockCall: () => _mock.deleteEmergencyContact(id),
      operationName: 'deleteEmergencyContact',
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eva_mobile/config/app_config.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/emergency_contact_entity.dart';
import '../../data/datasources/mock_auth_datasource.dart';
import '../../data/datasources/remote_auth_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/fallback_auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final mockRepo = AuthRepositoryImpl(MockAuthDataSource());
  final remoteRepo = AuthRepositoryImpl(RemoteAuthDataSource());

  if (AppConfig.useMockData) {
    return mockRepo;
  } else if (AppConfig.useHybridFallback) {
    return FallbackAuthRepository(remote: remoteRepo, mock: mockRepo);
  } else {
    return remoteRepo;
  }
});

final currentUserProvider = FutureProvider<UserEntity?>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.getCurrentUser();
});

final emergencyContactsProvider = FutureProvider<List<EmergencyContactEntity>>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.getEmergencyContacts();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/app_config.dart';
import '../../domain/entities/psychologist_user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/datasources/auth_datasource.dart';
import '../../data/datasources/mock_auth_datasource.dart';
import '../../data/datasources/remote_auth_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';

/// Data source provider dynamically switching based on AppConfig.useMockData
final authDataSourceProvider = Provider<AuthDataSource>((ref) {
  if (AppConfig.useMockData) {
    return MockAuthDataSource();
  }
  return RemoteAuthDataSource();
});

/// Repository provider
final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  final dataSource = ref.watch(authDataSourceProvider);
  return AuthRepositoryImpl(dataSource: dataSource);
});

/// Current active psychologist profile state notifier
class AuthStateNotifier extends StateNotifier<AsyncValue<PsychologistUserEntity?>> {
  final IAuthRepository _repository;

  AuthStateNotifier(this._repository) : super(const AsyncValue.loading()) {
    checkAuthSession();
  }

  Future<void> checkAuthSession() async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.getCurrentProfile();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.login(email, password);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> register({
    required String fullName,
    required String titleDegree,
    required String email,
    required String password,
    required String strNumber,
    required String association,
    required List<String> specializations,
    required int yearsOfExperience,
    required int consultationRate,
    required String certificateDocFileName,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.register(
        fullName: fullName,
        titleDegree: titleDegree,
        email: email,
        password: password,
        strNumber: strNumber,
        association: association,
        specializations: specializations,
        yearsOfExperience: yearsOfExperience,
        consultationRate: consultationRate,
        certificateDocFileName: certificateDocFileName,
      );
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleAvailability(bool isOnline) async {
    final current = state.value;
    if (current == null) return;
    try {
      await _repository.setOnlineAvailability(isOnline);
      state = AsyncValue.data(PsychologistUserEntity(
        id: current.id,
        fullName: current.fullName,
        titleDegree: current.titleDegree,
        email: current.email,
        strNumber: current.strNumber,
        association: current.association,
        specializations: current.specializations,
        yearsOfExperience: current.yearsOfExperience,
        consultationRatePerHour: current.consultationRatePerHour,
        verificationStatus: current.verificationStatus,
        isOnline: isOnline,
        profilePhotoUrl: current.profilePhotoUrl,
        certificateDocUrl: current.certificateDocUrl,
      ));
    } catch (_) {}
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AsyncValue.data(null);
  }
}

final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AsyncValue<PsychologistUserEntity?>>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthStateNotifier(repo);
});

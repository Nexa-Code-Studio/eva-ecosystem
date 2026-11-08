import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/app_config.dart';
import '../../domain/entities/psychologist_entity.dart';
import '../../domain/entities/clinic_entity.dart';
import '../../domain/entities/community_status_entity.dart';
import '../../domain/entities/consultation_session_entity.dart';
import '../../domain/repositories/care_repository.dart';
import '../../data/datasources/mock_care_datasource.dart';
import '../../data/datasources/remote_care_datasource.dart';
import '../../data/repositories/care_repository_impl.dart';
import '../../data/repositories/fallback_care_repository.dart';

// Persistent in-memory mock instance across provider updates
final _sharedMockCareDataSource = MockCareDataSource();

final careRepositoryProvider = Provider<CareRepository>((ref) {
  final mockRepo = CareRepositoryImpl(_sharedMockCareDataSource);
  final remoteRepo = CareRepositoryImpl(RemoteCareDataSource());

  if (AppConfig.useMockData) {
    return mockRepo;
  } else if (AppConfig.useHybridFallback) {
    return FallbackCareRepository(remote: remoteRepo, mock: mockRepo);
  } else {
    return remoteRepo;
  }
});

// Category Filter: 'all', 'psychologist', 'psychiatrist', 'clinic'
final careCategoryFilterProvider = StateProvider<String>((ref) => 'all');

// Search Query Filter
final careSearchQueryProvider = StateProvider<String>((ref) => '');

// Psychologists & Psychiatrists Provider
final psychologistsListProvider = FutureProvider<List<PsychologistEntity>>((ref) async {
  final repo = ref.watch(careRepositoryProvider);
  final category = ref.watch(careCategoryFilterProvider);
  final query = ref.watch(careSearchQueryProvider);

  // If the filter is explicitly 'clinic', psychologists list can be empty or unchanged
  if (category == 'clinic') return [];

  return repo.getPsychologists(
    category: category == 'all' ? null : category,
    query: query,
  );
});

// Clinics Provider
final clinicsListProvider = FutureProvider<List<ClinicEntity>>((ref) async {
  final repo = ref.watch(careRepositoryProvider);
  final query = ref.watch(careSearchQueryProvider);
  return repo.getClinics(query: query);
});

// Community Status Notifier (Handles instant upgrade & state sync)
class CommunityStatusNotifier extends StateNotifier<AsyncValue<CommunityStatusEntity>> {
  final CareRepository _repo;

  CommunityStatusNotifier(this._repo) : super(const AsyncValue.loading()) {
    loadStatus();
  }

  Future<void> loadStatus() async {
    state = const AsyncValue.loading();
    try {
      final status = await _repo.getCommunityStatus();
      state = AsyncValue.data(status);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> joinWithVipTrial() async {
    try {
      final updated = await _repo.joinCommunityWithVipTrial();
      state = AsyncValue.data(updated);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final communityStatusProvider =
    StateNotifierProvider<CommunityStatusNotifier, AsyncValue<CommunityStatusEntity>>((ref) {
  final repo = ref.watch(careRepositoryProvider);
  return CommunityStatusNotifier(repo);
});

// Consultation Sessions Notifier (Manages upcoming & completed history)
class ConsultationSessionsNotifier
    extends StateNotifier<AsyncValue<List<ConsultationSessionEntity>>> {
  final CareRepository _repo;

  ConsultationSessionsNotifier(this._repo) : super(const AsyncValue.loading()) {
    loadSessions();
  }

  Future<void> loadSessions() async {
    state = const AsyncValue.loading();
    try {
      final sessions = await _repo.getConsultationSessions();
      state = AsyncValue.data(sessions);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> bookNewSession({
    required String psychologistId,
    required DateTime preferredDateTime,
    required ConsultationType sessionType,
    String? complaints,
  }) async {
    try {
      final newSession = await _repo.bookConsultation(
        psychologistId: psychologistId,
        preferredDateTime: preferredDateTime,
        sessionType: sessionType,
        complaints: complaints,
      );

      final current = state.value ?? [];
      state = AsyncValue.data([newSession, ...current]);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> completeSession(
    String sessionId, {
    List<String>? adviceList,
    List<String>? actionItems,
    String? sessionSummary,
    String? moodAfter,
  }) async {
    final current = state.value ?? [];
    state = AsyncValue.data(
      current.map((s) {
        if (s.id == sessionId) {
          return s.copyWith(
            status: ConsultationStatus.completed,
            adviceList: adviceList ??
                (s.adviceList.isNotEmpty
                    ? s.adviceList
                    : const [
                        'Lakukan teknik relaksasi napas dalam saat merasa cemas.',
                        'Catat perubahan suasana hati di Jurnal Eva.',
                        'Jadwalkan sesi follow-up dalam 2 minggu ke depan.',
                      ]),
            actionItems: actionItems ??
                (s.actionItems.isNotEmpty
                    ? s.actionItems
                    : const [
                        'Praktikkan latihan mindfulness 5 menit setiap pagi.',
                      ]),
            sessionSummary: sessionSummary ??
                s.sessionSummary ??
                'Sesi konsultasi tatap muka online selesai dilaksanakan dengan hasil positif.',
            moodAfter: moodAfter ?? 'Tenang & Lebih Lega (Skala 4/10)',
          );
        }
        return s;
      }).toList(),
    );
  }
}

final consultationSessionsProvider = StateNotifierProvider<
    ConsultationSessionsNotifier,
    AsyncValue<List<ConsultationSessionEntity>>>((ref) {
  final repo = ref.watch(careRepositoryProvider);
  return ConsultationSessionsNotifier(repo);
});

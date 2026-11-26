import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/app_config.dart';
import '../../domain/entities/psychologist_entity.dart';
import '../../domain/entities/community_status_entity.dart';
import '../../domain/entities/consultation_session_entity.dart';
import '../../domain/entities/counselor_timeline_entity.dart';
import '../../domain/entities/psychologist_rating_review.dart';
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

// Availability Filter: 'all', 'available_now', 'available_today', 'available_tomorrow'
final careAvailabilityFilterProvider = StateProvider<String>((ref) => 'all');

// Sort Filter: 'default', 'rating'
final careSortByProvider = StateProvider<String>((ref) => 'default');

// Level Tier Filter: null = all levels, or integer tier (1, 2, 3, 4...)
final careLevelTierFilterProvider = StateProvider<int?>((ref) => null);

// Search Query Filter
final careSearchQueryProvider = StateProvider<String>((ref) => '');

// Verified Psychologists Directory Provider
final psychologistsListProvider = FutureProvider<List<PsychologistEntity>>((ref) async {
  final repo = ref.watch(careRepositoryProvider);
  final availability = ref.watch(careAvailabilityFilterProvider);
  final levelTier = ref.watch(careLevelTierFilterProvider);
  final sortBy = ref.watch(careSortByProvider);
  final query = ref.watch(careSearchQueryProvider);

  return repo.getPsychologists(
    availability: availability == 'all' ? null : availability,
    levelTier: levelTier,
    sortBy: sortBy == 'default' ? null : sortBy,
    query: query,
  );
});

// Counselor Daily Availability Timeline Provider
final counselorTimelineProvider = FutureProvider.autoDispose
    .family<CounselorTimelineEntity, ({String counselorId, DateTime date})>((ref, arg) async {
  final repo = ref.watch(careRepositoryProvider);
  return repo.getCounselorTimeline(counselorId: arg.counselorId, date: arg.date);
});

// Live Counselor Detail Provider (GET /api/v1/counselors/{id})
final counselorDetailProvider =
    FutureProvider.autoDispose.family<PsychologistEntity, String>((ref, counselorId) async {
  final repo = ref.watch(careRepositoryProvider);
  return repo.getCounselorDetail(counselorId);
});

// Live Counselor Reviews Provider (GET /api/v1/counselors/{id}/reviews)
final counselorReviewsProvider =
    FutureProvider.autoDispose.family<List<PatientReviewItem>, String>((ref, counselorId) async {
  final repo = ref.watch(careRepositoryProvider);
  return repo.getCounselorReviews(counselorId);
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
    int sessionCount = 1,
    int durationMinutes = 30,
    String? complaints,
    bool shareAiChatHistory = false,
  }) async {
    try {
      final newSession = await _repo.bookConsultation(
        psychologistId: psychologistId,
        preferredDateTime: preferredDateTime,
        sessionType: sessionType,
        sessionCount: sessionCount,
        durationMinutes: durationMinutes,
        complaints: complaints,
        shareAiChatHistory: shareAiChatHistory,
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
    List<ConsultationSessionEntity> baseList = state.value ?? [];
    try {
      final serverSessions = await _repo.getConsultationSessions();
      if (serverSessions.isNotEmpty) {
        baseList = serverSessions;
      }
    } catch (_) {}

    state = AsyncValue.data(
      baseList.map((s) {
        if (s.id == sessionId) {
          return s.copyWith(
            status: ConsultationStatus.completed,
            adviceList: adviceList ?? s.adviceList,
            actionItems: actionItems ?? s.actionItems,
            sessionSummary: sessionSummary ?? s.sessionSummary,
            moodAfter: moodAfter ?? s.moodAfter,
          );
        }
        return s;
      }).toList(),
    );
  }

  Future<PsychologistRatingReview> submitSessionReview({
    required String sessionId,
    required String psychologistId,
    required double rating,
    String? highlightLabel,
    String? reviewText,
    bool isAnonymous = true,
  }) async {
    final submitted = await _repo.submitSessionReview(
      sessionId: sessionId,
      psychologistId: psychologistId,
      rating: rating,
      highlightLabel: highlightLabel,
      reviewText: reviewText,
      isAnonymous: isAnonymous,
    );
    final current = state.value ?? [];
    state = AsyncValue.data(
      current
          .map((s) => s.id == sessionId
              ? s.copyWith(hasReview: true, myReview: submitted)
              : s)
          .toList(),
    );
    unawaited(loadSessions());
    return submitted;
  }

  void markSessionExtended(String sessionId, {int newDurationMinutes = 60}) {
    final current = state.value ?? [];
    state = AsyncValue.data(
      current
          .map((s) => s.id == sessionId
              ? s.copyWith(
                  durationMinutes: newDurationMinutes,
                  isExtended: true,
                )
              : s)
          .toList(),
    );
  }
}

final consultationSessionsProvider = StateNotifierProvider<
    ConsultationSessionsNotifier,
    AsyncValue<List<ConsultationSessionEntity>>>((ref) {
  final repo = ref.watch(careRepositoryProvider);
  return ConsultationSessionsNotifier(repo);
});

/// Manages user-submitted ratings and reviews for psychologists & volunteers
class PsychologistRatingsNotifier
    extends StateNotifier<Map<String, PsychologistRatingReview>> {
  PsychologistRatingsNotifier() : super({});

  void submitRating({
    required String psychologistId,
    required double rating,
    bool isPositive = true,
    required String label,
    required String description,
    List<String> tags = const [],
    bool isAnonymous = true,
  }) {
    state = {
      ...state,
      psychologistId: PsychologistRatingReview(
        psychologistId: psychologistId,
        rating: rating,
        isPositive: isPositive,
        label: label,
        description: description,
        tags: tags,
        createdAt: DateTime.now(),
        isAnonymous: isAnonymous,
      ),
    };
  }

  PsychologistRatingReview? getRatingFor(String psychologistId) {
    return state[psychologistId];
  }
}

final psychologistRatingsProvider = StateNotifierProvider<
    PsychologistRatingsNotifier,
    Map<String, PsychologistRatingReview>>((ref) {
  return PsychologistRatingsNotifier();
});

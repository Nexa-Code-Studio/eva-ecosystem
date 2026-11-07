import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/chat/domain/entities/conversation_entity.dart';
import '../features/chat/domain/repositories/chat_repository.dart';
import '../features/chat/presentation/providers/chat_provider.dart';
import '../features/diary/domain/repositories/diary_repository.dart';
import '../features/diary/presentation/providers/diary_provider.dart';
import '../services/daily_progress_local_service.dart';

/// Notifier managing real-time reactive updates for the user's daily self-care progress.
class DailyProgressNotifier extends StateNotifier<DailyProgressData> {
  final ChatRepository _chatRepo;
  final DiaryRepository _diaryRepo;
  StreamSubscription<DailyProgressData>? _streamSub;

  DailyProgressNotifier({
    required ChatRepository chatRepo,
    required DiaryRepository diaryRepo,
  })  : _chatRepo = chatRepo,
        _diaryRepo = diaryRepo,
        super(DailyProgressData(date: DailyProgressLocalService.getTodayWibDate())) {
    _init();
  }

  void _init() {
    // 1. Listen to broadcast stream from local persistence service
    _streamSub = DailyProgressLocalService.progressStream.listen((data) {
      if (mounted) {
        state = data;
      }
    });

    // 2. Load cached progress immediately
    loadProgress();

    // 3. Background sync with backend
    syncWithServer();
  }

  /// Load today's progress from local SharedPreferences
  Future<void> loadProgress() async {
    final local = await DailyProgressLocalService.loadTodayProgress();
    if (mounted) {
      state = local;
    }
  }

  /// Record conversation check-in
  Future<void> recordConversationCheckin({bool hasConversation = true, DateTime? now}) async {
    final updated = await DailyProgressLocalService.recordConversationCheckin(
      hasConversation: hasConversation,
      now: now,
    );
    if (mounted) {
      state = updated;
    }
  }

  /// Record diary check-in
  Future<void> recordDiaryCheckin({bool hasDiary = true, DateTime? now}) async {
    final updated = await DailyProgressLocalService.recordDiaryCheckin(
      hasDiary: hasDiary,
      now: now,
    );
    if (mounted) {
      state = updated;
    }
  }

  /// Record activity completion
  Future<void> recordActivityCompletion(String activityId, bool isCompleted, {DateTime? now}) async {
    final updated = await DailyProgressLocalService.recordActivityCompletion(
      activityId,
      isCompleted,
      now: now,
    );
    if (mounted) {
      state = updated;
    }
  }

  /// Toggle activity completion
  Future<void> toggleActivityCompletion(String activityId, {DateTime? now}) async {
    final updated = await DailyProgressLocalService.toggleActivityCompletion(
      activityId,
      now: now,
    );
    if (mounted) {
      state = updated;
    }
  }

  /// Synchronize today's progress with repositories
  Future<void> syncWithServer() async {
    try {
      final results = await Future.wait([
        // 0: Conversations today
        _chatRepo.getConversations().catchError((_) => <ConversationEntity>[]),
        // 1: Diary today
        _diaryRepo.getTodayDiary().catchError((_) => null),
      ]);

      bool hasConv = state.hasConversation;
      bool hasDiary = state.hasDiary;

      final convList = results[0] as List;
      if (convList.isNotEmpty) {
        hasConv = true;
      }

      final diary = results[1];
      if (diary != null) {
        hasDiary = true;
      }

      if (hasConv != state.hasConversation || hasDiary != state.hasDiary) {
        DailyProgressData updated = state;
        if (hasConv) {
          updated = await DailyProgressLocalService.recordConversationCheckin(hasConversation: true);
        }
        if (hasDiary) {
          updated = await DailyProgressLocalService.recordDiaryCheckin(hasDiary: true);
        }
        if (mounted) {
          state = updated;
        }
      }
    } catch (_) {
      // Graceful offline fallback
    }
  }

  /// Refresh progress from both local and server
  Future<void> refresh() async {
    await loadProgress();
    await syncWithServer();
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }
}

/// Global Riverpod provider for daily self-care progress.
final dailyProgressProvider =
    StateNotifierProvider<DailyProgressNotifier, DailyProgressData>((ref) {
  return DailyProgressNotifier(
    chatRepo: ref.watch(chatRepositoryProvider),
    diaryRepo: ref.watch(diaryRepositoryProvider),
  );
});

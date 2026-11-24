import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eva_mobile/config/app_config.dart';
import '../../data/datasources/dass_datasource.dart';
import '../../data/datasources/local_dass_datasource.dart';
import '../../data/repositories/dass_repository_impl.dart';
import '../../domain/entities/dass_assessment_entity.dart';
import '../../domain/repositories/dass_repository.dart';
import '../../../memory/presentation/providers/memory_provider.dart';
import '../../../monitoring/presentation/providers/monitoring_provider.dart';

final localDassDataSourceProvider = Provider<LocalDASSDataSource>((ref) {
  final localDb = ref.watch(encryptedLocalDatabaseProvider);
  return LocalDASSDataSource(localDb);
});

final dassRepositoryProvider = Provider<DASSRepository>((ref) {
  final localSource = ref.watch(localDassDataSourceProvider);
  final localRepo = DASSRepositoryImpl(localSource);
  final mockRepo = DASSRepositoryImpl(MockDASSDataSource());

  if (AppConfig.useMockData) {
    return mockRepo;
  }
  return localRepo;
});

class DASSAssessmentState {
  final AsyncValue<DASSAssessmentEntity> assessment;
  final Map<int, int> stagedScores;
  final bool isSaving;
  final String? successMessage;
  final String? errorMessage;

  const DASSAssessmentState({
    required this.assessment,
    this.stagedScores = const {},
    this.isSaving = false,
    this.successMessage,
    this.errorMessage,
  });

  DASSAssessmentState copyWith({
    AsyncValue<DASSAssessmentEntity>? assessment,
    Map<int, int>? stagedScores,
    bool? isSaving,
    String? successMessage,
    String? errorMessage,
  }) {
    return DASSAssessmentState(
      assessment: assessment ?? this.assessment,
      stagedScores: stagedScores ?? this.stagedScores,
      isSaving: isSaving ?? this.isSaving,
      successMessage: successMessage,
      errorMessage: errorMessage,
    );
  }
}

class DASSAssessmentNotifier extends StateNotifier<DASSAssessmentState> {
  final DASSRepository _repository;
  final Ref _ref;

  DASSAssessmentNotifier(this._repository, this._ref)
      : super(const DASSAssessmentState(assessment: AsyncValue.loading())) {
    loadTodayAssessment();
  }

  Future<void> loadTodayAssessment() async {
    state = state.copyWith(assessment: const AsyncValue.loading(), errorMessage: null);
    try {
      final result = await _repository.getTodayAssessment();
      // Initialize staged scores with current scores
      final initialStaged = {for (var it in result.items) it.itemId: it.score};
      state = state.copyWith(
        assessment: AsyncValue.data(result),
        stagedScores: initialStaged,
      );

      // Lazy On-Demand Recovery: If today's assessment is empty, attempt auto-extraction from local conversation turns
      if (result.status == 'empty') {
        _attemptAutoExtraction();
      }
    } catch (e, st) {
      state = state.copyWith(assessment: AsyncValue.error(e, st));
    }
  }

  Future<void> _attemptAutoExtraction() async {
    try {
      final extracted = await _repository.extractTodayAssessment();
      if (extracted.status != 'empty' && mounted) {
        final newStaged = {for (var it in extracted.items) it.itemId: it.score};
        state = state.copyWith(
          assessment: AsyncValue.data(extracted),
          stagedScores: newStaged,
        );
        _ref.invalidate(monitoringDataProvider);
      }
    } catch (_) {}
  }

  void updateScore(int itemId, int newScore) {
    final updated = Map<int, int>.from(state.stagedScores);
    updated[itemId] = newScore;
    state = state.copyWith(stagedScores: updated);
  }

  Future<bool> saveAssessment() async {
    if (state.isSaving) return false;
    state = state.copyWith(isSaving: true, errorMessage: null, successMessage: null);

    try {
      final payload = state.stagedScores.entries
          .map((e) => {'item_id': e.key, 'score': e.value})
          .toList();

      final updatedEntity = await _repository.updateAssessment(payload);

      final newStaged = {for (var it in updatedEntity.items) it.itemId: it.score};
      state = state.copyWith(
        assessment: AsyncValue.data(updatedEntity),
        stagedScores: newStaged,
        isSaving: false,
        successMessage: 'Koreksi DASS-21 berhasil disimpan & ritem emosional diselaraskan!',
      );

      // Invalidate monitoring provider agar kartu risiko di halaman tren ikut ter-refresh seketika
      _ref.invalidate(monitoringDataProvider);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Gagal menyimpan perubahan: $e',
      );
      return false;
    }
  }

  Future<bool> extractTodayAssessment() async {
    state = state.copyWith(
      assessment: const AsyncValue.loading(),
      errorMessage: null,
      successMessage: null,
    );
    try {
      final result = await _repository.extractTodayAssessment();
      final initialStaged = {for (var it in result.items) it.itemId: it.score};
      state = state.copyWith(
        assessment: AsyncValue.data(result),
        stagedScores: initialStaged,
        successMessage: 'Hasil DASS-21 berhasil diekstrak dari percakapan hari ini!',
      );
      _ref.invalidate(monitoringDataProvider);
      return true;
    } catch (e, st) {
      state = state.copyWith(
        assessment: AsyncValue.error(e, st),
        errorMessage: 'Gagal mengekstrak DASS: $e',
      );
      return false;
    }
  }
}

final dassAssessmentNotifierProvider =
    StateNotifierProvider<DASSAssessmentNotifier, DASSAssessmentState>((ref) {
  final repo = ref.watch(dassRepositoryProvider);
  return DASSAssessmentNotifier(repo, ref);
});

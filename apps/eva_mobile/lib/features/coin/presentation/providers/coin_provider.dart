import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eva_mobile/config/app_config.dart';
import 'package:eva_mobile/core/network/api_client.dart';
import '../../data/datasources/coin_datasource.dart';
import '../../data/datasources/mock_coin_datasource.dart';
import '../../data/datasources/remote_coin_datasource.dart';
import '../../data/repositories/coin_repository_impl.dart';
import '../../domain/entities/coin_economy_entity.dart';
import '../../domain/entities/coin_package_entity.dart';
import '../../domain/entities/coin_topup_order_entity.dart';
import '../../domain/repositories/i_coin_repository.dart';

const String _kMockCoinBalanceKey = 'user_coin_balance';
const String _kPendingTopupOrderIdKey = 'pending_topup_order_id';

/// DI provider isolating mock vs remote mode strictly from presentation widgets.
final coinUseMockModeProvider = Provider<bool>((ref) => AppConfig.useMockData);

/// Release gate for QRIS top-up in distributed builds until #135 policy sign-off.
final qrisTopupEnabledProvider = Provider<bool>(
  (ref) => AppConfig.enableQrisTopup || ref.watch(coinUseMockModeProvider),
);

final coinDataSourceProvider = Provider<CoinDataSource>((ref) {
  final isMock = ref.watch(coinUseMockModeProvider);
  return isMock ? MockCoinDataSource() : RemoteCoinDataSource();
});

final coinRepositoryProvider = Provider<ICoinRepository>((ref) {
  return CoinRepositoryImpl(ref.watch(coinDataSourceProvider));
});

/// Live EVA Coin packages fetched from backend (or MockCoinDataSource in mock mode).
final coinPackagesProvider = FutureProvider<List<CoinPackageEntity>>((ref) async {
  final repo = ref.watch(coinRepositoryProvider);
  return repo.getPackages();
});

/// Live EVA Coin economy config fetched from backend.
final coinEconomyProvider = FutureProvider<CoinEconomyEntity>((ref) async {
  final repo = ref.watch(coinRepositoryProvider);
  return repo.getEconomy();
});

/// User's paginated top-up order history.
final topupHistoryProvider = FutureProvider<List<CoinTopupOrderEntity>>((ref) async {
  final repo = ref.watch(coinRepositoryProvider);
  return repo.listTopupOrders(page: 1, pageSize: 20);
});

/// StateNotifier managing authoritative EVA Coin balance (server-synced in live mode).
class CoinBalanceNotifier extends StateNotifier<int> {
  final ICoinRepository _repository;
  final bool _isMockMode;

  CoinBalanceNotifier({
    required ICoinRepository repository,
    required bool isMockMode,
  })  : _repository = repository,
        _isMockMode = isMockMode,
        super(isMockMode ? kMockDefaultCoinBalance : 0) {
    unawaited(syncFromServer());
  }

  /// Fetch authoritative balance from backend (or mock storage in mock mode).
  Future<void> syncFromServer() async {
    try {
      final serverBalance = await _repository.getMyCoinBalance();
      state = serverBalance;
    } catch (_) {
      if (_isMockMode) {
        try {
          final prefs = await SharedPreferences.getInstance();
          state = prefs.getInt(_kMockCoinBalanceKey) ?? kMockDefaultCoinBalance;
        } catch (_) {}
      }
    }
  }

  /// Mock-only balance credit helper; live mode always syncs from server after payment.
  Future<void> addCoins(int amount) async {
    if (amount <= 0) return;
    if (!_isMockMode) {
      await syncFromServer();
      return;
    }
    final newBalance = state + amount;
    state = newBalance;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kMockCoinBalanceKey, newBalance);
    } catch (_) {}
  }

  /// Spend coins (mock updates local prefs; live mode refreshes authoritative server balance).
  Future<bool> spendCoins(int amount) async {
    if (amount <= 0) return false;
    if (!_isMockMode) {
      if (state < amount) return false;
      state = state - amount;
      await syncFromServer();
      return true;
    }
    if (state < amount) return false;
    final newBalance = state - amount;
    state = newBalance;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kMockCoinBalanceKey, newBalance);
    } catch (_) {}
    return true;
  }

  Future<void> setBalance(int balance) async {
    state = balance;
    if (_isMockMode) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_kMockCoinBalanceKey, balance);
      } catch (_) {}
    }
  }

  Future<void> refresh() => syncFromServer();
}

final coinBalanceProvider = StateNotifierProvider<CoinBalanceNotifier, int>((ref) {
  return CoinBalanceNotifier(
    repository: ref.watch(coinRepositoryProvider),
    isMockMode: ref.watch(coinUseMockModeProvider),
  );
});

class TopupFlowState {
  final bool isCreating;
  final bool isRefreshing;
  final bool isLoadingQr;
  final CoinTopupOrderEntity? activeOrder;
  final Uint8List? qrBytes;
  final String? pendingPackageId;
  final String? pendingIdempotencyKey;
  final String? errorMessage;
  final String? errorCode;

  const TopupFlowState({
    this.isCreating = false,
    this.isRefreshing = false,
    this.isLoadingQr = false,
    this.activeOrder,
    this.qrBytes,
    this.pendingPackageId,
    this.pendingIdempotencyKey,
    this.errorMessage,
    this.errorCode,
  });

  TopupFlowState copyWith({
    bool? isCreating,
    bool? isRefreshing,
    bool? isLoadingQr,
    CoinTopupOrderEntity? activeOrder,
    bool clearActiveOrder = false,
    Uint8List? qrBytes,
    bool clearQrBytes = false,
    String? pendingPackageId,
    String? pendingIdempotencyKey,
    bool clearIdempotency = false,
    String? errorMessage,
    String? errorCode,
    bool clearError = false,
  }) {
    return TopupFlowState(
      isCreating: isCreating ?? this.isCreating,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingQr: isLoadingQr ?? this.isLoadingQr,
      activeOrder: clearActiveOrder ? null : (activeOrder ?? this.activeOrder),
      qrBytes: clearQrBytes ? null : (qrBytes ?? this.qrBytes),
      pendingPackageId: clearIdempotency ? null : (pendingPackageId ?? this.pendingPackageId),
      pendingIdempotencyKey: clearIdempotency ? null : (pendingIdempotencyKey ?? this.pendingIdempotencyKey),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
    );
  }
}

class TopupFlowNotifier extends StateNotifier<TopupFlowState> {
  final Ref _ref;
  final ICoinRepository _repository;
  Timer? _pollingTimer;

  TopupFlowNotifier(this._ref, this._repository) : super(const TopupFlowState());

  static String _generateUuidV4() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Create a QRIS top-up order with a stable Idempotency-Key across retries of the same package.
  Future<CoinTopupOrderEntity?> startTopup(String packageId) async {
    final reuseKey = (state.pendingPackageId == packageId && state.pendingIdempotencyKey != null)
        ? state.pendingIdempotencyKey!
        : _generateUuidV4();

    state = state.copyWith(
      isCreating: true,
      pendingPackageId: packageId,
      pendingIdempotencyKey: reuseKey,
      clearError: true,
      clearQrBytes: true,
    );

    try {
      final order = await _repository.createTopupOrder(
        packageId: packageId,
        idempotencyKey: reuseKey,
      );
      await _persistPendingOrderId(order);
      state = state.copyWith(
        isCreating: false,
        activeOrder: order,
        clearIdempotency: !order.status.isActivePending,
      );
      if (order.status.isActivePending) {
        unawaited(loadQrImage(order.id));
        startPolling();
      } else if (order.status.isSuccess) {
        await _onOrderPaid();
      }
      return order;
    } catch (e) {
      state = state.copyWith(
        isCreating: false,
        errorMessage: _extractMessage(e),
        errorCode: _extractCode(e),
      );
      return null;
    }
  }

  /// Open an existing order (e.g. from history or restored after app restart).
  Future<void> openOrder(CoinTopupOrderEntity order) async {
    stopPolling();
    state = state.copyWith(
      activeOrder: order,
      clearQrBytes: true,
      clearError: true,
    );
    await _persistPendingOrderId(order);
    if (order.status.isActivePending) {
      unawaited(loadQrImage(order.id));
      startPolling();
    } else if (order.status.isSuccess) {
      await _onOrderPaid();
    }
  }

  /// Restore pending top-up order after app restart or relogin.
  Future<CoinTopupOrderEntity?> restorePendingOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_kPendingTopupOrderIdKey);
      if (savedId != null && savedId.isNotEmpty) {
        final order = await _repository.getTopupOrder(savedId);
        await _persistPendingOrderId(order);
        state = state.copyWith(activeOrder: order, clearError: true);
        if (order.status.isActivePending) {
          unawaited(loadQrImage(order.id));
        } else if (order.status.isSuccess) {
          await _onOrderPaid();
        }
        return order;
      }

      final pendingList = await _repository.listTopupOrders(
        page: 1,
        pageSize: 5,
        status: 'pending',
      );
      if (pendingList.isNotEmpty) {
        final latest = pendingList.first;
        await _persistPendingOrderId(latest);
        state = state.copyWith(activeOrder: latest, clearError: true);
        unawaited(loadQrImage(latest.id));
        return latest;
      }
    } catch (_) {}
    return null;
  }

  Future<void> loadQrImage(String topupId) async {
    state = state.copyWith(isLoadingQr: true, clearError: true);
    try {
      final bytes = await _repository.fetchTopupQrBytes(topupId);
      state = state.copyWith(isLoadingQr: false, qrBytes: bytes);
    } catch (e) {
      state = state.copyWith(
        isLoadingQr: false,
        errorMessage: _extractMessage(e),
        errorCode: _extractCode(e),
      );
    }
  }

  /// Poll backend status (GET /coins/topups/{id}) or trigger on-demand refresh.
  Future<void> checkStatus({bool forceProviderRefresh = false}) async {
    final current = state.activeOrder;
    if (current == null) return;

    state = state.copyWith(isRefreshing: true, clearError: true);
    try {
      final updated = forceProviderRefresh
          ? await _repository.refreshTopupOrder(current.id)
          : await _repository.getTopupOrder(current.id);
      await _persistPendingOrderId(updated);
      state = state.copyWith(isRefreshing: false, activeOrder: updated);
      if (!updated.status.isActivePending) {
        stopPolling();
        state = state.copyWith(clearIdempotency: true);
        if (updated.status.isSuccess) {
          await _onOrderPaid();
        }
      }
    } catch (e) {
      state = state.copyWith(
        isRefreshing: false,
        errorMessage: _extractMessage(e),
        errorCode: _extractCode(e),
      );
    }
  }

  void startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      final order = state.activeOrder;
      if (order == null || !order.status.isActivePending) {
        stopPolling();
        return;
      }
      if (!state.isRefreshing) {
        unawaited(checkStatus(forceProviderRefresh: false));
      }
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  void resetForNewOrder() {
    stopPolling();
    state = const TopupFlowState();
  }

  Future<void> _onOrderPaid() async {
    await _ref.read(coinBalanceProvider.notifier).syncFromServer();
    _ref.invalidate(topupHistoryProvider);
  }

  Future<void> _persistPendingOrderId(CoinTopupOrderEntity order) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (order.status.isActivePending) {
        await prefs.setString(_kPendingTopupOrderIdKey, order.id);
      } else {
        await prefs.remove(_kPendingTopupOrderIdKey);
      }
    } catch (_) {}
  }

  static String _extractMessage(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    return error.toString();
  }

  static String? _extractCode(Object error) {
    if (error is ApiException) {
      return error.errorCode;
    }
    return null;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}

final topupFlowProvider = StateNotifierProvider<TopupFlowNotifier, TopupFlowState>((ref) {
  return TopupFlowNotifier(ref, ref.watch(coinRepositoryProvider));
});

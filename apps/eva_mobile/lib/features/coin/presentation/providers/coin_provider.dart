import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/coin_package_entity.dart';

/// Predefined coin packages available for purchase in Eva Mobile.
final coinPackagesProvider = Provider<List<CoinPackageEntity>>((ref) {
  return const [
    CoinPackageEntity(
      id: 'pkg_starter',
      title: 'Paket Starter',
      coins: 50,
      bonusCoins: 0,
      priceIdr: 15000,
      description: 'Cocok untuk mencoba berbicara dengan EVA',
    ),
    CoinPackageEntity(
      id: 'pkg_popular',
      title: 'Paket Favorit',
      coins: 150,
      bonusCoins: 20,
      priceIdr: 45000,
      badge: 'Paling Populer',
      isPopular: true,
      description: 'Pilihan hemat untuk bicara rutin & konsultasi psikolog',
    ),
    CoinPackageEntity(
      id: 'pkg_pro',
      title: 'Paket Pro Mind',
      coins: 300,
      bonusCoins: 60,
      priceIdr: 89000,
      badge: 'Hemat 25%',
      description: 'Bicara intensif dengan EVA & konsultasi psikolog ahli',
    ),
    CoinPackageEntity(
      id: 'pkg_ultimate',
      title: 'Paket Ultimate',
      coins: 600,
      bonusCoins: 150,
      priceIdr: 169000,
      badge: 'Super Hemat',
      description: 'Koin terlengkap untuk bicara dengan EVA & konsultasi psikolog',
    ),
  ];
});

/// Key used to persist user's coin balance locally.
const String _kUserCoinBalanceKey = 'user_coin_balance';
const int kDefaultCoinBalance = 120;

/// StateNotifier that manages user's reactive coin balance.
class CoinBalanceNotifier extends StateNotifier<int> {
  final Future<int> Function()? _fetchServerBalance;
  final bool? _isMockModeOverride;

  CoinBalanceNotifier({
    Future<int> Function()? fetchServerBalance,
    bool? isMockMode,
  })  : _fetchServerBalance = fetchServerBalance,
        _isMockModeOverride = isMockMode,
        super(kDefaultCoinBalance) {
    _loadInitialBalance();
  }

  bool get _isMockMode => _isMockModeOverride ?? AppConfig.useMockData;
  bool get _hasRemoteSession =>
      !_isMockMode && (_fetchServerBalance != null || AppConfig.authToken != null);

  Future<void> _loadInitialBalance() async {
    if (_hasRemoteSession) {
      await syncFromServer();
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedBalance = prefs.getInt(_kUserCoinBalanceKey);
      if (savedBalance != null) {
        state = savedBalance;
      } else {
        await prefs.setInt(_kUserCoinBalanceKey, kDefaultCoinBalance);
      }
    } catch (_) {
      // Fallback to default in case of error
    }
  }

  /// Fetch authoritative coin balance from PostgreSQL via GET /api/v1/users/coins.
  Future<void> syncFromServer() async {
    if (_isMockMode) return;
    try {
      final int balance;
      if (_fetchServerBalance != null) {
        balance = await _fetchServerBalance();
      } else {
        final res = await ApiClient().get('/users/coins');
        if (res is Map<String, dynamic> && res['coin_balance'] != null) {
          balance = (res['coin_balance'] as num).toInt();
        } else {
          return;
        }
      }
      state = balance;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_kUserCoinBalanceKey, balance);
      } catch (_) {}
    } catch (_) {}
  }

  /// Add purchased or reward coins
  Future<void> addCoins(int amount) async {
    if (amount <= 0) return;
    if (_hasRemoteSession) {
      await syncFromServer();
      return;
    }
    final newBalance = state + amount;
    state = newBalance;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kUserCoinBalanceKey, newBalance);
    } catch (_) {}
  }

  /// Spend coins (mock/local updates prefs; authenticated live mode syncs authoritative PostgreSQL balance).
  Future<bool> spendCoins(int amount) async {
    if (amount <= 0) return false;
    if (_hasRemoteSession) {
      if (state < amount) return false;
      await syncFromServer();
      return true;
    }
    if (state < amount) return false;
    final newBalance = state - amount;
    state = newBalance;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kUserCoinBalanceKey, newBalance);
    } catch (_) {}
    return true;
  }

  /// Sync balance after server-side debit (booking / extension) or deduct locally in mock mode.
  Future<void> syncAfterServerDebit(int amount) async {
    if (!_isMockMode) {
      await syncFromServer();
      return;
    }
    if (amount > 0) {
      await spendCoins(amount);
    }
  }

  /// Set balance directly (e.g., from server sync)
  Future<void> setBalance(int balance) async {
    state = balance;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kUserCoinBalanceKey, balance);
    } catch (_) {}
  }

  /// Refresh from backend (live) or local storage (mock)
  Future<void> refresh() async {
    await _loadInitialBalance();
  }
}

/// Global provider for user's coin balance
final coinBalanceProvider = StateNotifierProvider<CoinBalanceNotifier, int>((ref) {
  return CoinBalanceNotifier();
});

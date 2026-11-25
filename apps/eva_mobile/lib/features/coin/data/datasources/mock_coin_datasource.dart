import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/coin_economy_model.dart';
import '../models/coin_package_model.dart';
import '../models/coin_topup_order_model.dart';
import 'coin_datasource.dart';

const int kMockDefaultCoinBalance = 120;
const String _kMockCoinBalanceKey = 'user_coin_balance';

// Valid 1x1 PNG base64 placeholder for mock QR display in offline/mock tests
final Uint8List _mockQrPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

class MockCoinDataSource implements CoinDataSource {
  final Map<String, CoinTopupOrderModel> _orders = {};
  final Map<String, String> _idempotencyMap = {};

  static const List<CoinPackageModel> _mockPackages = [
    CoinPackageModel(
      id: 'pkg_starter',
      code: 'STARTER',
      name: 'Paket Starter',
      coins: 50,
      bonusCoins: 0,
      priceIdr: 15000,
      description: 'Cocok untuk mencoba berbicara dengan EVA',
      isPopular: false,
    ),
    CoinPackageModel(
      id: 'pkg_popular',
      code: 'POPULAR',
      name: 'Paket Favorit',
      coins: 150,
      bonusCoins: 20,
      priceIdr: 45000,
      description: 'Pilihan hemat untuk bicara rutin & konsultasi psikolog',
      isPopular: true,
    ),
    CoinPackageModel(
      id: 'pkg_pro',
      code: 'PRO',
      name: 'Paket Pro Mind',
      coins: 300,
      bonusCoins: 60,
      priceIdr: 89000,
      description: 'Bicara intensif dengan EVA & konsultasi psikolog ahli',
      isPopular: false,
    ),
    CoinPackageModel(
      id: 'pkg_ultimate',
      code: 'ULTIMATE',
      name: 'Paket Ultimate',
      coins: 600,
      bonusCoins: 150,
      priceIdr: 169000,
      description: 'Koin terlengkap untuk bicara dengan EVA & konsultasi psikolog',
      isPopular: false,
    ),
  ];

  @override
  Future<List<CoinPackageModel>> fetchPackages() async {
    return _mockPackages;
  }

  @override
  Future<CoinEconomyModel> fetchEconomy() async {
    return const CoinEconomyModel(
      basePricePerCoinIdr: 1000,
      freeTrialCoinsNewUser: 10,
    );
  }

  @override
  Future<int> fetchMyCoinBalance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kMockCoinBalanceKey) ?? kMockDefaultCoinBalance;
  }

  @override
  Future<CoinTopupOrderModel> createTopupOrder({
    required String packageId,
    required String idempotencyKey,
  }) async {
    final existingId = _idempotencyMap[idempotencyKey];
    if (existingId != null && _orders.containsKey(existingId)) {
      return _orders[existingId]!;
    }

    final pkg = _mockPackages.firstWhere(
      (p) => p.id == packageId,
      orElse: () => _mockPackages.first,
    );
    final now = DateTime.now().toUtc();
    final id = 'mock-topup-${now.millisecondsSinceEpoch}';
    final order = CoinTopupOrderModel(
      id: id,
      orderId: 'EVA-TOPUP-MOCK-${now.millisecondsSinceEpoch}',
      package: CoinTopupPackageSnapshotModel(
        id: pkg.id,
        name: pkg.name,
        coins: pkg.coins,
        bonusCoins: pkg.bonusCoins,
      ),
      amountIdr: pkg.priceIdr,
      currency: 'IDR',
      totalCoins: pkg.coins + pkg.bonusCoins,
      paymentMethod: 'qris',
      status: 'pending',
      qrImageUrl: 'https://api.sandbox.midtrans.com/v2/qris/$id/qr-code',
      expiresAt: now.add(const Duration(minutes: 15)).toIso8601String(),
      paidAt: null,
      createdAt: now.toIso8601String(),
      updatedAt: now.toIso8601String(),
    );
    _orders[id] = order;
    _idempotencyMap[idempotencyKey] = id;
    return order;
  }

  @override
  Future<CoinTopupOrderModel> fetchTopupOrder(String topupId) async {
    return _orders[topupId] ?? _orders.values.first;
  }

  @override
  Future<List<CoinTopupOrderModel>> listTopupOrders({
    int page = 1,
    int pageSize = 20,
    String? status,
  }) async {
    final list = _orders.values.toList().reversed.toList();
    if (status == null || status.isEmpty) return list;
    return list.where((o) => o.status == status).toList();
  }

  @override
  Future<CoinTopupOrderModel> refreshTopupOrder(String topupId) async {
    final existing = _orders[topupId];
    if (existing == null) {
      throw StateError('Mock topup order not found: $topupId');
    }
    if (existing.status == 'paid') return existing;

    final now = DateTime.now().toUtc().toIso8601String();
    final paid = CoinTopupOrderModel(
      id: existing.id,
      orderId: existing.orderId,
      package: existing.package,
      amountIdr: existing.amountIdr,
      currency: existing.currency,
      totalCoins: existing.totalCoins,
      paymentMethod: existing.paymentMethod,
      status: 'paid',
      qrImageUrl: existing.qrImageUrl,
      expiresAt: existing.expiresAt,
      paidAt: now,
      createdAt: existing.createdAt,
      updatedAt: now,
    );
    _orders[topupId] = paid;

    final prefs = await SharedPreferences.getInstance();
    final curr = prefs.getInt(_kMockCoinBalanceKey) ?? kMockDefaultCoinBalance;
    await prefs.setInt(_kMockCoinBalanceKey, curr + paid.totalCoins);
    return paid;
  }

  @override
  Future<Uint8List> fetchTopupQrBytes(String topupId) async {
    return _mockQrPngBytes;
  }
}

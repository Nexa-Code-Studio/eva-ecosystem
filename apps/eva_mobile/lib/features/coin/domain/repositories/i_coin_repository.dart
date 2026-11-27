import 'dart:typed_data';

import '../entities/coin_economy_entity.dart';
import '../entities/coin_package_entity.dart';
import '../entities/coin_topup_order_entity.dart';

abstract class ICoinRepository {
  Future<List<CoinPackageEntity>> getPackages();

  Future<CoinEconomyEntity> getEconomy();

  Future<int> getMyCoinBalance();

  Future<CoinTopupOrderEntity> createTopupOrder({
    required String packageId,
    required String idempotencyKey,
  });

  Future<CoinTopupOrderEntity> getTopupOrder(String topupId);

  Future<List<CoinTopupOrderEntity>> listTopupOrders({
    int page = 1,
    int pageSize = 20,
    String? status,
  });

  Future<CoinTopupOrderEntity> refreshTopupOrder(String topupId);

  Future<CoinTopupOrderEntity> simulateTopupPayment(String topupId);

  Future<Uint8List> fetchTopupQrBytes(String topupId);
}

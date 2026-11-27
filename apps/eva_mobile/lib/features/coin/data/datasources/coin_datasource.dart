import 'dart:typed_data';

import '../models/coin_economy_model.dart';
import '../models/coin_package_model.dart';
import '../models/coin_topup_order_model.dart';

abstract class CoinDataSource {
  Future<List<CoinPackageModel>> fetchPackages();

  Future<CoinEconomyModel> fetchEconomy();

  Future<int> fetchMyCoinBalance();

  Future<CoinTopupOrderModel> createTopupOrder({
    required String packageId,
    required String idempotencyKey,
  });

  Future<CoinTopupOrderModel> fetchTopupOrder(String topupId);

  Future<List<CoinTopupOrderModel>> listTopupOrders({
    int page = 1,
    int pageSize = 20,
    String? status,
  });

  Future<CoinTopupOrderModel> refreshTopupOrder(String topupId);

  Future<CoinTopupOrderModel> simulateTopupPayment(String topupId);

  Future<Uint8List> fetchTopupQrBytes(String topupId);
}

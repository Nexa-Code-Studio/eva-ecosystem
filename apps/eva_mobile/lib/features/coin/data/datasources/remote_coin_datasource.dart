import 'dart:typed_data';

import 'package:eva_mobile/core/network/api_client.dart';
import '../models/coin_economy_model.dart';
import '../models/coin_package_model.dart';
import '../models/coin_topup_order_model.dart';
import 'coin_datasource.dart';

class RemoteCoinDataSource implements CoinDataSource {
  final ApiClient _client;

  RemoteCoinDataSource({ApiClient? client}) : _client = client ?? ApiClient();

  @override
  Future<List<CoinPackageModel>> fetchPackages() async {
    final res = await _client.get('/coins/packages');
    if (res is List<dynamic>) {
      return res
          .whereType<Map<String, dynamic>>()
          .map(CoinPackageModel.fromJson)
          .toList();
    }
    return [];
  }

  @override
  Future<CoinEconomyModel> fetchEconomy() async {
    final res = await _client.get('/coins/economy');
    return CoinEconomyModel.fromJson(res as Map<String, dynamic>);
  }

  @override
  Future<int> fetchMyCoinBalance() async {
    final res = await _client.get('/users/coins');
    final map = res as Map<String, dynamic>;
    return (map['coin_balance'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<CoinTopupOrderModel> createTopupOrder({
    required String packageId,
    required String idempotencyKey,
  }) async {
    final res = await _client.post(
      '/coins/topups',
      body: {'package_id': packageId},
      extraHeaders: {'Idempotency-Key': idempotencyKey},
    );
    return CoinTopupOrderModel.fromJson(res as Map<String, dynamic>);
  }

  @override
  Future<CoinTopupOrderModel> fetchTopupOrder(String topupId) async {
    final res = await _client.get('/coins/topups/$topupId');
    return CoinTopupOrderModel.fromJson(res as Map<String, dynamic>);
  }

  @override
  Future<List<CoinTopupOrderModel>> listTopupOrders({
    int page = 1,
    int pageSize = 20,
    String? status,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final res = await _client.get('/coins/topups', queryParams: query);
    if (res is Map<String, dynamic> && res['items'] is List<dynamic>) {
      return (res['items'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(CoinTopupOrderModel.fromJson)
          .toList();
    }
    return [];
  }

  @override
  Future<CoinTopupOrderModel> refreshTopupOrder(String topupId) async {
    final res = await _client.post('/coins/topups/$topupId/refresh');
    return CoinTopupOrderModel.fromJson(res as Map<String, dynamic>);
  }

  @override
  Future<Uint8List> fetchTopupQrBytes(String topupId) async {
    return _client.getBytes('/coins/topups/$topupId/qr');
  }
}

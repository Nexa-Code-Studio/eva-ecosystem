import 'dart:typed_data';

import '../../domain/entities/coin_economy_entity.dart';
import '../../domain/entities/coin_package_entity.dart';
import '../../domain/entities/coin_topup_order_entity.dart';
import '../../domain/repositories/i_coin_repository.dart';
import '../datasources/coin_datasource.dart';

class CoinRepositoryImpl implements ICoinRepository {
  final CoinDataSource _dataSource;

  CoinRepositoryImpl(this._dataSource);

  @override
  Future<List<CoinPackageEntity>> getPackages() async {
    final models = await _dataSource.fetchPackages();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<CoinEconomyEntity> getEconomy() async {
    final model = await _dataSource.fetchEconomy();
    return model.toEntity();
  }

  @override
  Future<int> getMyCoinBalance() {
    return _dataSource.fetchMyCoinBalance();
  }

  @override
  Future<CoinTopupOrderEntity> createTopupOrder({
    required String packageId,
    required String idempotencyKey,
  }) async {
    final model = await _dataSource.createTopupOrder(
      packageId: packageId,
      idempotencyKey: idempotencyKey,
    );
    return model.toEntity();
  }

  @override
  Future<CoinTopupOrderEntity> getTopupOrder(String topupId) async {
    final model = await _dataSource.fetchTopupOrder(topupId);
    return model.toEntity();
  }

  @override
  Future<List<CoinTopupOrderEntity>> listTopupOrders({
    int page = 1,
    int pageSize = 20,
    String? status,
  }) async {
    final models = await _dataSource.listTopupOrders(
      page: page,
      pageSize: pageSize,
      status: status,
    );
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<CoinTopupOrderEntity> refreshTopupOrder(String topupId) async {
    final model = await _dataSource.refreshTopupOrder(topupId);
    return model.toEntity();
  }

  @override
  Future<Uint8List> fetchTopupQrBytes(String topupId) {
    return _dataSource.fetchTopupQrBytes(topupId);
  }
}

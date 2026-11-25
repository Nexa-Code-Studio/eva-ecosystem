import '../../domain/entities/coin_economy_entity.dart';

class CoinEconomyModel {
  final int basePricePerCoinIdr;
  final int freeTrialCoinsNewUser;

  const CoinEconomyModel({
    required this.basePricePerCoinIdr,
    required this.freeTrialCoinsNewUser,
  });

  factory CoinEconomyModel.fromJson(Map<String, dynamic> json) {
    return CoinEconomyModel(
      basePricePerCoinIdr: (json['base_price_per_coin_idr'] as num?)?.toInt() ?? 1000,
      freeTrialCoinsNewUser: (json['free_trial_coins_new_user'] as num?)?.toInt() ?? 10,
    );
  }

  Map<String, dynamic> toJson() => {
        'base_price_per_coin_idr': basePricePerCoinIdr,
        'free_trial_coins_new_user': freeTrialCoinsNewUser,
      };

  CoinEconomyEntity toEntity() => CoinEconomyEntity(
        basePricePerCoinIdr: basePricePerCoinIdr,
        freeTrialCoinsNewUser: freeTrialCoinsNewUser,
      );
}

import '../../domain/entities/coin_package_entity.dart';

class CoinPackageModel {
  final String id;
  final String code;
  final String name;
  final int coins;
  final int bonusCoins;
  final int priceIdr;
  final String description;
  final bool isPopular;
  final bool isActive;

  const CoinPackageModel({
    required this.id,
    required this.code,
    required this.name,
    required this.coins,
    this.bonusCoins = 0,
    required this.priceIdr,
    this.description = '',
    this.isPopular = false,
    this.isActive = true,
  });

  factory CoinPackageModel.fromJson(Map<String, dynamic> json) {
    return CoinPackageModel(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? '',
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      bonusCoins: (json['bonus_coins'] as num?)?.toInt() ?? 0,
      priceIdr: (json['price_idr'] as num?)?.toInt() ?? 0,
      description: json['description']?.toString() ?? '',
      isPopular: json['is_popular'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'coins': coins,
        'bonus_coins': bonusCoins,
        'price_idr': priceIdr,
        'description': description,
        'is_popular': isPopular,
        'is_active': isActive,
      };

  CoinPackageEntity toEntity() => CoinPackageEntity(
        id: id,
        title: name,
        coins: coins,
        bonusCoins: bonusCoins,
        priceIdr: priceIdr,
        badge: isPopular ? 'Paling Populer' : null,
        isPopular: isPopular,
        description: description,
      );
}

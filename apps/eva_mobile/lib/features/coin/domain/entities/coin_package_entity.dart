class CoinPackageEntity {
  final String id;
  final String title;
  final int coins;
  final int bonusCoins;
  final int priceIdr;
  final String? badge;
  final bool isPopular;
  final String description;

  const CoinPackageEntity({
    required this.id,
    required this.title,
    required this.coins,
    this.bonusCoins = 0,
    required this.priceIdr,
    this.badge,
    this.isPopular = false,
    this.description = '',
  });

  int get totalCoins => coins + bonusCoins;

  String get formattedPrice {
    final str = priceIdr.toString();
    final formatted = str.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
    return 'Rp $formatted';
  }
}

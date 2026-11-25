import '../../domain/entities/coin_topup_order_entity.dart';

class CoinTopupPackageSnapshotModel {
  final String id;
  final String name;
  final int coins;
  final int bonusCoins;

  const CoinTopupPackageSnapshotModel({
    required this.id,
    required this.name,
    required this.coins,
    this.bonusCoins = 0,
  });

  factory CoinTopupPackageSnapshotModel.fromJson(Map<String, dynamic> json) {
    return CoinTopupPackageSnapshotModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      bonusCoins: (json['bonus_coins'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'coins': coins,
        'bonus_coins': bonusCoins,
      };

  CoinTopupPackageSnapshot toEntity() => CoinTopupPackageSnapshot(
        id: id,
        name: name,
        coins: coins,
        bonusCoins: bonusCoins,
      );
}

class CoinTopupOrderModel {
  final String id;
  final String orderId;
  final CoinTopupPackageSnapshotModel package;
  final int amountIdr;
  final String currency;
  final int totalCoins;
  final String paymentMethod;
  final String status;
  final String? qrImageUrl;
  final String? expiresAt;
  final String? paidAt;
  final String createdAt;
  final String updatedAt;

  const CoinTopupOrderModel({
    required this.id,
    required this.orderId,
    required this.package,
    required this.amountIdr,
    required this.currency,
    required this.totalCoins,
    required this.paymentMethod,
    required this.status,
    this.qrImageUrl,
    this.expiresAt,
    this.paidAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CoinTopupOrderModel.fromJson(Map<String, dynamic> json) {
    final pkgJson = json['package'] is Map<String, dynamic>
        ? json['package'] as Map<String, dynamic>
        : <String, dynamic>{};
    return CoinTopupOrderModel(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      package: CoinTopupPackageSnapshotModel.fromJson(pkgJson),
      amountIdr: (json['amount_idr'] as num?)?.toInt() ?? 0,
      currency: json['currency']?.toString() ?? 'IDR',
      totalCoins: (json['total_coins'] as num?)?.toInt() ?? 0,
      paymentMethod: json['payment_method']?.toString() ?? 'qris',
      status: json['status']?.toString() ?? 'pending',
      qrImageUrl: json['qr_image_url']?.toString(),
      expiresAt: json['expires_at']?.toString(),
      paidAt: json['paid_at']?.toString(),
      createdAt: json['created_at']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
      updatedAt: json['updated_at']?.toString() ?? DateTime.now().toUtc().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_id': orderId,
        'package': package.toJson(),
        'amount_idr': amountIdr,
        'currency': currency,
        'total_coins': totalCoins,
        'payment_method': paymentMethod,
        'status': status,
        'qr_image_url': qrImageUrl,
        'expires_at': expiresAt,
        'paid_at': paidAt,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  CoinTopupOrderEntity toEntity() => CoinTopupOrderEntity(
        id: id,
        orderId: orderId,
        package: package.toEntity(),
        amountIdr: amountIdr,
        currency: currency,
        totalCoins: totalCoins,
        paymentMethod: paymentMethod,
        status: CoinTopupStatus.fromApi(status),
        qrImageUrl: qrImageUrl,
        expiresAt: expiresAt != null ? DateTime.tryParse(expiresAt!) : null,
        paidAt: paidAt != null ? DateTime.tryParse(paidAt!) : null,
        createdAt: DateTime.tryParse(createdAt) ?? DateTime.now().toUtc(),
        updatedAt: DateTime.tryParse(updatedAt) ?? DateTime.now().toUtc(),
      );
}

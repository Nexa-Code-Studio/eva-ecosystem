enum CoinTopupStatus {
  creating,
  pending,
  paid,
  expired,
  failed,
  cancelled,
  refundPending,
  partiallyRefunded,
  refunded,
  reviewRequired;

  static CoinTopupStatus fromApi(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'creating':
        return CoinTopupStatus.creating;
      case 'pending':
        return CoinTopupStatus.pending;
      case 'paid':
        return CoinTopupStatus.paid;
      case 'expired':
        return CoinTopupStatus.expired;
      case 'failed':
        return CoinTopupStatus.failed;
      case 'cancelled':
        return CoinTopupStatus.cancelled;
      case 'refund_pending':
        return CoinTopupStatus.refundPending;
      case 'partially_refunded':
        return CoinTopupStatus.partiallyRefunded;
      case 'refunded':
        return CoinTopupStatus.refunded;
      case 'review_required':
      default:
        return CoinTopupStatus.reviewRequired;
    }
  }

  String get apiValue {
    switch (this) {
      case CoinTopupStatus.creating:
        return 'creating';
      case CoinTopupStatus.pending:
        return 'pending';
      case CoinTopupStatus.paid:
        return 'paid';
      case CoinTopupStatus.expired:
        return 'expired';
      case CoinTopupStatus.failed:
        return 'failed';
      case CoinTopupStatus.cancelled:
        return 'cancelled';
      case CoinTopupStatus.refundPending:
        return 'refund_pending';
      case CoinTopupStatus.partiallyRefunded:
        return 'partially_refunded';
      case CoinTopupStatus.refunded:
        return 'refunded';
      case CoinTopupStatus.reviewRequired:
        return 'review_required';
    }
  }

  bool get isActivePending =>
      this == CoinTopupStatus.creating || this == CoinTopupStatus.pending;

  bool get isSuccess => this == CoinTopupStatus.paid;

  bool get isRefundOrReview =>
      this == CoinTopupStatus.refundPending ||
      this == CoinTopupStatus.partiallyRefunded ||
      this == CoinTopupStatus.refunded ||
      this == CoinTopupStatus.reviewRequired;
}

class CoinTopupPackageSnapshot {
  final String id;
  final String name;
  final int coins;
  final int bonusCoins;

  const CoinTopupPackageSnapshot({
    required this.id,
    required this.name,
    required this.coins,
    this.bonusCoins = 0,
  });
}

class CoinTopupOrderEntity {
  final String id;
  final String orderId;
  final CoinTopupPackageSnapshot package;
  final int amountIdr;
  final String currency;
  final int totalCoins;
  final String paymentMethod;
  final CoinTopupStatus status;
  final String? qrImageUrl;
  final DateTime? expiresAt;
  final DateTime? paidAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CoinTopupOrderEntity({
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

  String get formattedAmountIdr {
    final str = amountIdr.toString();
    final formatted = str.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );
    return 'Rp $formatted';
  }
}

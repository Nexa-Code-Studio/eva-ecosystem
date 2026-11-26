import 'package:flutter/foundation.dart';

@immutable
class ExtensionSlotOption {
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final bool isAvailable;

  const ExtensionSlotOption({
    required this.startTime,
    required this.endTime,
    this.durationMinutes = 30,
    this.isAvailable = true,
  });
}

@immutable
class ExtensionAvailabilityEntity {
  final String sessionId;
  final bool canExtend;
  final int extensionDurationMinutes;
  final double extensionPrice;
  final String? reason;
  final List<ExtensionSlotOption> nextAvailableSlots;

  const ExtensionAvailabilityEntity({
    required this.sessionId,
    required this.canExtend,
    this.extensionDurationMinutes = 30,
    this.extensionPrice = 0,
    this.reason,
    this.nextAvailableSlots = const [],
  });

  int get extensionCoins => extensionPrice.round();
}

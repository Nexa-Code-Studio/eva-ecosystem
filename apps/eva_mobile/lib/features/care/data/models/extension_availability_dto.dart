import '../../domain/entities/extension_availability_entity.dart';

class ExtensionSlotOptionDto {
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final bool isAvailable;

  const ExtensionSlotOptionDto({
    required this.startTime,
    required this.endTime,
    this.durationMinutes = 30,
    this.isAvailable = true,
  });

  factory ExtensionSlotOptionDto.fromJson(Map<String, dynamic> json) {
    return ExtensionSlotOptionDto(
      startTime: DateTime.tryParse(json['start_time']?.toString() ?? '') ??
          DateTime.now(),
      endTime: DateTime.tryParse(json['end_time']?.toString() ?? '') ??
          DateTime.now().add(const Duration(minutes: 30)),
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 30,
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }

  ExtensionSlotOption toEntity() => ExtensionSlotOption(
        startTime: startTime,
        endTime: endTime,
        durationMinutes: durationMinutes,
        isAvailable: isAvailable,
      );
}

class ExtensionAvailabilityDto {
  final String sessionId;
  final bool canExtend;
  final int extensionDurationMinutes;
  final double extensionPrice;
  final String? reason;
  final List<ExtensionSlotOptionDto> nextAvailableSlots;

  const ExtensionAvailabilityDto({
    required this.sessionId,
    required this.canExtend,
    this.extensionDurationMinutes = 30,
    this.extensionPrice = 0,
    this.reason,
    this.nextAvailableSlots = const [],
  });

  factory ExtensionAvailabilityDto.fromJson(Map<String, dynamic> json) {
    final rawSlots = json['next_available_slots'] as List<dynamic>? ?? const [];
    return ExtensionAvailabilityDto(
      sessionId: json['session_id']?.toString() ?? '',
      canExtend: json['can_extend'] as bool? ?? false,
      extensionDurationMinutes:
          (json['extension_duration_minutes'] as num?)?.toInt() ?? 30,
      extensionPrice: (json['extension_price'] as num?)?.toDouble() ?? 0,
      reason: json['reason']?.toString(),
      nextAvailableSlots: rawSlots
          .whereType<Map<String, dynamic>>()
          .map(ExtensionSlotOptionDto.fromJson)
          .toList(),
    );
  }

  ExtensionAvailabilityEntity toEntity() => ExtensionAvailabilityEntity(
        sessionId: sessionId,
        canExtend: canExtend,
        extensionDurationMinutes: extensionDurationMinutes,
        extensionPrice: extensionPrice,
        reason: reason,
        nextAvailableSlots:
            nextAvailableSlots.map((slot) => slot.toEntity()).toList(),
      );
}

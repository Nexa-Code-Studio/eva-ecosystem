import 'package:flutter/material.dart';
import '../../domain/entities/counselor_timeline_entity.dart';

TimeOfDay parseTimeOfDay(String timeStr) {
  final clean = timeStr.trim();
  final parts = clean.split(':');
  if (parts.length >= 2) {
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }
  return const TimeOfDay(hour: 8, minute: 0);
}

String formatTimeOfDay(TimeOfDay time) {
  final h = time.hour.toString().padLeft(2, '0');
  final m = time.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

class OperatingHoursDto {
  final String start;
  final String end;

  const OperatingHoursDto({
    required this.start,
    required this.end,
  });

  factory OperatingHoursDto.fromJson(Map<String, dynamic> json) {
    return OperatingHoursDto(
      start: json['start'] as String? ?? '08:00',
      end: json['end'] as String? ?? '17:00',
    );
  }

  Map<String, dynamic> toJson() => {
        'start': start,
        'end': end,
      };

  OperatingHoursEntity toEntity() {
    return OperatingHoursEntity(
      start: parseTimeOfDay(start),
      end: parseTimeOfDay(end),
    );
  }
}

class BlockedRangeDto {
  final String start;
  final String end;
  final String type;
  final String? label;

  const BlockedRangeDto({
    required this.start,
    required this.end,
    required this.type,
    this.label,
  });

  factory BlockedRangeDto.fromJson(Map<String, dynamic> json) {
    return BlockedRangeDto(
      start: json['start'] as String? ?? '00:00',
      end: json['end'] as String? ?? '00:00',
      type: json['type'] as String? ?? 'break',
      label: json['label'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'start': start,
        'end': end,
        'type': type,
        if (label != null) 'label': label,
      };

  BlockedRangeEntity toEntity() {
    return BlockedRangeEntity(
      start: parseTimeOfDay(start),
      end: parseTimeOfDay(end),
      type: BlockedRangeType.fromString(type),
      label: label,
    );
  }
}

class TimeRangeDto {
  final String start;
  final String end;

  const TimeRangeDto({
    required this.start,
    required this.end,
  });

  factory TimeRangeDto.fromJson(Map<String, dynamic> json) {
    return TimeRangeDto(
      start: json['start'] as String? ?? '00:00',
      end: json['end'] as String? ?? '00:00',
    );
  }

  Map<String, dynamic> toJson() => {
        'start': start,
        'end': end,
      };

  TimeRangeEntity toEntity() {
    return TimeRangeEntity(
      start: parseTimeOfDay(start),
      end: parseTimeOfDay(end),
    );
  }
}

class CounselorTimelineDto {
  final String counselorId;
  final String date;
  final OperatingHoursDto operatingHours;
  final List<BlockedRangeDto> blockedRanges;
  final List<TimeRangeDto> availableWindows;
  final int bufferTimeMinutes;

  const CounselorTimelineDto({
    required this.counselorId,
    required this.date,
    required this.operatingHours,
    this.blockedRanges = const [],
    this.availableWindows = const [],
    this.bufferTimeMinutes = 0,
  });

  factory CounselorTimelineDto.fromJson(Map<String, dynamic> json) {
    final opHoursRaw = json['operating_hours'];
    final operatingHours = opHoursRaw is Map<String, dynamic>
        ? OperatingHoursDto.fromJson(opHoursRaw)
        : const OperatingHoursDto(start: '08:00', end: '17:00');

    final blockedList = (json['blocked_ranges'] as List? ?? [])
        .map((e) => BlockedRangeDto.fromJson(e as Map<String, dynamic>))
        .toList();

    final availableList = (json['available_windows'] as List? ?? [])
        .map((e) => TimeRangeDto.fromJson(e as Map<String, dynamic>))
        .toList();

    return CounselorTimelineDto(
      counselorId: json['counselor_id'] as String? ?? '',
      date: json['date'] as String? ?? '',
      operatingHours: operatingHours,
      blockedRanges: blockedList,
      availableWindows: availableList,
      bufferTimeMinutes: (json['buffer_time_minutes'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'counselor_id': counselorId,
        'date': date,
        'operating_hours': operatingHours.toJson(),
        'blocked_ranges': blockedRanges.map((e) => e.toJson()).toList(),
        'available_windows': availableWindows.map((e) => e.toJson()).toList(),
        'buffer_time_minutes': bufferTimeMinutes,
      };

  CounselorTimelineEntity toEntity() {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(date);
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return CounselorTimelineEntity(
      counselorId: counselorId,
      date: parsedDate,
      operatingHours: operatingHours.toEntity(),
      blockedRanges: blockedRanges.map((e) => e.toEntity()).toList(),
      availableWindows: availableWindows.map((e) => e.toEntity()).toList(),
      bufferTimeMinutes: bufferTimeMinutes,
    );
  }
}

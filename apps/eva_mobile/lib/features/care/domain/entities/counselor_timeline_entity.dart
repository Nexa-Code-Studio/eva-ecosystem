import 'package:flutter/material.dart';

enum BlockedRangeType {
  breakTime,
  booked,
  buffer;

  static BlockedRangeType fromString(String val) {
    switch (val.toLowerCase()) {
      case 'break':
      case 'break_time':
      case 'breaktime':
        return BlockedRangeType.breakTime;
      case 'booked':
        return BlockedRangeType.booked;
      case 'buffer':
      default:
        return BlockedRangeType.buffer;
    }
  }

  String get displayName {
    switch (this) {
      case BlockedRangeType.breakTime:
        return 'Istirahat';
      case BlockedRangeType.booked:
        return 'Terisi';
      case BlockedRangeType.buffer:
        return 'Jeda Sesi';
    }
  }
}

@immutable
class OperatingHoursEntity {
  final TimeOfDay start;
  final TimeOfDay end;

  const OperatingHoursEntity({
    required this.start,
    required this.end,
  });

  int get startMinutes => start.hour * 60 + start.minute;
  int get endMinutes => end.hour * 60 + end.minute;
  int get totalSpanMinutes => endMinutes - startMinutes;

  String get startFormatted =>
      '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
  String get endFormatted =>
      '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
}

@immutable
class BlockedRangeEntity {
  final TimeOfDay start;
  final TimeOfDay end;
  final BlockedRangeType type;
  final String? label;

  const BlockedRangeEntity({
    required this.start,
    required this.end,
    required this.type,
    this.label,
  });

  int get startMinutes => start.hour * 60 + start.minute;
  int get endMinutes => end.hour * 60 + end.minute;

  String get startFormatted =>
      '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
  String get endFormatted =>
      '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';

  bool overlapsWith(int rangeStartMin, int rangeEndMin) {
    return rangeStartMin < endMinutes && rangeEndMin > startMinutes;
  }
}

@immutable
class TimeRangeEntity {
  final TimeOfDay start;
  final TimeOfDay end;

  const TimeRangeEntity({
    required this.start,
    required this.end,
  });

  int get startMinutes => start.hour * 60 + start.minute;
  int get endMinutes => end.hour * 60 + end.minute;

  String get startFormatted =>
      '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
  String get endFormatted =>
      '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
}

@immutable
class CollisionResult {
  final bool hasClash;
  final String? reason;
  final BlockedRangeType? clashType;

  const CollisionResult({
    required this.hasClash,
    this.reason,
    this.clashType,
  });

  const CollisionResult.safe()
      : hasClash = false,
        reason = null,
        clashType = null;
}

@immutable
class CounselorTimelineEntity {
  final String counselorId;
  final DateTime date;
  final OperatingHoursEntity operatingHours;
  final List<BlockedRangeEntity> blockedRanges;
  final List<TimeRangeEntity> availableWindows;
  final int bufferTimeMinutes;

  const CounselorTimelineEntity({
    required this.counselorId,
    required this.date,
    required this.operatingHours,
    this.blockedRanges = const [],
    this.availableWindows = const [],
    this.bufferTimeMinutes = 0,
  });

  CollisionResult evaluateSelection(TimeOfDay selectedStart, int durationMinutes) {
    final startMin = selectedStart.hour * 60 + selectedStart.minute;
    final endMin = startMin + durationMinutes;

    if (startMin < operatingHours.startMinutes) {
      return CollisionResult(
        hasClash: true,
        reason: 'Sebelum jam buka operasional (${operatingHours.startFormatted})',
      );
    }

    if (endMin > operatingHours.endMinutes) {
      return CollisionResult(
        hasClash: true,
        reason: 'Melebihi jam tutup operasional (${operatingHours.endFormatted})',
      );
    }

    for (final blocked in blockedRanges) {
      if (blocked.overlapsWith(startMin, endMin)) {
        final label = blocked.label ?? blocked.type.displayName;
        return CollisionResult(
          hasClash: true,
          reason: 'Menabrak $label (${blocked.startFormatted} - ${blocked.endFormatted})',
          clashType: blocked.type,
        );
      }
      if (bufferTimeMinutes > 0 &&
          blocked.type == BlockedRangeType.booked &&
          blocked.overlapsWith(startMin, endMin + bufferTimeMinutes)) {
        return CollisionResult(
          hasClash: true,
          reason:
              'Jeda buffer ($bufferTimeMinutes menit) sebelum ${blocked.label ?? blocked.type.displayName} (${blocked.startFormatted})',
          clashType: BlockedRangeType.buffer,
        );
      }
    }

    return const CollisionResult.safe();
  }
}

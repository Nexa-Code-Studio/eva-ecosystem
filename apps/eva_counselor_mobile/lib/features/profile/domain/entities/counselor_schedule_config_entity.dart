import 'package:flutter/material.dart';

const List<String> kCounselorWeekdayKeys = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

String weekdayKeyFromDate(DateTime date) {
  final idx = (date.weekday - 1).clamp(0, 6);
  return kCounselorWeekdayKeys[idx];
}

TimeOfDay parseScheduleTimeOfDay(String raw, {TimeOfDay fallback = const TimeOfDay(hour: 8, minute: 0)}) {
  final parts = raw.trim().split(':');
  if (parts.length >= 2) {
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h != null && m != null && h >= 0 && h <= 23 && m >= 0 && m <= 59) {
      return TimeOfDay(hour: h, minute: m);
    }
  }
  return fallback;
}

String formatScheduleTimeOfDay(TimeOfDay time) {
  final h = time.hour.toString().padLeft(2, '0');
  final m = time.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

class CounselorBreakSlotEntity {
  final String start;
  final String end;
  final String label;

  const CounselorBreakSlotEntity({
    required this.start,
    required this.end,
    this.label = 'Istirahat',
  });

  factory CounselorBreakSlotEntity.fromJson(Map<String, dynamic> json) {
    return CounselorBreakSlotEntity(
      start: json['start']?.toString() ?? '12:00',
      end: json['end']?.toString() ?? '13:00',
      label: json['label']?.toString() ?? 'Istirahat',
    );
  }

  Map<String, dynamic> toJson() => {
        'start': start,
        'end': end,
        'label': label,
      };
}

class CounselorDayScheduleEntity {
  final bool isActive;
  final String startTime;
  final String endTime;
  final List<CounselorBreakSlotEntity> breaks;

  const CounselorDayScheduleEntity({
    required this.isActive,
    required this.startTime,
    required this.endTime,
    this.breaks = const [],
  });

  factory CounselorDayScheduleEntity.fromJson(Map<String, dynamic> json) {
    final opHours = json['operating_hours'] as Map<String, dynamic>? ?? const {};
    final rawBreaks = json['breaks'] as List<dynamic>? ?? const [];
    return CounselorDayScheduleEntity(
      isActive: json['is_active'] as bool? ?? true,
      startTime: opHours['start']?.toString() ?? '08:00',
      endTime: opHours['end']?.toString() ?? '17:00',
      breaks: rawBreaks
          .whereType<Map<String, dynamic>>()
          .map(CounselorBreakSlotEntity.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'is_active': isActive,
        'operating_hours': {
          'start': startTime,
          'end': endTime,
        },
        'breaks': breaks.map((b) => b.toJson()).toList(),
      };
}

class CounselorScheduleConfigEntity {
  final String counselorId;
  final int bufferTimeMinutes;
  final Map<String, CounselorDayScheduleEntity> days;

  const CounselorScheduleConfigEntity({
    required this.counselorId,
    required this.bufferTimeMinutes,
    required this.days,
  });

  factory CounselorScheduleConfigEntity.fromJson(Map<String, dynamic> json) {
    final rawCfg = json['schedule_config'] as Map<String, dynamic>? ?? const {};
    final parsed = <String, CounselorDayScheduleEntity>{};
    for (final entry in rawCfg.entries) {
      if (entry.value is Map<String, dynamic>) {
        parsed[entry.key.toLowerCase()] =
            CounselorDayScheduleEntity.fromJson(entry.value as Map<String, dynamic>);
      }
    }
    return CounselorScheduleConfigEntity(
      counselorId: json['counselor_id']?.toString() ?? '',
      bufferTimeMinutes: (json['buffer_time_minutes'] as num?)?.toInt() ?? 10,
      days: parsed,
    );
  }

  factory CounselorScheduleConfigEntity.defaults({String counselorId = ''}) {
    return CounselorScheduleConfigEntity(
      counselorId: counselorId,
      bufferTimeMinutes: 10,
      days: {
        for (int i = 0; i < kCounselorWeekdayKeys.length; i++)
          kCounselorWeekdayKeys[i]: CounselorDayScheduleEntity(
            isActive: i < 5,
            startTime: i < 5 ? '08:00' : '09:00',
            endTime: i < 5 ? '17:00' : '14:00',
            breaks: i < 5
                ? const [
                    CounselorBreakSlotEntity(
                      start: '12:00',
                      end: '13:00',
                      label: 'Istirahat Siang',
                    ),
                  ]
                : const [],
          ),
      },
    );
  }

  Map<String, dynamic> toScheduleConfigMap() => {
        for (final entry in days.entries) entry.key: entry.value.toJson(),
      };
}

class CounselorBlockedRangeEntity {
  final String start;
  final String end;
  final String type; // 'break', 'booked', 'buffer'
  final String? label;

  const CounselorBlockedRangeEntity({
    required this.start,
    required this.end,
    required this.type,
    this.label,
  });

  factory CounselorBlockedRangeEntity.fromJson(Map<String, dynamic> json) {
    return CounselorBlockedRangeEntity(
      start: json['start']?.toString() ?? '00:00',
      end: json['end']?.toString() ?? '00:00',
      type: json['type']?.toString() ?? 'break',
      label: json['label']?.toString(),
    );
  }
}

class CounselorTimeRangeEntity {
  final String start;
  final String end;

  const CounselorTimeRangeEntity({required this.start, required this.end});

  factory CounselorTimeRangeEntity.fromJson(Map<String, dynamic> json) {
    return CounselorTimeRangeEntity(
      start: json['start']?.toString() ?? '08:00',
      end: json['end']?.toString() ?? '17:00',
    );
  }
}

class CounselorBookedSessionEntity {
  final String sessionId;
  final String sessionCode;
  final String patientId;
  final String patientName;
  final String start;
  final String end;
  final int durationMinutes;
  final String status;
  final String? complaints;

  const CounselorBookedSessionEntity({
    required this.sessionId,
    required this.sessionCode,
    required this.patientId,
    required this.patientName,
    required this.start,
    required this.end,
    required this.durationMinutes,
    required this.status,
    this.complaints,
  });

  factory CounselorBookedSessionEntity.fromJson(Map<String, dynamic> json) {
    return CounselorBookedSessionEntity(
      sessionId: json['session_id']?.toString() ?? '',
      sessionCode: json['session_code']?.toString() ?? '',
      patientId: json['patient_id']?.toString() ?? '',
      patientName: json['patient_name']?.toString() ?? 'Pasien EVA',
      start: json['start']?.toString() ?? '08:00',
      end: json['end']?.toString() ?? '08:30',
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 30,
      status: json['status']?.toString() ?? 'scheduled',
      complaints: json['complaints']?.toString(),
    );
  }
}

class CounselorDailyTimelineEntity {
  final String counselorId;
  final String date;
  final bool isActive;
  final bool isOnline;
  final String operatingStart;
  final String operatingEnd;
  final int bufferTimeMinutes;
  final List<CounselorBlockedRangeEntity> blockedRanges;
  final List<CounselorTimeRangeEntity> availableWindows;
  final List<CounselorBookedSessionEntity> bookedSessions;

  const CounselorDailyTimelineEntity({
    required this.counselorId,
    required this.date,
    this.isActive = true,
    this.isOnline = true,
    required this.operatingStart,
    required this.operatingEnd,
    this.bufferTimeMinutes = 10,
    this.blockedRanges = const [],
    this.availableWindows = const [],
    this.bookedSessions = const [],
  });

  factory CounselorDailyTimelineEntity.empty(
    String date, {
    String counselorId = '',
  }) {
    return CounselorDailyTimelineEntity(
      counselorId: counselorId,
      date: date,
      isActive: true,
      isOnline: true,
      operatingStart: '08:00',
      operatingEnd: '17:00',
    );
  }

  factory CounselorDailyTimelineEntity.fromJson(Map<String, dynamic> json) {
    final op = json['operating_hours'] as Map<String, dynamic>? ?? const {};
    return CounselorDailyTimelineEntity(
      counselorId: json['counselor_id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      isActive: json['is_active'] as bool? ?? true,
      isOnline: json['is_online'] as bool? ?? true,
      operatingStart: op['start']?.toString() ?? '08:00',
      operatingEnd: op['end']?.toString() ?? '17:00',
      bufferTimeMinutes: (json['buffer_time_minutes'] as num?)?.toInt() ?? 10,
      blockedRanges: (json['blocked_ranges'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CounselorBlockedRangeEntity.fromJson)
          .toList(),
      availableWindows: (json['available_windows'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CounselorTimeRangeEntity.fromJson)
          .toList(),
      bookedSessions: (json['booked_sessions'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CounselorBookedSessionEntity.fromJson)
          .toList(),
    );
  }
}

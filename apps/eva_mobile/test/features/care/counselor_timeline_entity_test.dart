import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eva_mobile/features/care/domain/entities/counselor_timeline_entity.dart';

void main() {
  group('CounselorTimelineEntity & Collision Detection Tests', () {
    const opHours = OperatingHoursEntity(
      start: TimeOfDay(hour: 8, minute: 0),
      end: TimeOfDay(hour: 17, minute: 0),
    );

    final blockedRanges = [
      const BlockedRangeEntity(
        start: TimeOfDay(hour: 10, minute: 0),
        end: TimeOfDay(hour: 11, minute: 0),
        type: BlockedRangeType.booked,
        label: 'Sesi Pasien Lain',
      ),
      const BlockedRangeEntity(
        start: TimeOfDay(hour: 11, minute: 0),
        end: TimeOfDay(hour: 11, minute: 15),
        type: BlockedRangeType.buffer,
        label: 'Jeda Sesi',
      ),
      const BlockedRangeEntity(
        start: TimeOfDay(hour: 12, minute: 0),
        end: TimeOfDay(hour: 13, minute: 0),
        type: BlockedRangeType.breakTime,
        label: 'Istirahat Siang',
      ),
    ];

    final timeline = CounselorTimelineEntity(
      counselorId: 'psy_test_1',
      date: DateTime(2026, 11, 24),
      operatingHours: opHours,
      blockedRanges: blockedRanges,
    );

    test('OperatingHoursEntity calculates span and formats correctly', () {
      expect(opHours.startMinutes, 480);
      expect(opHours.endMinutes, 1020);
      expect(opHours.totalSpanMinutes, 540);
      expect(opHours.startFormatted, '08:00');
      expect(opHours.endFormatted, '17:00');
    });

    test('BlockedRangeEntity detects overlap correctly', () {
      final breakBlock = blockedRanges[2]; // 12:00 - 13:00 (720 - 780 min)
      // 11:30 - 12:30 overlaps with 12:00 - 13:00
      expect(breakBlock.overlapsWith(690, 750), isTrue);
      // 12:15 - 12:45 is inside 12:00 - 13:00
      expect(breakBlock.overlapsWith(735, 765), isTrue);
      // 10:00 - 11:00 does not overlap with 12:00 - 13:00
      expect(breakBlock.overlapsWith(600, 660), isFalse);
    });

    test('Selection before operating hours returns collision', () {
      final collision = timeline.evaluateSelection(const TimeOfDay(hour: 7, minute: 30), 30);
      expect(collision.hasClash, isTrue);
      expect(collision.reason, contains('Sebelum jam buka'));
    });

    test('Selection exceeding operating hours returns collision', () {
      final collision = timeline.evaluateSelection(const TimeOfDay(hour: 16, minute: 45), 30);
      expect(collision.hasClash, isTrue);
      expect(collision.reason, contains('Melebihi jam tutup'));
    });

    test('Selection colliding with booked session returns clash reason', () {
      final collision = timeline.evaluateSelection(const TimeOfDay(hour: 10, minute: 30), 30);
      expect(collision.hasClash, isTrue);
      expect(collision.reason, contains('Sesi Pasien Lain'));
      expect(collision.clashType, BlockedRangeType.booked);
    });

    test('Selection colliding with break time returns clash reason', () {
      final collision = timeline.evaluateSelection(const TimeOfDay(hour: 12, minute: 15), 30);
      expect(collision.hasClash, isTrue);
      expect(collision.reason, contains('Istirahat Siang'));
      expect(collision.clashType, BlockedRangeType.breakTime);
    });

    test('Selection colliding with buffer returns clash reason', () {
      final collision = timeline.evaluateSelection(const TimeOfDay(hour: 11, minute: 0), 30);
      expect(collision.hasClash, isTrue);
      expect(collision.reason, contains('Jeda Sesi'));
      expect(collision.clashType, BlockedRangeType.buffer);
    });

    test('Valid selection in available slot returns safe result', () {
      // 08:30 - 09:30 (60 minutes = 2 sessions) in open morning window
      final collision = timeline.evaluateSelection(const TimeOfDay(hour: 8, minute: 30), 60);
      expect(collision.hasClash, isFalse);
      expect(collision.reason, isNull);
    });

    test('Valid selection in afternoon open slot returns safe result', () {
      // 13:30 - 14:30 (60 minutes) in open afternoon window
      final collision = timeline.evaluateSelection(const TimeOfDay(hour: 13, minute: 30), 60);
      expect(collision.hasClash, isFalse);
      expect(collision.reason, isNull);
    });

    test('Dynamic arbitrary minute start time (08:37 - 09:07) and pre-session buffer check work accurately', () {
      final bufferedTimeline = CounselorTimelineEntity(
        counselorId: 'psy_test_1',
        date: DateTime(2026, 11, 24),
        operatingHours: opHours,
        blockedRanges: blockedRanges,
        bufferTimeMinutes: 10,
      );

      // 08:37 - 09:07 is completely free and > 10m before 10:00 booked session
      final ok = bufferedTimeline.evaluateSelection(const TimeOfDay(hour: 8, minute: 37), 30);
      expect(ok.hasClash, isFalse);

      // 09:25 - 09:55 leaves only 5m buffer before 10:00 -> caught by buffer guard
      final preBufferClash =
          bufferedTimeline.evaluateSelection(const TimeOfDay(hour: 9, minute: 25), 30);
      expect(preBufferClash.hasClash, isTrue);
      expect(preBufferClash.clashType, BlockedRangeType.buffer);
    });
  });
}

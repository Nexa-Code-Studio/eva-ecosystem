import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eva_mobile/features/care/domain/entities/counselor_timeline_entity.dart';
import 'package:eva_mobile/features/care/presentation/widgets/psychologist_availability_timeline_bar.dart';

void main() {
  const opHours = OperatingHoursEntity(
    start: TimeOfDay(hour: 8, minute: 0),
    end: TimeOfDay(hour: 17, minute: 0),
  );

  final testTimeline = CounselorTimelineEntity(
    counselorId: 'psy_test_1',
    date: DateTime(2026, 11, 24),
    operatingHours: opHours,
    blockedRanges: const [
      BlockedRangeEntity(
        start: TimeOfDay(hour: 12, minute: 0),
        end: TimeOfDay(hour: 13, minute: 0),
        type: BlockedRangeType.breakTime,
        label: 'Istirahat Siang',
      ),
      BlockedRangeEntity(
        start: TimeOfDay(hour: 10, minute: 0),
        end: TimeOfDay(hour: 11, minute: 0),
        type: BlockedRangeType.booked,
        label: 'Sesi Pasien Lain',
      ),
    ],
  );

  Widget createWidget({
    CounselorTimelineEntity? timeline,
    TimeOfDay? selectedStartTime = const TimeOfDay(hour: 9, minute: 0),
    int durationMinutes = 30,
    ValueChanged<TimeOfDay>? onTimeSelected,
    CollisionResult collision = const CollisionResult.safe(),
    TimeOfDay? minSelectableTime,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 500,
            child: PsychologistAvailabilityTimelineBar(
              timeline: timeline ?? testTimeline,
              selectedStartTime: selectedStartTime,
              durationMinutes: durationMinutes,
              onTimeSelected: onTimeSelected ?? (_) {},
              collision: collision,
              minSelectableTime: minSelectableTime,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Renders operating hours, simplified legends, and selected time', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    expect(find.text('Buka: 08:00'), findsOneWidget);
    expect(find.text('Tutup: 17:00'), findsOneWidget);

    expect(find.text('Tersedia'), findsOneWidget);
    expect(find.text('Tidak Tersedia'), findsOneWidget);
    expect(find.text('Istirahat'), findsNothing);
    expect(find.text('Terisi'), findsNothing);
    expect(find.text('Jeda Sesi'), findsNothing);
    expect(find.text('Pilihan Anda'), findsNothing);

    expect(find.text('Pilihan: 09:00 - 09:30 (30 Menit)'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('Prevents tapping or dragging into past hours before minSelectableTime', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    TimeOfDay? tappedTime;

    await tester.pumpWidget(createWidget(
      selectedStartTime: const TimeOfDay(hour: 13, minute: 30),
      minSelectableTime: const TimeOfDay(hour: 13, minute: 0),
      onTimeSelected: (t) => tappedTime = t,
    ));
    await tester.pumpAndSettle();

    final barFinder = find.byType(GestureDetector);
    final topLeft = tester.getTopLeft(barFinder);
    final size = tester.getSize(barFinder);

    // Tap near the start (08:30 area, which is well before 13:00 cutoff)
    await tester.tapAt(Offset(topLeft.dx + size.width * 0.05, topLeft.dy + size.height / 2));
    await tester.pumpAndSettle();

    expect(tappedTime, equals(const TimeOfDay(hour: 13, minute: 0)));

    // Drag further left toward 08:00; selection remains clamped at 13:00
    await tester.dragFrom(
      Offset(topLeft.dx + size.width * 0.5, topLeft.dy + size.height / 2),
      Offset(-size.width * 0.45, 0),
    );
    await tester.pumpAndSettle();

    expect(tappedTime, equals(const TimeOfDay(hour: 13, minute: 0)));
  });

  testWidgets('Merges past hours and adjacent blocked ranges into a single seamless segment', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final denseTimeline = CounselorTimelineEntity(
      counselorId: 'psy_test_1',
      date: DateTime(2026, 11, 24),
      operatingHours: opHours,
      blockedRanges: const [
        BlockedRangeEntity(
          start: TimeOfDay(hour: 9, minute: 0),
          end: TimeOfDay(hour: 10, minute: 0),
          type: BlockedRangeType.booked,
        ),
        BlockedRangeEntity(
          start: TimeOfDay(hour: 10, minute: 0),
          end: TimeOfDay(hour: 10, minute: 15),
          type: BlockedRangeType.buffer,
        ),
        BlockedRangeEntity(
          start: TimeOfDay(hour: 12, minute: 0),
          end: TimeOfDay(hour: 13, minute: 0),
          type: BlockedRangeType.breakTime,
        ),
      ],
    );

    await tester.pumpWidget(createWidget(
      timeline: denseTimeline,
      selectedStartTime: const TimeOfDay(hour: 14, minute: 0),
      minSelectableTime: const TimeOfDay(hour: 13, minute: 30),
    ));
    await tester.pumpAndSettle();

    // Past cutoff 08:00-13:30 overlaps all three blocked ranges -> single merged segment
    expect(find.byKey(const Key('timeline_unavailable_segment')), findsOneWidget);
  });

  testWidgets('Displays warning banner when collision occurs', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const collision = CollisionResult(
      hasClash: true,
      reason: 'Menabrak Istirahat Siang (12:00 - 13:00)',
      clashType: BlockedRangeType.breakTime,
    );

    await tester.pumpWidget(createWidget(
      selectedStartTime: const TimeOfDay(hour: 12, minute: 15),
      collision: collision,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Menabrak Istirahat Siang (12:00 - 13:00)'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
  });

  testWidgets('Tap on timeline triggers dynamic minute-level onTimeSelected within operating hours', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    TimeOfDay? tappedTime;

    await tester.pumpWidget(createWidget(
      onTimeSelected: (t) => tappedTime = t,
    ));
    await tester.pumpAndSettle();

    // Tap on the progress bar GestureDetector slightly off-center to verify free minute precision
    final barFinder = find.byType(GestureDetector);
    expect(barFinder, findsOneWidget);

    final topLeft = tester.getTopLeft(barFinder);
    final size = tester.getSize(barFinder);
    await tester.tapAt(Offset(topLeft.dx + size.width * 0.137, topLeft.dy + size.height / 2));
    await tester.pumpAndSettle();

    expect(tappedTime, isNotNull);
    final totalMin = tappedTime!.hour * 60 + tappedTime!.minute;
    expect(totalMin, greaterThanOrEqualTo(opHours.startMinutes));
    expect(totalMin, lessThanOrEqualTo(opHours.endMinutes - 30));
    expect(tappedTime!.minute % 15, isNot(equals(0)));
  });

  testWidgets('Displays arbitrary dynamic minute range (e.g. 08:37 - 09:07)', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidget(
      selectedStartTime: const TimeOfDay(hour: 8, minute: 37),
      durationMinutes: 30,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Pilihan: 08:37 - 09:07 (30 Menit)'), findsOneWidget);
  });
}

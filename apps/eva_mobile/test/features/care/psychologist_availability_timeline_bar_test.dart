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
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Renders operating hours, legends, and selected time', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    expect(find.text('Buka: 08:00'), findsOneWidget);
    expect(find.text('Tutup: 17:00'), findsOneWidget);

    expect(find.text('Tersedia'), findsOneWidget);
    expect(find.text('Istirahat'), findsOneWidget);
    expect(find.text('Terisi'), findsOneWidget);
    expect(find.text('Jeda Sesi'), findsOneWidget);
    expect(find.text('Pilihan Anda'), findsOneWidget);

    expect(find.text('Pilihan: 09:00 - 09:30 (30 Menit)'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
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

  testWidgets('Tap on timeline triggers onTimeSelected with snapped 15-minute time', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    TimeOfDay? tappedTime;

    await tester.pumpWidget(createWidget(
      onTimeSelected: (t) => tappedTime = t,
    ));
    await tester.pumpAndSettle();

    // Tap on the progress bar GestureDetector
    final barFinder = find.byType(GestureDetector);
    expect(barFinder, findsOneWidget);

    await tester.tap(barFinder);
    await tester.pumpAndSettle();

    expect(tappedTime, isNotNull);
    // Verified that tappedTime minutes is a multiple of 15
    expect(tappedTime!.minute % 15, equals(0));
  });
}

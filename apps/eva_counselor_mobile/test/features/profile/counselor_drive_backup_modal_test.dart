import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eva_counselor_mobile/features/profile/presentation/widgets/counselor_drive_backup_modal.dart';
import 'package:eva_counselor_mobile/features/profile/presentation/widgets/counselor_profile_drive_card.dart';
import 'package:eva_counselor_mobile/features/auth/domain/entities/psychologist_user_entity.dart';

void main() {
  final dummyUser = PsychologistUserEntity(
    id: 'psy-001',
    fullName: 'dr. Sarah Anindya, Sp.KJ',
    titleDegree: 'M.Psi',
    email: 'sarah.anindya@eva.id',
    strNumber: 'STR-99182',
    association: 'HIMPSI',
    specializations: const ['Kecemasan', 'Depresi'],
    yearsOfExperience: 7,
    consultationRatePerHour: 150000,
    verificationStatus: VerificationStatus.verified,
    googleDriveEmail: 'sarah.anindya@gmail.com',
    lastDriveBackup: DateTime(2026, 11, 18, 10, 15),
  );

  group('CounselorDriveBackupModal Tests & Zero-Overflow Verification', () {
    testWidgets(
        'Renders without overflow on ultra-narrow 320px viewport and saves preferences',
        (tester) async {
      // Set narrow screen size (320x640)
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String savedFreq = '';
      bool savedWifi = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () {
                      CounselorDriveBackupModal.show(
                        context: context,
                        user: dummyUser,
                        initialFrequency: 'Mingguan',
                        initialWifiOnly: true,
                        onSave: (freq, wifi) {
                          savedFreq = freq;
                          savedWifi = wifi;
                        },
                      );
                    },
                    child: const Text('Open Modal'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // Open modal
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Verify Title and elements rendered
      expect(find.text('Cadangan Google Drive'), findsOneWidget);
      expect(find.text('Frekuensi Pencadangan:'), findsOneWidget);
      expect(find.text('Harian'), findsOneWidget);
      expect(find.text('Mingguan'), findsOneWidget);
      expect(find.text('Manual'), findsOneWidget);
      expect(find.text('Cadangkan Hanya Melalui Wi-Fi'), findsOneWidget);

      // Select 'Harian' frequency chip
      await tester.tap(find.text('Harian'));
      await tester.pumpAndSettle();

      // Toggle Wi-Fi switch off
      final switchTile = find.byType(Switch);
      expect(switchTile, findsOneWidget);
      await tester.tap(switchTile);
      await tester.pumpAndSettle();

      // Tap Simpan Preferensi
      final saveBtn = find.text('Simpan Preferensi');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify callback received updated state
      expect(savedFreq, 'Harian');
      expect(savedWifi, false);

      // Fast forward past TopToast auto-dismiss timer (2.8s)
      await tester.pump(const Duration(seconds: 4));

      // Verify no overflow error occurred during test
      expect(tester.takeException(), isNull);
    });

    testWidgets('CounselorProfileDriveCard displays backup info and triggers modal',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool backupTriggered = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: CounselorProfileDriveCard(
                  user: dummyUser,
                  backupFrequency: 'Harian',
                  backupWifiOnly: true,
                  isBackingUp: false,
                  onSettingsSaved: (freq, wifi) {},
                  onBackupNow: () => backupTriggered = true,
                  onRestore: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('sarah.anindya@gmail.com'), findsOneWidget);
      expect(find.text('Cadangkan Sekarang'), findsOneWidget);
      expect(find.text('Pulihkan Data'), findsOneWidget);

      // Tap Cadangkan Sekarang
      await tester.tap(find.text('Cadangkan Sekarang'));
      await tester.pump();
      expect(backupTriggered, isTrue);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eva_counselor_mobile/features/auth/domain/entities/psychologist_user_entity.dart';
import 'package:eva_counselor_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:eva_counselor_mobile/features/profile/presentation/widgets/counselor_bank_account_modal.dart';
import 'package:eva_counselor_mobile/features/video_call/data/datasources/mock_video_call_datasource.dart';
import 'package:eva_counselor_mobile/features/video_call/data/repositories/video_call_repository_impl.dart';
import 'package:eva_counselor_mobile/features/video_call/domain/entities/video_call_state_entity.dart';
import 'package:eva_counselor_mobile/features/video_call/presentation/controllers/video_call_controller.dart';
import 'package:eva_counselor_mobile/features/video_call/presentation/screens/video_consultation_screen.dart';

void main() {
  group('In-Call Extension & Consultation Cycle Tests', () {
    late VideoCallRepositoryImpl repository;
    late MockVideoCallDataSource mockDataSource;
    late VideoCallSessionEntity initialSession;

    setUp(() {
      mockDataSource = MockVideoCallDataSource();
      repository = VideoCallRepositoryImpl(dataSource: mockDataSource);
      initialSession = VideoCallSessionEntity(
        sessionId: 'session-001',
        patientId: 'patient-001',
        patientName: 'Rian Pratama',
        scheduledTime: DateTime.now(),
      );
    });

    test('VideoCallSessionEntity default duration is 30 minutes', () {
      expect(initialSession.maxDuration, const Duration(minutes: 30));
      expect(initialSession.isExtended, false);
      expect(initialSession.isExtensionRequested, false);
      expect(initialSession.isExtensionApproved, isNull);
    });

    test('triggerExtensionRequest sets isExtensionRequested to true', () {
      final controller = VideoCallController(repository, initialSession);
      controller.triggerExtensionRequest();

      expect(controller.state.isExtensionRequested, true);
      expect(controller.state.isExtended, false);
    });

    test('approveExtension updates timer to 60:00 and marks isExtended true', () async {
      final controller = VideoCallController(repository, initialSession);
      controller.triggerExtensionRequest();

      final success = await controller.approveExtension();
      expect(success, true);
      expect(controller.state.isExtended, true);
      expect(controller.state.maxDuration, const Duration(minutes: 60));
      expect(controller.state.isExtensionRequested, false);
      expect(controller.state.isExtensionApproved, true);
    });

    test('rejectExtension rejects extension and maintains 30-min duration', () async {
      final controller = VideoCallController(repository, initialSession);
      controller.triggerExtensionRequest();

      await controller.rejectExtension();
      expect(controller.state.isExtended, false);
      expect(controller.state.maxDuration, const Duration(minutes: 30));
      expect(controller.state.isExtensionRequested, false);
      expect(controller.state.isExtensionApproved, false);
    });

    testWidgets('VideoConsultationScreen displays in-call extension prompt and handles approval',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: VideoConsultationScreen(
              sessionId: 'session-test-01',
              patientName: 'Rian Pratama',
              isEarlyEntry: false,
            ),
          ),
        ),
      );

      // Fast forward past initial patient connect (3.5s)
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      expect(find.textContaining('Rian Pratama'), findsWidgets);

      // Tap simulation button
      final simulateBtn = find.byKey(const Key('simulate_extension_btn'));
      expect(simulateBtn, findsOneWidget);
      await tester.tap(simulateBtn);
      await tester.pump();

      expect(find.text('Permintaan Tambah Sesi (+30 Mnt)'), findsOneWidget);
      expect(find.text('Terima (+30 Mnt)'), findsOneWidget);
      expect(find.text('Tolak'), findsOneWidget);

      // Tap 'Terima (+30 Mnt)'
      await tester.tap(find.text('Terima (+30 Mnt)'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.textContaining('/ 60:00'), findsOneWidget);
      expect(find.text('+30m'), findsOneWidget);

      // Fast forward past TopToast auto-dismiss timers (2.8s)
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('CounselorBankAccountModal displays registered bank and enables editing',
        (tester) async {
      final mockUser = const PsychologistUserEntity(
        id: 'counselor-1',
        fullName: 'dr. Sarah Jenkins',
        titleDegree: 'M.Psi',
        email: 'sarah@eva.id',
        strNumber: 'STR-99182',
        association: 'HIMPSI',
        specializations: ['CBT'],
        yearsOfExperience: 5,
        consultationRatePerHour: 150000,
        verificationStatus: VerificationStatus.verified,
        bankName: 'BCA (Bank Central Asia)',
        bankAccountNumber: '8192039182',
        bankAccountHolder: 'dr. Sarah Jenkins, M.Psi',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(
                (ref) => _LocalTestAuthNotifier(mockUser)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => CounselorBankAccountModal.show(ctx),
                  child: const Text('Buka Modal Bank'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Modal Bank'));
      await tester.pumpAndSettle();

      expect(find.text('Rekening Bank Pencairan'), findsOneWidget);
      expect(find.text('BCA (Bank Central Asia)'), findsOneWidget);
      expect(find.text('Ubah Rekening Bank'), findsOneWidget);

      // Tap Ubah Rekening Bank
      await tester.tap(find.text('Ubah Rekening Bank'));
      await tester.pumpAndSettle();

      expect(find.text('Simpan Rekening'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
    });
  });
}

class _LocalTestAuthNotifier extends StateNotifier<AsyncValue<PsychologistUserEntity?>>
    implements AuthStateNotifier {
  _LocalTestAuthNotifier(PsychologistUserEntity user)
      : super(AsyncValue.data(user));

  @override
  void updateBankDetails({
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  }) {
    final cur = state.value;
    if (cur != null) {
      state = AsyncValue.data(cur.copyWith(
        bankName: bankName,
        bankAccountNumber: accountNumber,
        bankAccountHolder: accountHolder,
      ));
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

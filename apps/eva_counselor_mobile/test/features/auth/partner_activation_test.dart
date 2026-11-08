import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eva_counselor_mobile/features/auth/data/datasources/mock_auth_datasource.dart';
import 'package:eva_counselor_mobile/features/auth/data/models/psychologist_auth_dto.dart';
import 'package:eva_counselor_mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:eva_counselor_mobile/features/auth/domain/entities/psychologist_user_entity.dart';
import 'package:eva_counselor_mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:eva_counselor_mobile/features/auth/presentation/screens/partner_counselor_activation_screen.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('Mitra Invitation & Activation Flow Tests', () {
    test('MockAuthDataSource registers partner counselor with verified status and persists login', () async {
      final dataSource = MockAuthDataSource();

      const registerDto = PsychologistRegisterRequestDto(
        fullName: 'Dr. Sarah Lestari, M.Psi., Psikolog',
        titleDegree: 'M.Psi., Psikolog Klinis',
        email: 'sarah.lestari@gmail.com',
        password: 'securePassword123',
        strNumber: 'STR-MITRA-2026-99',
        association: 'HIMPSI',
        specializations: ['Kecemasan Dewasa'],
        yearsOfExperience: 5,
        consultationRate: 180000,
        certificateDocFileName: 'STR_Mitra_Verified.pdf',
        counselorRole: 'professional_partner',
        partnerName: 'RS Mitra Sehati Jakarta',
        sessionDurationMinutes: 50,
        coinsPerSession: 180,
      );

      final registered = await dataSource.register(registerDto);
      expect(registered.verificationStatus, equals('verified'));
      expect(registered.counselorRole, equals('professional_partner'));
      expect(registered.partnerName, equals('RS Mitra Sehati Jakarta'));

      // Subsequent login using newly set password
      const loginDto = PsychologistLoginRequestDto(
        email: 'sarah.lestari@gmail.com',
        password: 'securePassword123',
      );
      final loggedIn = await dataSource.login(loginDto);
      expect(loggedIn.email, equals('sarah.lestari@gmail.com'));
      expect(loggedIn.counselorRole, equals('professional_partner'));
      expect(loggedIn.partnerName, equals('RS Mitra Sehati Jakarta'));
      expect(loggedIn.verificationStatus, equals('verified'));
    });

    test('AuthStateNotifier activatePartnerAccount activates partner state correctly', () async {
      final dataSource = MockAuthDataSource();
      final repository = AuthRepositoryImpl(dataSource: dataSource);
      final notifier = AuthStateNotifier(repository);

      await notifier.activatePartnerAccount(
        email: 'dimas.mitra@klinik.co.id',
        password: 'myNewPassword123',
        partnerName: 'Klinik Jiwa Sejahtera',
        fullName: 'Dimas Pratama, M.Psi.',
      );

      final state = notifier.state.value;
      expect(state, isNotNull);
      expect(state!.role, equals(CounselorRole.professionalPartner));
      expect(state.partnerName, equals('Klinik Jiwa Sejahtera'));
      expect(state.fullName, equals('Dimas Pratama, M.Psi.'));
      expect(state.email, equals('dimas.mitra@klinik.co.id'));
      expect(state.isPartner, isTrue);
      expect(state.isVolunteer, isFalse);
    });

    testWidgets('PartnerCounselorActivationScreen renders prefilled partner info and password form', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PartnerCounselorActivationScreen(
              prefilledEmail: 'sarah.lestari@gmail.com',
              partnerName: 'RS Mitra Sehati Jakarta',
              fullName: 'Dr. Sarah Lestari, M.Psi., Psikolog',
              invitationToken: 'test-token-123',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Aktivasi Akun Mitra'), findsOneWidget);
      expect(find.text('RS Mitra Sehati Jakarta'), findsOneWidget);
      expect(find.text('Dr. Sarah Lestari, M.Psi., Psikolog'), findsOneWidget);
      expect(find.text('sarah.lestari@gmail.com'), findsOneWidget);
      expect(find.text('Kata Sandi Baru'), findsOneWidget);
      expect(find.text('Simpan Kata Sandi & Masuk ke EVA'), findsOneWidget);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:eva_counselor_mobile/features/auth/domain/entities/psychologist_user_entity.dart';
import 'package:eva_counselor_mobile/features/auth/data/datasources/mock_auth_datasource.dart';
import 'package:eva_counselor_mobile/features/auth/data/models/psychologist_auth_dto.dart';

void main() {
  group('Psikolog Mandiri Single-Category Architecture Tests', () {
    test('Independent professional entity attributes and coins system', () {
      const pro = PsychologistUserEntity(
        id: 'pro-001',
        fullName: 'Sarah Anindya',
        titleDegree: 'M.Psi., Psikolog',
        email: 'sarah@psikolog.eva.id',
        strNumber: 'STR-PK-198827364-2026',
        association: 'HIMPSI',
        specializations: ['Kecemasan Dewasa', 'Burnout'],
        yearsOfExperience: 5,
        consultationRatePerHour: 150000,
        verificationStatus: VerificationStatus.verified,
        role: CounselorRole.professionalIndependent,
        sessionDurationMinutes: 50,
        coinsPerSession: 150,
        coinBalance: 1250,
        googleDriveEmail: 'sarah.anindya@gmail.com',
      );

      expect(pro.isVolunteer, false);
      expect(pro.isProfessional, true);
      expect(pro.isIndependent, true);
      expect(pro.isPartner, false);
      expect(pro.canConfigureOffline, true);
      expect(pro.isOfflineManagedByPartner, false);
      expect(pro.roleBadgeLabel, 'Psikolog Mandiri');
      expect(pro.displayName, 'Sarah Anindya, M.Psi., Psikolog');
      expect(pro.coinsPerSession, 150);
      expect(pro.coinBalance, 1250);
    });

    test('Single-category invariant: all users are Psikolog Mandiri', () {
      const counselor = PsychologistUserEntity(
        id: 'counselor-001',
        fullName: 'Budi Santoso',
        titleDegree: 'M.Psi., Psikolog',
        email: 'budi@psikolog.eva.id',
        strNumber: 'STR-PK-10293847-2026',
        association: 'HIMPSI',
        specializations: ['Curhat Klinis', 'Manajemen Stres'],
        yearsOfExperience: 3,
        consultationRatePerHour: 120000,
        verificationStatus: VerificationStatus.verified,
      );

      expect(counselor.isVolunteer, false);
      expect(counselor.isPartner, false);
      expect(counselor.isIndependent, true);
      expect(counselor.isProfessional, true);
      expect(counselor.roleBadgeLabel, 'Psikolog Mandiri');
    });

    test('MockAuthDataSource registers independent psychologist with STR', () async {
      final ds = MockAuthDataSource();
      final response = await ds.register(
        const PsychologistRegisterRequestDto(
          fullName: 'Anisa Rahma',
          titleDegree: 'M.Psi., Psikolog',
          email: 'anisa@psikolog.eva.id',
          password: 'password123',
          strNumber: 'STR-PK-8899001',
          association: 'HIMPSI',
          specializations: ['Kecemasan Remaja'],
          yearsOfExperience: 2,
          consultationRate: 150000,
          certificateDocFileName: 'STR_Anisa.pdf',
          counselorRole: 'professional_independent',
          coinsPerSession: 150,
        ),
      );

      final entity = response.toEntity();
      expect(entity.role, CounselorRole.professionalIndependent);
      expect(entity.isIndependent, true);
      expect(entity.roleBadgeLabel, 'Psikolog Mandiri');
      expect(entity.coinsPerSession, 150);
    });
  });
}

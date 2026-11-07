import 'package:flutter_test/flutter_test.dart';
import 'package:eva_counselor_mobile/features/auth/domain/entities/psychologist_user_entity.dart';
import 'package:eva_counselor_mobile/features/auth/data/datasources/mock_auth_datasource.dart';
import 'package:eva_counselor_mobile/features/auth/data/models/psychologist_auth_dto.dart';

void main() {
  group('Counselor Role & Multi-Category System Tests', () {
    test('Peer volunteer entity attributes and restrictions', () {
      const volunteer = PsychologistUserEntity(
        id: 'vol-001',
        fullName: 'Budi Santoso',
        titleDegree: 'Relawan Sebaya',
        email: 'budi@volunteer.id',
        strNumber: 'VOLUNTEER-PEER',
        association: 'Komunitas Peduli Mahasiswa',
        specializations: ['Curhat Sebaya', 'Manajemen Stres Akademik'],
        yearsOfExperience: 1,
        consultationRatePerHour: 0,
        verificationStatus: VerificationStatus.verified,
        role: CounselorRole.peerVolunteer,
        coinsPerSession: 0,
        coinBalance: 0,
      );

      expect(volunteer.isVolunteer, true);
      expect(volunteer.isProfessional, false);
      expect(volunteer.isPartner, false);
      expect(volunteer.isIndependent, false);
      expect(volunteer.roleBadgeLabel, 'Relawan Teman Sebaya');
      expect(volunteer.displayName, 'Budi Santoso');
    });

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
      expect(pro.roleBadgeLabel, 'Psikolog Profesional (Mandiri)');
      expect(pro.displayName, 'Sarah Anindya, M.Psi., Psikolog');
      expect(pro.coinsPerSession, 150);
      expect(pro.coinBalance, 1250);
    });

    test('Partner professional entity attributes and partner affiliation', () {
      const partnerPro = PsychologistUserEntity(
        id: 'partner-001',
        fullName: 'dr. Dimas Wahyu',
        titleDegree: 'Sp.KJ',
        email: 'dimas@rsmitra.co.id',
        strNumber: 'STR-MED-8891-2026',
        association: 'IDI / PDSKJI',
        specializations: ['Depresi Klinis', 'Trauma Akut'],
        yearsOfExperience: 8,
        consultationRatePerHour: 250000,
        verificationStatus: VerificationStatus.verified,
        role: CounselorRole.professionalPartner,
        partnerName: 'RS Mitra Sehati Jakarta',
      );

      expect(partnerPro.isPartner, true);
      expect(partnerPro.isProfessional, true);
      expect(partnerPro.isVolunteer, false);
      expect(partnerPro.roleBadgeLabel, 'Psikolog Mitra • RS Mitra Sehati Jakarta');
    });

    test('MockAuthDataSource registers volunteer without STR and with verified status', () async {
      final ds = MockAuthDataSource();
      final response = await ds.register(
        const PsychologistRegisterRequestDto(
          fullName: 'Anisa Rahma',
          titleDegree: 'Relawan Sebaya',
          email: 'anisa@volunteer.org',
          password: 'password123',
          strNumber: 'VOLUNTEER-PEER',
          association: 'Komunitas Teman Curhat',
          specializations: ['Curhat Keseharian'],
          yearsOfExperience: 1,
          consultationRate: 0,
          certificateDocFileName: 'none',
          counselorRole: 'peer_volunteer',
          coinsPerSession: 0,
        ),
      );

      final entity = response.toEntity();
      expect(entity.role, CounselorRole.peerVolunteer);
      expect(entity.verificationStatus, VerificationStatus.verified);
      expect(entity.coinsPerSession, 0);
    });

    test('MockAuthDataSource registers partner counselor with partnerName', () async {
      final ds = MockAuthDataSource();
      final response = await ds.register(
        const PsychologistRegisterRequestDto(
          fullName: 'Bambang Kusuma',
          titleDegree: 'M.Psi., Psikolog',
          email: 'bambang@kliniksehati.id',
          password: 'password123',
          strNumber: 'STR-PK-991283',
          association: 'HIMPSI',
          specializations: ['Hubungan & Keluarga'],
          yearsOfExperience: 6,
          consultationRate: 200000,
          certificateDocFileName: 'STR_Bambang.pdf',
          counselorRole: 'professional_partner',
          partnerName: 'Klinik Sehati Mitra',
          coinsPerSession: 200,
        ),
      );

      final entity = response.toEntity();
      expect(entity.role, CounselorRole.professionalPartner);
      expect(entity.partnerName, 'Klinik Sehati Mitra');
    });
  });
}

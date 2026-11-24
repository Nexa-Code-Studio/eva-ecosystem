import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eva_counselor_mobile/core/config/app_config.dart';
import 'package:eva_counselor_mobile/core/network/api_client.dart';
import 'package:eva_counselor_mobile/core/storage/token_storage.dart';
import 'package:eva_counselor_mobile/features/auth/domain/entities/psychologist_user_entity.dart';
import 'package:eva_counselor_mobile/features/profile/data/datasources/counselor_certificate_remote_data_source.dart';
import 'package:eva_counselor_mobile/features/profile/data/repositories/counselor_certificate_repository_impl.dart';
import 'package:eva_counselor_mobile/features/profile/domain/entities/eva_certificate_entity.dart';
import 'package:eva_counselor_mobile/features/profile/presentation/providers/counselor_certificate_provider.dart';
import 'package:eva_counselor_mobile/features/profile/presentation/widgets/counselor_certificates_modal.dart';

class MockApiClient extends ApiClient {
  final dynamic mockGetResponse;
  final List<int>? mockRawBytes;

  MockApiClient({this.mockGetResponse, this.mockRawBytes});

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? queryParams}) async {
    return mockGetResponse;
  }

  @override
  Future<List<int>> getRawBytes(String path, {Map<String, dynamic>? queryParams}) async {
    return mockRawBytes ?? [0x25, 0x50, 0x44, 0x46]; // %PDF
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('EvaCertificateEntity Unit Tests', () {
    test('fromJson and toJson correctly serialize and deserialize certificate data', () {
      final json = {
        'id': 'cert-101',
        'psychologist_id': 'psy-202',
        'certificate_number': 'EVA/CERT/2026/001',
        'title': 'SERTIFIKAT PRAKTIK TELEKONSELING',
        'subtitle': 'Excellence in Counseling',
        'recipient_name': 'dr. Sarah Amelia, M.Psi.',
        'str_number': 'STR-123456789',
        'milestone_criteria': 'Penyelesaian 25 Sesi Klinis',
        'category_label': 'Psikolog Mandiri',
        'description': 'Sertifikat apresiasi layanan klinis.',
        'trigger_source': 'milestone',
        'status': 'active',
        'issued_at': '2026-11-20T10:00:00Z',
        'revoked_at': null,
        'revocation_reason': null,
        'metadata': {'sessions': 25},
      };

      final entity = EvaCertificateEntity.fromJson(json);

      expect(entity.id, equals('cert-101'));
      expect(entity.certificateNumber, equals('EVA/CERT/2026/001'));
      expect(entity.title, equals('SERTIFIKAT PRAKTIK TELEKONSELING'));
      expect(entity.recipientName, equals('dr. Sarah Amelia, M.Psi.'));
      expect(entity.status, equals('active'));
      expect(entity.isActive, isTrue);
      expect(entity.isRevoked, isFalse);
      expect(entity.issueDate, contains('2026'));

      final serialized = entity.toJson();
      expect(serialized['id'], equals('cert-101'));
      expect(serialized['certificate_number'], equals('EVA/CERT/2026/001'));
      expect(serialized['status'], equals('active'));
    });

    test('isActive and isRevoked correctly detect revoked certificates', () {
      final revokedCert = EvaCertificateEntity(
        id: 'cert-revoked',
        title: 'Revoked Certificate',
        subtitle: 'Sub',
        recipientName: 'Sarah',
        milestoneCriteria: 'None',
        certificateNumber: 'REV-001',
        issueDate: '2026-01-01',
        categoryLabel: 'Psikolog Mandiri',
        description: 'Revoked for testing',
        status: 'revoked',
        revokedAt: DateTime.parse('2026-02-01T00:00:00Z'),
        revocationReason: 'Pelanggaran kode etik',
      );

      expect(revokedCert.isActive, isFalse);
      expect(revokedCert.isRevoked, isTrue);
      expect(revokedCert.revocationReason, equals('Pelanggaran kode etik'));
    });
  });

  group('CounselorCertificateRemoteDataSource Tests', () {
    test('fetchCertificates filters out revoked certificates and keeps active ones', () async {
      final mockData = [
        {
          'id': 'cert-active-1',
          'certificate_number': 'EVA/2026/01',
          'title': 'Active Certificate 1',
          'subtitle': 'Sub 1',
          'recipient_name': 'Sarah',
          'milestone_criteria': '25 Sessions',
          'status': 'active',
        },
        {
          'id': 'cert-revoked-2',
          'certificate_number': 'EVA/2026/02',
          'title': 'Revoked Certificate 2',
          'subtitle': 'Sub 2',
          'recipient_name': 'Sarah',
          'milestone_criteria': '50 Sessions',
          'status': 'revoked',
        },
        {
          'id': 'cert-active-3',
          'certificate_number': 'EVA/2026/03',
          'title': 'Active Certificate 3',
          'subtitle': 'Sub 3',
          'recipient_name': 'Sarah',
          'milestone_criteria': '100 Sessions',
          'status': 'active',
        },
      ];

      final dataSource = CounselorCertificateRemoteDataSource(
        apiClient: MockApiClient(mockGetResponse: mockData),
      );

      final certs = await dataSource.fetchCertificates();

      expect(certs.length, equals(2));
      expect(certs[0].id, equals('cert-active-1'));
      expect(certs[1].id, equals('cert-active-3'));
      expect(certs.every((c) => c.status == 'active'), isTrue);
    });

    test('downloadCertificatePdf fetches raw bytes from endpoint', () async {
      final dummyBytes = [0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34];
      final dataSource = CounselorCertificateRemoteDataSource(
        apiClient: MockApiClient(mockRawBytes: dummyBytes),
      );

      final result = await dataSource.downloadCertificatePdf('cert-active-1');
      expect(result, isNotNull);
      expect(result.length, equals(dummyBytes.length));
    });

    test('getCertificateDownloadUrl appends token when available in TokenStorage', () async {
      await TokenStorage.saveToken('jwt-test-token-xyz');
      final dataSource = CounselorCertificateRemoteDataSource();

      final url = await dataSource.getCertificateDownloadUrl('cert-active-1');
      expect(url, contains('/counselor/certificates/cert-active-1/download'));
      expect(url, contains('token=jwt-test-token-xyz'));
    });
  });

  group('CounselorCertificateRepositoryImpl Tests', () {
    test('getCertificates in mock mode returns mock earned certificates', () async {
      AppConfig.useMockData = true;
      final repo = CounselorCertificateRepositoryImpl();

      final certs = await repo.getCertificates();
      expect(certs.length, equals(3));
      expect(certs[0].title, contains('TELEKONSELING'));
      expect(certs.every((c) => c.isActive), isTrue);

      final pdfBytes = await repo.downloadCertificatePdf('CERT-PRO-01');
      expect(pdfBytes, isNotEmpty);
      expect(String.fromCharCodes(pdfBytes), contains('%PDF-1.4'));
    });
  });

  group('CounselorCertificatesModal Static & Widget Tests', () {
    const verifiedUser = PsychologistUserEntity(
      id: 'counselor-123',
      fullName: 'Dr. Sarah Anindya',
      titleDegree: 'M.Psi., Psikolog',
      email: 'sarah@psikolog.eva.id',
      strNumber: 'STR-PK-198827364-2026',
      association: 'HIMPSI',
      specializations: ['Kecemasan Dewasa'],
      yearsOfExperience: 5,
      consultationRatePerHour: 50000,
      verificationStatus: VerificationStatus.verified,
      role: CounselorRole.professionalIndependent,
      isOnline: true,
      coinBalance: 6500, // 6500 ~/ 120 = 54 completed sessions -> qualifies for 25 and 50 sessions
    );

    test('getCertificatesForUser returns milestone certificates for verified user', () {
      final certs = CounselorCertificatesModal.getCertificatesForUser(verifiedUser);
      expect(certs.length, equals(2));
      expect(certs[0].id, equals('CERT-PRO-01'));
      expect(certs[1].id, equals('CERT-PRO-02'));
    });

    test('getCertificatesForUser returns empty list for unverified or null user', () {
      expect(CounselorCertificatesModal.getCertificatesForUser(null), isEmpty);

      final unverifiedUser = verifiedUser.copyWith(verificationStatus: VerificationStatus.pending);
      expect(CounselorCertificatesModal.getCertificatesForUser(unverifiedUser), isEmpty);
    });

    testWidgets('showGallery displays certificates and opens official preview on tap', (tester) async {
      final testCerts = [
        const EvaCertificateEntity(
          id: 'CERT-001',
          title: 'SERTIFIKAT PRAKTIK TELEKONSELING KLINIS',
          subtitle: 'Clinical Tele-Psychology Excellence',
          recipientName: 'dr. Sarah Amelia',
          milestoneCriteria: '25 Sesi Terverifikasi',
          certificateNumber: 'EVA/CERT/2026/001',
          issueDate: '20 Okt 2026',
          categoryLabel: 'Psikolog Mandiri',
          description: 'Apresiasi kompetensi klinis telekonseling.',
          status: 'active',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            counselorCertificatesProvider.overrideWith((ref) => Future.value(testCerts)),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => CounselorCertificatesModal.showGallery(context, verifiedUser, ref: ref),
                      child: const Text('Buka Galeri'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap button to open bottom sheet
      await tester.tap(find.text('Buka Galeri'));
      await tester.pumpAndSettle();

      // Verify bottom sheet contents
      expect(find.text('Sertifikat & Pencapaian'), findsOneWidget);
      expect(find.text('1 Sertifikat resmi diraih berdasarkan milestone'), findsOneWidget);
      expect(find.text('SERTIFIKAT PRAKTIK TELEKONSELING KLINIS'), findsOneWidget);
      expect(find.text('Buka & Unduh'), findsOneWidget);

      // Tap "Buka & Unduh" to open official certificate dialog
      await tester.tap(find.text('Buka & Unduh'));
      await tester.pumpAndSettle();

      expect(find.text('Pratinjau Sertifikat Resmi'), findsOneWidget);
      expect(find.text('EVA MENTAL HEALTH ECOSYSTEM'), findsOneWidget);
      expect(find.text('Unduh Sertifikat (PDF)'), findsOneWidget);

      // Tap "Tutup"
      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();

      expect(find.text('Pratinjau Sertifikat Resmi'), findsNothing);
    });

    testWidgets('showGallery displays empty state when no certificates available', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            counselorCertificatesProvider.overrideWith((ref) => Future.value([])),
          ],
          child: MaterialApp(
            home: Consumer(
              builder: (context, ref, _) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => CounselorCertificatesModal.showGallery(context, verifiedUser, ref: ref),
                      child: const Text('Buka Galeri Kosong'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap button to open bottom sheet
      await tester.tap(find.text('Buka Galeri Kosong'));
      await tester.pumpAndSettle();

      expect(find.text('Belum Ada Sertifikat Penghargaan'), findsOneWidget);
      expect(find.text('0 Sertifikat resmi diraih berdasarkan milestone'), findsOneWidget);
    });
  });
}

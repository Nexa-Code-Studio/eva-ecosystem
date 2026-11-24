import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/config/app_config.dart';
import '../../domain/entities/eva_certificate_entity.dart';
import '../../domain/repositories/counselor_certificate_repository.dart';
import '../datasources/counselor_certificate_remote_data_source.dart';

class CounselorCertificateRepositoryImpl implements ICounselorCertificateRepository {
  final ICounselorCertificateDataSource _remoteDataSource;

  CounselorCertificateRepositoryImpl({
    ICounselorCertificateDataSource? remoteDataSource,
  }) : _remoteDataSource = remoteDataSource ?? CounselorCertificateRemoteDataSource();

  @override
  Future<List<EvaCertificateEntity>> getCertificates() async {
    if (AppConfig.useMockData) {
      return _getMockCertificates();
    }

    try {
      final certs = await _remoteDataSource.fetchCertificates();
      return certs;
    } catch (_) {
      // In case of network errors during local offline inspection, provide fallback
      return _getMockCertificates();
    }
  }

  @override
  Future<Uint8List> downloadCertificatePdf(String certificateId) async {
    if (AppConfig.useMockData) {
      // Return a minimal valid dummy PDF stream in mock mode
      return Uint8List.fromList('%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj 2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj 3 0 obj<</Type/Page/MediaBox[0 0 595 842]/Parent 2 0 R>>endobj\nxref\n0 4\n0000000000 65535 f \n0000000009 00000 n \n0000000052 00000 n \n0000000102 00000 n \ntrailer<</Size 4/Root 1 0 R>>\nstartxref\n178\n%%EOF'.codeUnits);
    }
    return await _remoteDataSource.downloadCertificatePdf(certificateId);
  }

  @override
  Future<String> getCertificateDownloadUrl(String certificateId) async {
    return await _remoteDataSource.getCertificateDownloadUrl(certificateId);
  }

  List<EvaCertificateEntity> _getMockCertificates() {
    return [
      const EvaCertificateEntity(
        id: 'CERT-PRO-01',
        title: 'SERTIFIKAT PRAKTIK TELEKONSELING KLINIS',
        subtitle: 'Clinical Tele-Psychology Excellence & Competence',
        recipientName: 'dr. Sarah Amelia, M.Psi., Psikolog',
        milestoneCriteria: 'Penyelesaian 25 Sesi Klinis Terverifikasi',
        certificateNumber: 'EVA/CERT/2026/PRO/00341',
        issueDate: '20 Oktober 2026',
        categoryLabel: 'Psikolog Mandiri',
        description:
            'Diberikan atas dedikasi dan kompetensi klinis prima dalam menyelenggarakan telekonsultasi kesehatan mental dengan standar etika tertinggi.',
        badgeColor: Color(0xFF2563EB),
        status: 'active',
      ),
      const EvaCertificateEntity(
        id: 'CERT-PRO-02',
        title: 'SERTIFIKAT KEPATUHAN REKAM MEDIS SOAP',
        subtitle: 'Certified Clinical Medical Record Standard',
        recipientName: 'dr. Sarah Amelia, M.Psi., Psikolog',
        milestoneCriteria: 'Kepatuhan Rekam SOAP 100% pada 50 Sesi',
        certificateNumber: 'EVA/CERT/2026/PRO/00512',
        issueDate: '02 November 2026',
        categoryLabel: 'Psikolog Mandiri',
        description:
            'Diberikan atas komitmen integritas dokumentasi rekam medis klinis yang terenkripsi aman demi keselamatan pasien.',
        badgeColor: Color(0xFFD97706),
        status: 'active',
      ),
      const EvaCertificateEntity(
        id: 'CERT-PRO-03',
        title: 'SERTIFIKAT KONSELOR TELADAN EVA 2026',
        subtitle: 'Distinguished Clinical Practitioner 2026',
        recipientName: 'dr. Sarah Amelia, M.Psi., Psikolog',
        milestoneCriteria: '100+ Sesi Terlaksana dengan Rating Kepuasan 4.9+',
        certificateNumber: 'EVA/CERT/2026/PRO/00789',
        issueDate: '06 November 2026',
        categoryLabel: 'Psikolog Mandiri',
        description:
            'Penghargaan tertinggi platform Eva atas loyalitas pelayanan intervensi krisis, kepuasan pasien bintang lima, dan kontribusi nyata pada kesehatan jiwa bangsa.',
        badgeColor: Color(0xFF7E22CE),
        status: 'active',
      ),
    ];
  }
}

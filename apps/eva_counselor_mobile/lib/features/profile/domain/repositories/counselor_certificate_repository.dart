import 'dart:typed_data';
import '../entities/eva_certificate_entity.dart';

abstract class ICounselorCertificateRepository {
  /// Fetches official certificates awarded to the psychologist (active only).
  Future<List<EvaCertificateEntity>> getCertificates();

  /// Downloads the raw binary PDF stream of an official watermarked certificate.
  Future<Uint8List> downloadCertificatePdf(String certificateId);

  /// Resolves the authenticated direct download URL (with JWT token query param).
  Future<String> getCertificateDownloadUrl(String certificateId);
}

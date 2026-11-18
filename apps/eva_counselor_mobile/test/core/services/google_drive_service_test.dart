import 'package:flutter_test/flutter_test.dart';
import 'package:eva_counselor_mobile/core/services/google_drive_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GoogleDriveService Tests', () {
    test('MockGoogleDriveService authenticates and uploads encrypted backup', () async {
      final service = MockGoogleDriveService();
      final authOk = await service.authenticate(email: 'sarah.anindya@psikolog.eva.id');
      expect(authOk, true);

      final result = await service.uploadEncryptedBackup(
        email: 'sarah.anindya@psikolog.eva.id',
        data: {'sessions': 5, 'records': ['SOAP-1', 'SOAP-2']},
      );

      expect(result.isSuccess, true);
      expect(result.fileId.startsWith('mock-gdrive-file-'), true);
      expect(result.email, 'sarah.anindya@psikolog.eva.id');
      expect(result.formattedSizeMb.contains('MB'), true);
    });

    test('RemoteGoogleDriveService authenticates and creates encrypted payload with dynamic email', () async {
      final service = RemoteGoogleDriveService();
      final authOk = await service.authenticate(email: 'counselor.dynamic@gmail.com');
      expect(authOk, true);

      final result = await service.uploadEncryptedBackup(
        email: 'counselor.dynamic@gmail.com',
        data: {'patient_id': 'pt-101', 'soap': 'Subjective notes'},
      );

      expect(result.isSuccess, true);
      expect(result.email, 'counselor.dynamic@gmail.com');
      expect(result.fileName.contains('counselor.dynamic'), true);
      expect(result.bytesUploaded, greaterThan(0));

      final restored = await service.restoreEncryptedBackup(email: 'counselor.dynamic@gmail.com');
      expect(restored?['email'], 'counselor.dynamic@gmail.com');
    });

    test('RemoteGoogleDriveService throws on empty email', () async {
      final service = RemoteGoogleDriveService();
      expect(() => service.authenticate(email: ''), throwsA(isA<Exception>()));
      expect(
        () => service.uploadEncryptedBackup(email: '', data: {}),
        throwsA(isA<Exception>()),
      );
    });
  });
}

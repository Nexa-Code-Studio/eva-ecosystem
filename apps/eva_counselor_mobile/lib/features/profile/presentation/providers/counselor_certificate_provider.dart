import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/counselor_certificate_remote_data_source.dart';
import '../../data/repositories/counselor_certificate_repository_impl.dart';
import '../../domain/entities/eva_certificate_entity.dart';
import '../../domain/repositories/counselor_certificate_repository.dart';

final counselorCertificateDataSourceProvider =
    Provider<ICounselorCertificateDataSource>((ref) {
  return CounselorCertificateRemoteDataSource();
});

final counselorCertificateRepositoryProvider =
    Provider<ICounselorCertificateRepository>((ref) {
  final dataSource = ref.watch(counselorCertificateDataSourceProvider);
  return CounselorCertificateRepositoryImpl(remoteDataSource: dataSource);
});

final counselorCertificatesProvider =
    FutureProvider.autoDispose<List<EvaCertificateEntity>>((ref) async {
  final repository = ref.watch(counselorCertificateRepositoryProvider);
  return await repository.getCertificates();
});

class CertificateDownloadNotifier extends StateNotifier<AsyncValue<Uint8List?>> {
  final ICounselorCertificateRepository _repository;

  CertificateDownloadNotifier(this._repository) : super(const AsyncValue.data(null));

  Future<Uint8List?> downloadCertificate(String certificateId) async {
    state = const AsyncValue.loading();
    try {
      final bytes = await _repository.downloadCertificatePdf(certificateId);
      state = AsyncValue.data(bytes);
      return bytes;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<String> getDownloadUrl(String certificateId) async {
    return await _repository.getCertificateDownloadUrl(certificateId);
  }
}

final certificateDownloadProvider = StateNotifierProvider<
    CertificateDownloadNotifier, AsyncValue<Uint8List?>>((ref) {
  final repository = ref.watch(counselorCertificateRepositoryProvider);
  return CertificateDownloadNotifier(repository);
});

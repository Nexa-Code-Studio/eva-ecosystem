enum VerificationStatus { pending, verified, needRevision, rejected }

class PsychologistUserEntity {
  final String id;
  final String fullName;
  final String titleDegree; // e.g., 'S.Psi., M.Psi., Psikolog'
  final String email;
  final String strNumber; // Surat Tanda Registrasi
  final String association; // e.g. 'HIMPSI'
  final List<String> specializations;
  final int yearsOfExperience;
  final int consultationRatePerHour;
  final VerificationStatus verificationStatus;
  final bool isOnline;
  final String? profilePhotoUrl;
  final String? certificateDocUrl;

  const PsychologistUserEntity({
    required this.id,
    required this.fullName,
    required this.titleDegree,
    required this.email,
    required this.strNumber,
    required this.association,
    required this.specializations,
    required this.yearsOfExperience,
    required this.consultationRatePerHour,
    required this.verificationStatus,
    this.isOnline = true,
    this.profilePhotoUrl,
    this.certificateDocUrl,
  });

  String get displayName => '$fullName, $titleDegree';
}

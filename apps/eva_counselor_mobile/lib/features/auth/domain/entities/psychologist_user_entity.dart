enum VerificationStatus { pending, verified, needRevision, rejected }

enum CounselorRole {
  professionalPartner, // Relawan Profesional dengan Mitra (Jadwal & koin diatur mitra di web, koin ke mitra)
  professionalIndependent, // Relawan Profesional Non-Mitra (Mandiri: atur sesi, menit, tarif koin, redeem koin ke Rp)
  peerVolunteer, // Relawan Non-Profesional / Teman Sebaya (Curhat non-kritis, tanpa STR, tanpa SOAP, tanpa koin)
}

class PsychologistUserEntity {
  final String id;
  final String fullName;
  final String titleDegree; // e.g., 'S.Psi., M.Psi., Psikolog' or 'Relawan Sebaya'
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

  // New role and session/coin system fields
  final CounselorRole role;
  final String? partnerName; // e.g. 'RS Mitra Sehati' (khusus mitra)
  final int sessionDurationMinutes; // durasi 1 sesi dalam menit (misal 50)
  final int coinsPerSession; // tarif koin per sesi (misal 150 koin)
  final int coinBalance; // saldo koin akun
  final String googleDriveEmail; // email drive untuk backup lokal E2EE
  final DateTime? lastDriveBackup;
  final String autoBackupFrequency; // 'Harian', 'Mingguan', 'Manual'

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
    this.role = CounselorRole.professionalIndependent,
    this.partnerName,
    this.sessionDurationMinutes = 50,
    this.coinsPerSession = 150,
    this.coinBalance = 1250,
    this.googleDriveEmail = 'sarah.anindya@gmail.com',
    this.lastDriveBackup,
    this.autoBackupFrequency = 'Harian',
  });

  bool get isVolunteer => role == CounselorRole.peerVolunteer;
  bool get isPartner => role == CounselorRole.professionalPartner;
  bool get isIndependent => role == CounselorRole.professionalIndependent;
  bool get isProfessional => role != CounselorRole.peerVolunteer;

  String get displayName =>
      isVolunteer ? fullName : '$fullName, $titleDegree';

  String get roleBadgeLabel {
    switch (role) {
      case CounselorRole.peerVolunteer:
        return 'Relawan Teman Sebaya';
      case CounselorRole.professionalIndependent:
        return 'Psikolog Profesional (Mandiri)';
      case CounselorRole.professionalPartner:
        return 'Psikolog Mitra • ${partnerName ?? "Klinik Sehati"}';
    }
  }

  PsychologistUserEntity copyWith({
    String? id,
    String? fullName,
    String? titleDegree,
    String? email,
    String? strNumber,
    String? association,
    List<String>? specializations,
    int? yearsOfExperience,
    int? consultationRatePerHour,
    VerificationStatus? verificationStatus,
    bool? isOnline,
    String? profilePhotoUrl,
    String? certificateDocUrl,
    CounselorRole? role,
    String? partnerName,
    int? sessionDurationMinutes,
    int? coinsPerSession,
    int? coinBalance,
    String? googleDriveEmail,
    DateTime? lastDriveBackup,
    String? autoBackupFrequency,
  }) {
    return PsychologistUserEntity(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      titleDegree: titleDegree ?? this.titleDegree,
      email: email ?? this.email,
      strNumber: strNumber ?? this.strNumber,
      association: association ?? this.association,
      specializations: specializations ?? this.specializations,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
      consultationRatePerHour:
          consultationRatePerHour ?? this.consultationRatePerHour,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      isOnline: isOnline ?? this.isOnline,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      certificateDocUrl: certificateDocUrl ?? this.certificateDocUrl,
      role: role ?? this.role,
      partnerName: partnerName ?? this.partnerName,
      sessionDurationMinutes:
          sessionDurationMinutes ?? this.sessionDurationMinutes,
      coinsPerSession: coinsPerSession ?? this.coinsPerSession,
      coinBalance: coinBalance ?? this.coinBalance,
      googleDriveEmail: googleDriveEmail ?? this.googleDriveEmail,
      lastDriveBackup: lastDriveBackup ?? this.lastDriveBackup,
      autoBackupFrequency: autoBackupFrequency ?? this.autoBackupFrequency,
    );
  }
}

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
  final String? sipNumber; // Surat Izin Praktik / SIPP
  final String documentType; // 'str', 'sip', 'both'
  final String issuingInstitution; // Fallback umum
  final String documentExpiryDate; // Fallback umum
  final String lastEducation; // e.g. 'S2 Magister Psikologi Profesi'

  // Granular STR / SIP metadata
  final String? strIssuingInstitution;
  final String? strExpiryDate;
  final String? strDocUrl;
  final String? sipIssuingInstitution;
  final String? sipExpiryDate;
  final String? sipDocUrl;

  // Scheduled Break Window (Replacing ad-hoc toggle)
  final String breakStartTime;
  final String breakEndTime;
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
  final String? googleDriveEmail; // email drive untuk backup lokal E2EE
  final DateTime? lastDriveBackup;
  final String autoBackupFrequency; // 'Harian', 'Mingguan', 'Manual'

  // Schedule & Offline Practice fields
  final String employeeNip; // NIP Pegawai Konselor (Identifier unik integrasi eksternal)
  final bool isOnlinePracticeEnabled; // Melayani telekonseling daring
  final bool isOfflinePracticeEnabled; // Melayani praktik tatap muka / offline (opsional)
  final String? offlinePlaceName; // Nama Tempat / Klinik Praktik Offline
  final String? offlineAddress; // Alamat Lengkap Praktik Offline
  final String? offlineCity; // Kota / Wilayah Praktik Offline
  final String? offlineNotes; // Petunjuk Ruang / Catatan Kedatangan
  final List<String> offlineScheduleDays; // Hari praktik offline aktif (e.g. ['Sel', 'Kam', 'Sab'])
  final String offlineStartTime; // Jam mulai offline (e.g. '10:00')
  final String offlineEndTime; // Jam selesai offline (e.g. '16:00')
  final bool isScheduleConfigured; // Status apakah jadwal praktik utama sudah ditentukan

  // External Offline Schedule Sync (GitHub-style Personal Access Token / API Key)
  final String? externalApiKey; // API Key / PAT untuk integrasi kalender/SIMRS eksternal
  final DateTime? externalApiKeyCreatedAt;
  final DateTime? externalApiLastSyncAt;
  final int externalSyncCount; // Jumlah slot jadwal eksternal yang diimpor

  // Bank details for payout
  final String bankName;
  final String bankAccountNumber;
  final String bankAccountHolder;

  const PsychologistUserEntity({
    required this.id,
    required this.fullName,
    required this.titleDegree,
    required this.email,
    required this.strNumber,
    this.sipNumber,
    this.documentType = 'str',
    this.issuingInstitution = 'Kemenkes RI',
    this.documentExpiryDate = 'Seumur Hidup',
    this.lastEducation = 'S2 Magister Psikologi Profesi',
    this.strIssuingInstitution,
    this.strExpiryDate,
    this.strDocUrl,
    this.sipIssuingInstitution,
    this.sipExpiryDate,
    this.sipDocUrl,
    this.breakStartTime = '12:00',
    this.breakEndTime = '13:00',
    required this.association,
    required this.specializations,
    required this.yearsOfExperience,
    required this.consultationRatePerHour,
    required this.verificationStatus,
    this.isOnline = false,
    this.profilePhotoUrl,
    this.certificateDocUrl,
    this.role = CounselorRole.professionalIndependent,
    this.partnerName,
    this.sessionDurationMinutes = 30,
    this.coinsPerSession = 150,
    this.coinBalance = 0,
    this.googleDriveEmail,
    this.lastDriveBackup,
    this.autoBackupFrequency = 'Harian',
    this.employeeNip = '',
    this.isOnlinePracticeEnabled = true,
    this.isOfflinePracticeEnabled = false,
    this.offlinePlaceName,
    this.offlineAddress,
    this.offlineCity,
    this.offlineNotes,
    this.offlineScheduleDays = const ['Sel', 'Kam', 'Sab'],
    this.offlineStartTime = '10:00',
    this.offlineEndTime = '16:00',
    this.externalApiKey,
    this.externalApiKeyCreatedAt,
    this.externalApiLastSyncAt,
    this.externalSyncCount = 0,
    this.bankName = '',
    this.bankAccountNumber = '',
    this.bankAccountHolder = '',
    this.isScheduleConfigured = false,
  });

  String get effectiveGoogleDriveEmail =>
      (googleDriveEmail != null && googleDriveEmail!.isNotEmpty)
          ? googleDriveEmail!
          : email;

  bool get isVolunteer => false;
  bool get isPartner => false;
  bool get isIndependent => true;
  bool get isProfessional => true;

  bool get canConfigureOffline => true;
  bool get isOfflineManagedByPartner => false;

  String get displayName => '$fullName, $titleDegree';

  String get roleBadgeLabel => 'Psikolog Mandiri';

  PsychologistUserEntity copyWith({
    String? id,
    String? fullName,
    String? titleDegree,
    String? email,
    String? strNumber,
    String? sipNumber,
    String? documentType,
    String? issuingInstitution,
    String? documentExpiryDate,
    String? lastEducation,
    String? strIssuingInstitution,
    String? strExpiryDate,
    String? strDocUrl,
    String? sipIssuingInstitution,
    String? sipExpiryDate,
    String? sipDocUrl,
    String? breakStartTime,
    String? breakEndTime,
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
    String? employeeNip,
    bool? isOnlinePracticeEnabled,
    bool? isOfflinePracticeEnabled,
    String? offlinePlaceName,
    String? offlineAddress,
    String? offlineCity,
    String? offlineNotes,
    List<String>? offlineScheduleDays,
    String? offlineStartTime,
    String? offlineEndTime,
    String? externalApiKey,
    DateTime? externalApiKeyCreatedAt,
    DateTime? externalApiLastSyncAt,
    int? externalSyncCount,
    bool clearExternalApiKey = false,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountHolder,
    bool? isScheduleConfigured,
  }) {
    return PsychologistUserEntity(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      titleDegree: titleDegree ?? this.titleDegree,
      email: email ?? this.email,
      strNumber: strNumber ?? this.strNumber,
      sipNumber: sipNumber ?? this.sipNumber,
      documentType: documentType ?? this.documentType,
      issuingInstitution: issuingInstitution ?? this.issuingInstitution,
      documentExpiryDate: documentExpiryDate ?? this.documentExpiryDate,
      lastEducation: lastEducation ?? this.lastEducation,
      strIssuingInstitution: strIssuingInstitution ?? this.strIssuingInstitution,
      strExpiryDate: strExpiryDate ?? this.strExpiryDate,
      strDocUrl: strDocUrl ?? this.strDocUrl,
      sipIssuingInstitution: sipIssuingInstitution ?? this.sipIssuingInstitution,
      sipExpiryDate: sipExpiryDate ?? this.sipExpiryDate,
      sipDocUrl: sipDocUrl ?? this.sipDocUrl,
      breakStartTime: breakStartTime ?? this.breakStartTime,
      breakEndTime: breakEndTime ?? this.breakEndTime,
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
      employeeNip: employeeNip ?? this.employeeNip,
      isOnlinePracticeEnabled:
          isOnlinePracticeEnabled ?? this.isOnlinePracticeEnabled,
      isOfflinePracticeEnabled:
          isOfflinePracticeEnabled ?? this.isOfflinePracticeEnabled,
      offlinePlaceName: offlinePlaceName ?? this.offlinePlaceName,
      offlineAddress: offlineAddress ?? this.offlineAddress,
      offlineCity: offlineCity ?? this.offlineCity,
      offlineNotes: offlineNotes ?? this.offlineNotes,
      offlineScheduleDays: offlineScheduleDays ?? this.offlineScheduleDays,
      offlineStartTime: offlineStartTime ?? this.offlineStartTime,
      offlineEndTime: offlineEndTime ?? this.offlineEndTime,
      externalApiKey:
          clearExternalApiKey ? null : (externalApiKey ?? this.externalApiKey),
      externalApiKeyCreatedAt: clearExternalApiKey
          ? null
          : (externalApiKeyCreatedAt ?? this.externalApiKeyCreatedAt),
      externalApiLastSyncAt:
          externalApiLastSyncAt ?? this.externalApiLastSyncAt,
      externalSyncCount: externalSyncCount ?? this.externalSyncCount,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankAccountHolder: bankAccountHolder ?? this.bankAccountHolder,
      isScheduleConfigured: isScheduleConfigured ?? this.isScheduleConfigured,
    );
  }
}

import '../../domain/entities/psychologist_user_entity.dart';

/// Request schema for psychologist login.
class PsychologistLoginRequestDto {
  final String email;
  final String password;

  const PsychologistLoginRequestDto({
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
      };
}

/// Request schema for psychologist registration with certification details.
class PsychologistRegisterRequestDto {
  final String fullName;
  final String titleDegree;
  final String email;
  final String password;
  final String strNumber;
  final String? sipNumber;
  final String documentType; // 'str', 'sip', 'both'
  final String issuingInstitution;
  final String documentExpiryDate;
  final String lastEducation;
  final String? strIssuingInstitution;
  final String? strExpiryDate;
  final String? strDocUrl;
  final String? sipIssuingInstitution;
  final String? sipExpiryDate;
  final String? sipDocUrl;
  final String association;
  final List<String> specializations;
  final int yearsOfExperience;
  final int consultationRate;
  final String certificateDocFileName;
  final String counselorRole; // 'professional_partner', 'professional_independent', 'peer_volunteer'
  final String? partnerName;
  final int sessionDurationMinutes;
  final int coinsPerSession;

  String? get strDocFileName => strDocUrl;
  String? get sipDocFileName => sipDocUrl;

  const PsychologistRegisterRequestDto({
    required this.fullName,
    required this.titleDegree,
    required this.email,
    required this.password,
    this.strNumber = '',
    this.sipNumber,
    this.documentType = 'str',
    this.issuingInstitution = 'Kemenkes RI',
    this.documentExpiryDate = 'Seumur Hidup',
    this.lastEducation = 'S2 Magister Psikologi Profesi',
    this.strIssuingInstitution,
    this.strExpiryDate,
    String? strDocFileName,
    String? strDocUrl,
    this.sipIssuingInstitution,
    this.sipExpiryDate,
    String? sipDocFileName,
    String? sipDocUrl,
    required this.association,
    required this.specializations,
    required this.yearsOfExperience,
    required this.consultationRate,
    required this.certificateDocFileName,
    this.counselorRole = 'professional_independent',
    this.partnerName,
    this.sessionDurationMinutes = 30,
    this.coinsPerSession = 150,
  })  : strDocUrl = strDocUrl ?? strDocFileName,
        sipDocUrl = sipDocUrl ?? sipDocFileName;

  Map<String, dynamic> toJson() => {
        'full_name': fullName,
        'title_degree': titleDegree,
        'email': email,
        'password': password,
        'str_number': strNumber,
        if (sipNumber != null) 'sip_number': sipNumber,
        'document_type': documentType,
        'issuing_institution': issuingInstitution,
        'document_expiry_date': documentExpiryDate,
        'last_education': lastEducation,
        if (strIssuingInstitution != null) 'str_issuing_institution': strIssuingInstitution,
        if (strExpiryDate != null) 'str_expiry_date': strExpiryDate,
        if (strDocUrl != null) 'str_doc_url': strDocUrl,
        if (sipIssuingInstitution != null) 'sip_issuing_institution': sipIssuingInstitution,
        if (sipExpiryDate != null) 'sip_expiry_date': sipExpiryDate,
        if (sipDocUrl != null) 'sip_doc_url': sipDocUrl,
        'association': association,
        'specializations': specializations,
        'years_of_experience': yearsOfExperience,
        'consultation_rate_per_hour': consultationRate,
        'certificate_doc_file_name': certificateDocFileName,
        'counselor_role': counselorRole,
        if (partnerName != null) 'partner_name': partnerName,
        'session_duration_minutes': sessionDurationMinutes,
        'coins_per_session': coinsPerSession,
      };
}

/// Response schema for psychologist auth and profile endpoints.
class PsychologistProfileResponseDto {
  final String id;
  final String fullName;
  final String titleDegree;
  final String email;
  final String strNumber;
  final String? sipNumber;
  final String documentType;
  final String issuingInstitution;
  final String documentExpiryDate;
  final String lastEducation;
  final String? strIssuingInstitution;
  final String? strExpiryDate;
  final String? strDocUrl;
  final String? sipIssuingInstitution;
  final String? sipExpiryDate;
  final String? sipDocUrl;
  final String association;
  final List<String> specializations;
  final int yearsOfExperience;
  final int consultationRatePerHour;
  final String verificationStatus;
  final bool isOnline;
  final String? profilePhotoUrl;
  final String? certificateDocUrl;
  final String? token;
  final String counselorRole;
  final String? partnerName;
  final int sessionDurationMinutes;
  final int coinsPerSession;
  final int coinBalance;
  final String? googleDriveEmail;
  final String employeeNip;
  final bool isOnlinePracticeEnabled;
  final bool isOfflinePracticeEnabled;
  final String? offlinePlaceName;
  final String? offlineAddress;
  final String? offlineCity;
  final String? offlineNotes;
  final List<String> offlineScheduleDays;
  final String offlineStartTime;
  final String offlineEndTime;
  final String? externalApiKey;
  final DateTime? externalApiKeyCreatedAt;
  final DateTime? externalApiLastSyncAt;
  final int externalSyncCount;
  final String bankName;
  final String bankAccountNumber;
  final String bankAccountHolder;

  String? get strDocFileName => strDocUrl;
  String? get sipDocFileName => sipDocUrl;

  const PsychologistProfileResponseDto({
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
    String? strDocFileName,
    String? strDocUrl,
    this.sipIssuingInstitution,
    this.sipExpiryDate,
    String? sipDocFileName,
    String? sipDocUrl,
    required this.association,
    required this.specializations,
    required this.yearsOfExperience,
    required this.consultationRatePerHour,
    required this.verificationStatus,
    required this.isOnline,
    this.profilePhotoUrl,
    this.certificateDocUrl,
    this.token,
    this.counselorRole = 'professional_independent',
    this.partnerName,
    this.sessionDurationMinutes = 30,
    this.coinsPerSession = 150,
    this.coinBalance = 0,
    this.googleDriveEmail,
    this.employeeNip = '',
    this.isOnlinePracticeEnabled = false,
    this.isOfflinePracticeEnabled = false,
    this.offlinePlaceName,
    this.offlineAddress,
    this.offlineCity,
    this.offlineNotes,
    this.offlineScheduleDays = const [],
    this.offlineStartTime = '10:00',
    this.offlineEndTime = '16:00',
    this.externalApiKey,
    this.externalApiKeyCreatedAt,
    this.externalApiLastSyncAt,
    this.externalSyncCount = 0,
    this.bankName = '',
    this.bankAccountNumber = '',
    this.bankAccountHolder = '',
  })  : strDocUrl = strDocUrl ?? strDocFileName,
        sipDocUrl = sipDocUrl ?? sipDocFileName;

  factory PsychologistProfileResponseDto.fromJson(Map<String, dynamic> json) {
    return PsychologistProfileResponseDto(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      titleDegree: json['title_degree']?.toString() ?? 'M.Psi., Psikolog',
      email: json['email']?.toString() ?? '',
      strNumber: json['str_number']?.toString() ?? '',
      sipNumber: json['sip_number']?.toString(),
      documentType: json['document_type']?.toString() ?? 'str',
      issuingInstitution: json['issuing_institution']?.toString() ?? 'Kemenkes RI',
      documentExpiryDate: json['document_expiry_date']?.toString() ?? 'Seumur Hidup',
      lastEducation: json['last_education']?.toString() ?? 'S2 Magister Psikologi Profesi',
      strIssuingInstitution: json['str_issuing_institution']?.toString(),
      strExpiryDate: json['str_expiry_date']?.toString(),
      strDocUrl: json['str_doc_url']?.toString(),
      sipIssuingInstitution: json['sip_issuing_institution']?.toString(),
      sipExpiryDate: json['sip_expiry_date']?.toString(),
      sipDocUrl: json['sip_doc_url']?.toString(),
      association: json['association']?.toString() ?? 'HIMPSI',
      specializations: (json['specializations'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      yearsOfExperience: json['years_of_experience'] as int? ?? 1,
      consultationRatePerHour:
          json['consultation_rate_per_hour'] as int? ?? 150000,
      verificationStatus:
          json['verification_status']?.toString() ?? 'pending',
      isOnline: json['is_online'] as bool? ?? false,
      profilePhotoUrl: json['profile_photo_url']?.toString(),
      certificateDocUrl: json['certificate_doc_url']?.toString(),
      token: json['token']?.toString(),
      counselorRole: json['counselor_role']?.toString() ?? 'professional_independent',
      partnerName: json['partner_name']?.toString(),
      sessionDurationMinutes: json['session_duration_minutes'] as int? ?? 30,
      coinsPerSession: json['coins_per_session'] as int? ?? 150,
      coinBalance: (json['coin_balance'] as num?)?.toInt() ??
          (json['wallet_balance'] != null
              ? ((json['wallet_balance'] as num) / 1000).toInt()
              : 0),
      googleDriveEmail: json['google_drive_email']?.toString(),
      employeeNip: json['employee_nip']?.toString() ?? '',
      isOnlinePracticeEnabled: json['is_online_practice_enabled'] as bool? ?? false,
      isOfflinePracticeEnabled: json['is_offline_practice_enabled'] as bool? ?? false,
      offlinePlaceName: json['offline_place_name']?.toString(),
      offlineAddress: json['offline_address']?.toString(),
      offlineCity: json['offline_city']?.toString(),
      offlineNotes: json['offline_notes']?.toString(),
      offlineScheduleDays: (json['offline_schedule_days'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      offlineStartTime: json['offline_start_time']?.toString() ?? '10:00',
      offlineEndTime: json['offline_end_time']?.toString() ?? '16:00',
      externalApiKey: json['external_api_key']?.toString(),
      externalApiKeyCreatedAt: json['external_api_key_created_at'] != null
          ? DateTime.tryParse(json['external_api_key_created_at'].toString())
          : null,
      externalApiLastSyncAt: json['external_api_last_sync_at'] != null
          ? DateTime.tryParse(json['external_api_last_sync_at'].toString())
          : null,
      externalSyncCount: json['external_sync_count'] as int? ?? 0,
      bankName: json['bank_name']?.toString() ?? '',
      bankAccountNumber: json['bank_account_number']?.toString() ?? '',
      bankAccountHolder: json['bank_account_holder']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'title_degree': titleDegree,
        'email': email,
        'str_number': strNumber,
        if (sipNumber != null) 'sip_number': sipNumber,
        'document_type': documentType,
        'issuing_institution': issuingInstitution,
        'document_expiry_date': documentExpiryDate,
        'last_education': lastEducation,
        if (strIssuingInstitution != null) 'str_issuing_institution': strIssuingInstitution,
        if (strExpiryDate != null) 'str_expiry_date': strExpiryDate,
        if (strDocUrl != null) 'str_doc_url': strDocUrl,
        if (sipIssuingInstitution != null) 'sip_issuing_institution': sipIssuingInstitution,
        if (sipExpiryDate != null) 'sip_expiry_date': sipExpiryDate,
        if (sipDocUrl != null) 'sip_doc_url': sipDocUrl,
        'association': association,
        'specializations': specializations,
        'years_of_experience': yearsOfExperience,
        'consultation_rate_per_hour': consultationRatePerHour,
        'verification_status': verificationStatus,
        'is_online': isOnline,
        'profile_photo_url': profilePhotoUrl,
        'certificate_doc_url': certificateDocUrl,
        if (token != null) 'token': token,
        'counselor_role': counselorRole,
        if (partnerName != null) 'partner_name': partnerName,
        'session_duration_minutes': sessionDurationMinutes,
        'coins_per_session': coinsPerSession,
        'coin_balance': coinBalance,
        if (googleDriveEmail != null) 'google_drive_email': googleDriveEmail,
        'employee_nip': employeeNip,
        'is_online_practice_enabled': isOnlinePracticeEnabled,
        'is_offline_practice_enabled': isOfflinePracticeEnabled,
        if (offlinePlaceName != null) 'offline_place_name': offlinePlaceName,
        if (offlineAddress != null) 'offline_address': offlineAddress,
        if (offlineCity != null) 'offline_city': offlineCity,
        if (offlineNotes != null) 'offline_notes': offlineNotes,
        'offline_schedule_days': offlineScheduleDays,
        'offline_start_time': offlineStartTime,
        'offline_end_time': offlineEndTime,
        if (externalApiKey != null) 'external_api_key': externalApiKey,
        if (externalApiKeyCreatedAt != null)
          'external_api_key_created_at': externalApiKeyCreatedAt!.toIso8601String(),
        if (externalApiLastSyncAt != null)
          'external_api_last_sync_at': externalApiLastSyncAt!.toIso8601String(),
        'external_sync_count': externalSyncCount,
        'bank_name': bankName,
        'bank_account_number': bankAccountNumber,
        'bank_account_holder': bankAccountHolder,
      };

  PsychologistProfileResponseDto copyWith({
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
    String? association,
    List<String>? specializations,
    int? yearsOfExperience,
    int? consultationRatePerHour,
    String? verificationStatus,
    bool? isOnline,
    String? profilePhotoUrl,
    String? certificateDocUrl,
    String? token,
    String? counselorRole,
    String? partnerName,
    int? sessionDurationMinutes,
    int? coinsPerSession,
    int? coinBalance,
    String? googleDriveEmail,
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
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountHolder,
  }) {
    return PsychologistProfileResponseDto(
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
      association: association ?? this.association,
      specializations: specializations ?? this.specializations,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
      consultationRatePerHour:
          consultationRatePerHour ?? this.consultationRatePerHour,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      isOnline: isOnline ?? this.isOnline,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      certificateDocUrl: certificateDocUrl ?? this.certificateDocUrl,
      token: token ?? this.token,
      counselorRole: counselorRole ?? this.counselorRole,
      partnerName: partnerName ?? this.partnerName,
      sessionDurationMinutes:
          sessionDurationMinutes ?? this.sessionDurationMinutes,
      coinsPerSession: coinsPerSession ?? this.coinsPerSession,
      coinBalance: coinBalance ?? this.coinBalance,
      googleDriveEmail: googleDriveEmail ?? this.googleDriveEmail,
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
      externalApiKey: externalApiKey ?? this.externalApiKey,
      externalApiKeyCreatedAt:
          externalApiKeyCreatedAt ?? this.externalApiKeyCreatedAt,
      externalApiLastSyncAt:
          externalApiLastSyncAt ?? this.externalApiLastSyncAt,
      externalSyncCount: externalSyncCount ?? this.externalSyncCount,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankAccountHolder: bankAccountHolder ?? this.bankAccountHolder,
    );
  }

  PsychologistUserEntity toEntity() {
    VerificationStatus status;
    switch (verificationStatus.toLowerCase()) {
      case 'verified':
        status = VerificationStatus.verified;
        break;
      case 'need_revision':
        status = VerificationStatus.needRevision;
        break;
      case 'rejected':
        status = VerificationStatus.rejected;
        break;
      case 'pending':
      default:
        status = VerificationStatus.pending;
        break;
    }

    CounselorRole roleEnum;
    switch (counselorRole.toLowerCase()) {
      case 'peer_volunteer':
      case 'volunteer':
        roleEnum = CounselorRole.peerVolunteer;
        break;
      case 'professional_partner':
      case 'mitra':
        roleEnum = CounselorRole.professionalPartner;
        break;
      case 'professional_independent':
      case 'mandiri':
      default:
        roleEnum = CounselorRole.professionalIndependent;
        break;
    }

    return PsychologistUserEntity(
      id: id,
      fullName: fullName,
      titleDegree: titleDegree,
      email: email,
      strNumber: strNumber,
      sipNumber: sipNumber,
      documentType: documentType,
      issuingInstitution: issuingInstitution,
      documentExpiryDate: documentExpiryDate,
      lastEducation: lastEducation,
      strIssuingInstitution: strIssuingInstitution,
      strExpiryDate: strExpiryDate,
      strDocUrl: strDocUrl ?? certificateDocUrl,
      sipIssuingInstitution: sipIssuingInstitution,
      sipExpiryDate: sipExpiryDate,
      sipDocUrl: sipDocUrl,
      association: association,
      specializations: specializations,
      yearsOfExperience: yearsOfExperience,
      consultationRatePerHour: consultationRatePerHour,
      verificationStatus: status,
      isOnline: isOnline,
      profilePhotoUrl: profilePhotoUrl,
      certificateDocUrl: certificateDocUrl,
      role: roleEnum,
      partnerName: partnerName,
      sessionDurationMinutes: sessionDurationMinutes,
      coinsPerSession: coinsPerSession,
      coinBalance: coinBalance,
      googleDriveEmail: googleDriveEmail ?? email,
      employeeNip: employeeNip,
      isOnlinePracticeEnabled: isOnlinePracticeEnabled,
      isOfflinePracticeEnabled: isOfflinePracticeEnabled,
      offlinePlaceName: offlinePlaceName,
      offlineAddress: offlineAddress,
      offlineCity: offlineCity,
      offlineNotes: offlineNotes,
      offlineScheduleDays: offlineScheduleDays,
      offlineStartTime: offlineStartTime,
      offlineEndTime: offlineEndTime,
      externalApiKey: externalApiKey,
      externalApiKeyCreatedAt: externalApiKeyCreatedAt,
      externalApiLastSyncAt: externalApiLastSyncAt,
      externalSyncCount: externalSyncCount,
      bankName: bankName,
      bankAccountNumber: bankAccountNumber,
      bankAccountHolder: bankAccountHolder,
      isScheduleConfigured: isOnlinePracticeEnabled || (offlineScheduleDays.isNotEmpty),
    );
  }
}

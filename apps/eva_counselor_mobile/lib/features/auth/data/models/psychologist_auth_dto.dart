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
  final String association;
  final List<String> specializations;
  final int yearsOfExperience;
  final int consultationRate;
  final String certificateDocFileName;
  final String counselorRole; // 'professional_partner', 'professional_independent', 'peer_volunteer'
  final String? partnerName;
  final int sessionDurationMinutes;
  final int coinsPerSession;

  const PsychologistRegisterRequestDto({
    required this.fullName,
    required this.titleDegree,
    required this.email,
    required this.password,
    required this.strNumber,
    required this.association,
    required this.specializations,
    required this.yearsOfExperience,
    required this.consultationRate,
    required this.certificateDocFileName,
    this.counselorRole = 'professional_independent',
    this.partnerName,
    this.sessionDurationMinutes = 50,
    this.coinsPerSession = 150,
  });

  Map<String, dynamic> toJson() => {
        'full_name': fullName,
        'title_degree': titleDegree,
        'email': email,
        'password': password,
        'str_number': strNumber,
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

  const PsychologistProfileResponseDto({
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
    required this.isOnline,
    this.profilePhotoUrl,
    this.certificateDocUrl,
    this.token,
    this.counselorRole = 'professional_independent',
    this.partnerName,
    this.sessionDurationMinutes = 50,
    this.coinsPerSession = 150,
    this.coinBalance = 1250,
    this.googleDriveEmail,
  });

  factory PsychologistProfileResponseDto.fromJson(Map<String, dynamic> json) {
    return PsychologistProfileResponseDto(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      titleDegree: json['title_degree']?.toString() ?? 'M.Psi., Psikolog',
      email: json['email']?.toString() ?? '',
      strNumber: json['str_number']?.toString() ?? '',
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
      isOnline: json['is_online'] as bool? ?? true,
      profilePhotoUrl: json['profile_photo_url']?.toString(),
      certificateDocUrl: json['certificate_doc_url']?.toString(),
      token: json['token']?.toString(),
      counselorRole: json['counselor_role']?.toString() ?? 'professional_independent',
      partnerName: json['partner_name']?.toString(),
      sessionDurationMinutes: json['session_duration_minutes'] as int? ?? 50,
      coinsPerSession: json['coins_per_session'] as int? ?? 150,
      coinBalance: json['coin_balance'] as int? ?? 1250,
      googleDriveEmail: json['google_drive_email']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'title_degree': titleDegree,
        'email': email,
        'str_number': strNumber,
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
      };

  PsychologistProfileResponseDto copyWith({
    String? id,
    String? fullName,
    String? titleDegree,
    String? email,
    String? strNumber,
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
  }) {
    return PsychologistProfileResponseDto(
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
      token: token ?? this.token,
      counselorRole: counselorRole ?? this.counselorRole,
      partnerName: partnerName ?? this.partnerName,
      sessionDurationMinutes:
          sessionDurationMinutes ?? this.sessionDurationMinutes,
      coinsPerSession: coinsPerSession ?? this.coinsPerSession,
      coinBalance: coinBalance ?? this.coinBalance,
      googleDriveEmail: googleDriveEmail ?? this.googleDriveEmail,
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
      googleDriveEmail: googleDriveEmail ?? 'sarah.anindya@gmail.com',
    );
  }
}

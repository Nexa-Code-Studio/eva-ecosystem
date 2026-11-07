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
      };

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
    );
  }
}

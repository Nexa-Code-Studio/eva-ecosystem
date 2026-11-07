import '../../domain/entities/clinic_entity.dart';

class ClinicModel extends ClinicEntity {
  const ClinicModel({
    required super.id,
    required super.name,
    required super.address,
    required super.city,
    required super.distanceKm,
    required super.photoUrl,
    required super.phone,
    required super.facilities,
    super.rating = 4.8,
  });

  factory ClinicModel.fromJson(Map<String, dynamic> json) {
    return ClinicModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 1.0,
      photoUrl: json['photo_url'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      facilities: (json['facilities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rating: (json['rating'] as num?)?.toDouble() ?? 4.8,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'distance_km': distanceKm,
      'photo_url': photoUrl,
      'phone': phone,
      'facilities': facilities,
      'rating': rating,
    };
  }
}

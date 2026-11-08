import 'package:flutter/foundation.dart';

@immutable
class ClinicEntity {
  final String id;
  final String name;
  final String address;
  final String city;
  final double distanceKm;
  final String photoUrl;
  final String phone;
  final List<String> facilities;
  final double rating;

  const ClinicEntity({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.distanceKm,
    required this.photoUrl,
    required this.phone,
    required this.facilities,
    this.rating = 4.8,
  });
}

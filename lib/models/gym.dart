// lib/models/gym.dart
import 'package:equatable/equatable.dart';

class Gym extends Equatable {
  final int id;
  final String name;
  final double? latitude;
  final double? longitude;
  final String? address;
  final List<int>? openingDays;
  final String? openingTime;
  final String? closingTime;
  final String? phone;
  final String? email;
  final String? website;
  final List<String>? amenities;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Gym({
    required this.id,
    required this.name,
    this.latitude,
    this.longitude,
    this.address,
    this.openingDays,
    this.openingTime,
    this.closingTime,
    this.phone,
    this.email,
    this.website,
    this.amenities,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Gym.fromJson(Map<String, dynamic> json) {
    return Gym(
      id: json['id'] as int,
      name: json['name'] as String,
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      address: json['address'] as String?,
      openingDays: json['opening_days'] != null
          ? List<int>.from(json['opening_days'] as List)
          : null,
      openingTime: json['opening_time'] as String?,
      closingTime: json['closing_time'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      website: json['website'] as String?,
      amenities: json['amenities'] != null
          ? List<String>.from(json['amenities'] as List)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'opening_days': openingDays,
      'opening_time': openingTime,
      'closing_time': closingTime,
      'phone': phone,
      'email': email,
      'website': website,
      'amenities': amenities,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  String get formattedAddress => address ?? 'Address not available';

  String get formattedHours {
    if (openingTime == null || closingTime == null) {
      return 'Hours not available';
    }
    return '$openingTime - $closingTime';
  }

  @override
  List<Object?> get props => [
    id,
    name,
    latitude,
    longitude,
    address,
    openingDays,
    openingTime,
    closingTime,
    phone,
    email,
    website,
    amenities,
    createdAt,
    updatedAt,
  ];
}

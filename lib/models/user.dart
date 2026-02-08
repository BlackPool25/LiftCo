// lib/models/user.dart
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class User extends Equatable {
  final String id;
  final String name;
  final String? email;
  final String? phoneNumber;
  final int? age;
  final String? gender;
  final String? currentWorkoutSplit;
  final int? timeWorkingOutMonths;
  final int? homeGymId;
  final String? profilePhotoUrl;
  final String? experienceLevel;
  final String? primaryActivity;
  final String? preferredTime;
  final String? bio;
  final int reputationScore;
  final DateTime createdAt;
  final DateTime updatedAt;

  const User({
    required this.id,
    required this.name,
    this.email,
    this.phoneNumber,
    this.age,
    this.gender,
    this.currentWorkoutSplit,
    this.timeWorkingOutMonths,
    this.homeGymId,
    this.profilePhotoUrl,
    this.experienceLevel,
    this.primaryActivity,
    this.preferredTime,
    this.bio,
    this.reputationScore = 100,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isProfileComplete => 
    age != null && 
    gender != null && 
    experienceLevel != null &&
    preferredTime != null;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      phoneNumber: json['phone_number'] as String?,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      currentWorkoutSplit: json['current_workout_split'] as String?,
      timeWorkingOutMonths: json['time_working_out_months'] as int?,
      homeGymId: json['home_gym_id'] as int?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      experienceLevel: json['experience_level'] as String?,
      primaryActivity: json['primary_activity'] as String?,
      preferredTime: json['preferred_time'] as String?,
      bio: json['bio'] as String?,
      reputationScore: json['reputation_score'] as int? ?? 100,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone_number': phoneNumber,
      'age': age,
      'gender': gender,
      'current_workout_split': currentWorkoutSplit,
      'time_working_out_months': timeWorkingOutMonths,
      'home_gym_id': homeGymId,
      'profile_photo_url': profilePhotoUrl,
      'experience_level': experienceLevel,
      'primary_activity': primaryActivity,
      'preferred_time': preferredTime,
      'bio': bio,
      'reputation_score': reputationScore,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? phoneNumber,
    int? age,
    String? gender,
    String? currentWorkoutSplit,
    int? timeWorkingOutMonths,
    int? homeGymId,
    String? profilePhotoUrl,
    String? experienceLevel,
    String? primaryActivity,
    String? preferredTime,
    String? bio,
    int? reputationScore,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      currentWorkoutSplit: currentWorkoutSplit ?? this.currentWorkoutSplit,
      timeWorkingOutMonths: timeWorkingOutMonths ?? this.timeWorkingOutMonths,
      homeGymId: homeGymId ?? this.homeGymId,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      primaryActivity: primaryActivity ?? this.primaryActivity,
      preferredTime: preferredTime ?? this.preferredTime,
      bio: bio ?? this.bio,
      reputationScore: reputationScore ?? this.reputationScore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id, name, email, phoneNumber, age, gender,
    currentWorkoutSplit, timeWorkingOutMonths, homeGymId,
    profilePhotoUrl, experienceLevel, primaryActivity,
    preferredTime, bio, reputationScore, createdAt, updatedAt,
  ];
}

// Enum values for dropdowns/cards
class WorkoutSplit {
  static const List<Map<String, dynamic>> values = [
    {'value': 'push', 'label': 'Push', 'icon': Icons.fitness_center},
    {'value': 'pull', 'label': 'Pull', 'icon': Icons.fitness_center},
    {'value': 'legs', 'label': 'Legs', 'icon': Icons.fitness_center},
    {'value': 'full_body', 'label': 'Full Body', 'icon': Icons.accessibility},
    {'value': 'upper', 'label': 'Upper', 'icon': Icons.fitness_center},
    {'value': 'lower', 'label': 'Lower', 'icon': Icons.fitness_center},
    {'value': 'cardio', 'label': 'Cardio', 'icon': Icons.directions_run},
    {'value': 'yoga', 'label': 'Yoga', 'icon': Icons.self_improvement},
    {'value': 'crossfit', 'label': 'CrossFit', 'icon': Icons.sports},
    {'value': 'other', 'label': 'Other', 'icon': Icons.more_horiz},
  ];
}

class ExperienceLevel {
  static const List<Map<String, dynamic>> values = [
    {
      'value': 'beginner',
      'label': 'Beginner',
      'description': 'Just getting started',
      'color': 0xFF22C55E,
      'icon': Icons.spa,  // Changed from seed to spa
    },
    {
      'value': 'intermediate',
      'label': 'Intermediate',
      'description': 'Regular gym goer',
      'color': 0xFFF59E0B,
      'icon': Icons.local_fire_department,
    },
    {
      'value': 'advanced',
      'label': 'Advanced',
      'description': 'Years of training',
      'color': 0xFFEF4444,
      'icon': Icons.emoji_events,
    },
  ];
}

class PreferredTime {
  // Updated to only include gym hours (5am-9pm)
  static const List<Map<String, dynamic>> values = [
    {
      'value': 'early_morning',
      'label': 'Early Bird',
      'time': '5AM - 8AM',
      'icon': Icons.wb_twilight,
      'gradient': [0xFFFF6B6B, 0xFFFF8E53],
    },
    {
      'value': 'morning',
      'label': 'Morning',
      'time': '8AM - 12PM',
      'icon': Icons.wb_sunny,
      'gradient': [0xFFF59E0B, 0xFFFCD34D],
    },
    {
      'value': 'afternoon',
      'label': 'Afternoon',
      'time': '12PM - 5PM',
      'icon': Icons.wb_cloudy,
      'gradient': [0xFF3B82F6, 0xFF60A5FA],
    },
    {
      'value': 'evening',
      'label': 'Evening',
      'time': '5PM - 9PM',
      'icon': Icons.nights_stay,
      'gradient': [0xFF6366F1, 0xFF8B5CF6],
    },
  ];
}

class Gender {
  static const List<Map<String, dynamic>> values = [
    {'value': 'male', 'label': 'Male', 'icon': Icons.male},
    {'value': 'female', 'label': 'Female', 'icon': Icons.female},
    {'value': 'non_binary', 'label': 'Non-Binary', 'icon': Icons.transgender},
    {'value': 'prefer_not_to_say', 'label': 'Prefer not to say', 'icon': Icons.remove},
  ];
}

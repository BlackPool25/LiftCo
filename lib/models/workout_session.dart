// lib/models/workout_session.dart
import 'package:equatable/equatable.dart';

class WorkoutSession extends Equatable {
  final String id;
  final int gymId;
  final String hostUserId;
  final String title;
  final String sessionType;
  final String? description;
  final DateTime startTime;
  final int durationMinutes;
  final int maxCapacity;
  final int currentCount;
  final String status;
  final String? intensityLevel;
  final bool womenOnly;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Optional joined fields
  final Map<String, dynamic>? host;
  final Map<String, dynamic>? gym;
  final List<SessionMember>? members;
  final bool? isUserJoined;

  const WorkoutSession({
    required this.id,
    required this.gymId,
    required this.hostUserId,
    required this.title,
    required this.sessionType,
    this.description,
    required this.startTime,
    required this.durationMinutes,
    required this.maxCapacity,
    required this.currentCount,
    required this.status,
    this.intensityLevel,
    this.womenOnly = false,
    required this.createdAt,
    required this.updatedAt,
    this.host,
    this.gym,
    this.members,
    this.isUserJoined,
  });

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    return WorkoutSession(
      id: json['id'] as String,
      gymId: json['gym_id'] as int,
      hostUserId: json['host_user_id'] as String,
      title: json['title'] as String,
      sessionType: json['session_type'] as String,
      description: json['description'] as String?,
      startTime: DateTime.parse(json['start_time'] as String),
      durationMinutes: json['duration_minutes'] as int,
      maxCapacity: json['max_capacity'] as int,
      currentCount: json['current_count'] as int,
      status: json['status'] as String,
      intensityLevel: json['intensity_level'] as String?,
      womenOnly: json['women_only'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      host: json['host'] as Map<String, dynamic>?,
      gym: json['gym'] as Map<String, dynamic>?,
      members: json['members'] != null
          ? (json['members'] as List)
                .map((m) => SessionMember.fromJson(m))
                .toList()
          : null,
      isUserJoined: json['is_user_joined'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gym_id': gymId,
      'host_user_id': hostUserId,
      'title': title,
      'session_type': sessionType,
      'description': description,
      'start_time': startTime.toIso8601String(),
      'duration_minutes': durationMinutes,
      'max_capacity': maxCapacity,
      'current_count': currentCount,
      'status': status,
      'intensity_level': intensityLevel,
      'women_only': womenOnly,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isFull => currentCount >= maxCapacity;
  bool get isUpcoming => status == 'upcoming';
  bool get isInProgress => status == 'in_progress';
  bool get isFinished => status == 'finished';
  bool get isCancelled => status == 'cancelled';
  bool get isJoinable => isUpcoming && !isFull;

  int get availableSpots => maxCapacity - currentCount;

  DateTime get endTime => startTime.add(Duration(minutes: durationMinutes));

  String get formattedTime {
    final hour = startTime.hour.toString().padLeft(2, '0');
    final minute = startTime.minute.toString().padLeft(2, '0');
    final endHour = endTime.hour.toString().padLeft(2, '0');
    final endMinute = endTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute - $endHour:$endMinute';
  }

  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDate = DateTime(
      startTime.year,
      startTime.month,
      startTime.day,
    );
    final difference = sessionDate.difference(today).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    if (difference < 7) {
      final weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return weekdays[startTime.weekday - 1];
    }
    return '${startTime.day}/${startTime.month}/${startTime.year}';
  }

  String get durationText {
    if (durationMinutes < 60) return '$durationMinutes min';
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  bool get isWomenOnly => womenOnly;

  @override
  List<Object?> get props => [
    id,
    gymId,
    hostUserId,
    title,
    sessionType,
    description,
    startTime,
    durationMinutes,
    maxCapacity,
    currentCount,
    status,
    intensityLevel,
    womenOnly,
    createdAt,
    updatedAt,
    host,
    gym,
    members,
    isUserJoined,
  ];
}

class SessionMember extends Equatable {
  final String id;
  final String sessionId;
  final String userId;
  final String status;
  final DateTime joinedAt;
  final Map<String, dynamic>? user;

  const SessionMember({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.status,
    required this.joinedAt,
    this.user,
  });

  factory SessionMember.fromJson(Map<String, dynamic> json) {
    return SessionMember(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      userId: json['user_id'] as String,
      status: json['status'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      user: json['user'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [id, sessionId, userId, status, joinedAt, user];
}

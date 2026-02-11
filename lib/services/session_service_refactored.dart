// lib/services/session_service_refactored.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout_session.dart';
import 'supabase_service.dart';

/// Refactored Session Service using Edge Functions
/// Provides cleaner API using standardized CRUD operations
class SessionService {
  final SupabaseService _api;
  final SupabaseClient _client;

  SessionService(SupabaseClient client)
    : _client = client,
      _api = SupabaseService(client);

  /// Create a new workout session
  Future<WorkoutSession> createSession({
    required int gymId,
    required String title,
    required String sessionType,
    String? description,
    required DateTime startTime,
    required int durationMinutes,
    int maxCapacity = 4,
    String? intensityLevel,
    bool womenOnly = false,
  }) async {
    try {
      final response = await _api.createSession(
        gymId: gymId,
        title: title,
        sessionType: sessionType,
        description: description,
        startTime: startTime,
        durationMinutes: durationMinutes,
        maxCapacity: maxCapacity,
        intensityLevel: intensityLevel,
        womenOnly: womenOnly,
      );

      return WorkoutSession.fromJson(
        response['session'] as Map<String, dynamic>,
      );
    } catch (e) {
      debugPrint('Error creating session: $e');
      throw Exception('Failed to create session: $e');
    }
  }

  /// Get a single session by ID with full details
  Future<WorkoutSession?> getSession(String sessionId) async {
    try {
      final response = await _api.getSession(sessionId);

      if (response['session'] != null) {
        return WorkoutSession.fromJson(
          response['session'] as Map<String, dynamic>,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching session: $e');
      throw Exception('Failed to fetch session: $e');
    }
  }

  /// List sessions with pagination and filters
  Future<List<WorkoutSession>> listSessions({
    int? gymId,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _api.listSessions(
        gymId: gymId,
        status: status,
        limit: limit,
        offset: offset,
      );

      final sessions = response['sessions'] as List<dynamic>? ?? [];
      return sessions
          .map((s) => WorkoutSession.fromJson(s as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error listing sessions: $e');
      throw Exception('Failed to list sessions: $e');
    }
  }

  /// Get all upcoming sessions (convenience method)
  Future<List<WorkoutSession>> getUpcomingSessions({
    int? gymId,
    int limit = 50,
  }) async {
    return listSessions(gymId: gymId, status: 'upcoming', limit: limit);
  }

  /// Join a session
  Future<void> joinSession(String sessionId) async {
    try {
      await _api.joinSession(sessionId);
    } catch (e) {
      debugPrint('Error joining session: $e');
      throw Exception('Failed to join session: $e');
    }
  }

  /// Leave a session
  Future<void> leaveSession(String sessionId) async {
    try {
      await _api.leaveSession(sessionId);
    } catch (e) {
      debugPrint('Error leaving session: $e');
      throw Exception('Failed to leave session: $e');
    }
  }

  /// Cancel a session (host only)
  Future<void> cancelSession(String sessionId) async {
    try {
      await _api.deleteSession(sessionId);
    } catch (e) {
      debugPrint('Error cancelling session: $e');
      throw Exception('Failed to cancel session: $e');
    }
  }

  /// Get current user's joined sessions
  Future<List<WorkoutSession>> getUserSessions() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get user's memberships using direct query
      final memberships = await _client
          .from('session_members')
          .select('session_id')
          .eq('user_id', user.id)
          .eq('status', 'joined');

      if (memberships.isEmpty) return [];

      final sessionIds = memberships
          .map((m) => m['session_id'] as String)
          .toList();

      // Get session details using edge function
      final sessions = <WorkoutSession>[];
      for (final sessionId in sessionIds) {
        try {
          final response = await _api.getSession(sessionId);
          if (response['session'] != null) {
            final session = WorkoutSession.fromJson(
              response['session'] as Map<String, dynamic>,
            );
            if (session.status != 'cancelled') {
              sessions.add(session);
            }
          }
        } catch (e) {
          debugPrint('Error fetching session $sessionId: $e');
        }
      }

      // Sort by start time
      sessions.sort((a, b) => a.startTime.compareTo(b.startTime));
      return sessions;
    } catch (e) {
      debugPrint('Error fetching user sessions: $e');
      throw Exception('Failed to fetch user sessions: $e');
    }
  }

  /// Check if user has joined a specific session
  Future<bool> isUserJoined(String sessionId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;

      final membership = await _client
          .from('session_members')
          .select()
          .eq('session_id', sessionId)
          .eq('user_id', user.id)
          .eq('status', 'joined')
          .maybeSingle();

      return membership != null;
    } catch (e) {
      debugPrint('Error checking membership: $e');
      return false;
    }
  }

  /// Stream of sessions for real-time updates
  Stream<List<WorkoutSession>> streamSessions({int? gymId}) {
    var builder = _client.from('workout_sessions').stream(primaryKey: ['id']);

    return builder.map((data) {
      var sessions = data
          .map((json) => WorkoutSession.fromJson(json))
          .where((s) => s.status == 'upcoming')
          .where((s) => s.startTime.isAfter(DateTime.now()))
          .toList();

      if (gymId != null) {
        sessions = sessions.where((s) => s.gymId == gymId).toList();
      }

      return sessions;
    });
  }
}

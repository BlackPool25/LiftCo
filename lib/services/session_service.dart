// lib/services/session_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout_session.dart';

class SessionService {
  final SupabaseClient _supabase;

  SessionService(this._supabase);

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
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get user profile
      final userProfile = await _supabase
          .from('users')
          .select('id')
          .eq('id', user.id)
          .single();

      // Create session - current_count will be 0, trigger will increment when host joins
      final response = await _supabase
          .from('workout_sessions')
          .insert({
            'gym_id': gymId,
            'host_user_id': userProfile['id'],
            'title': title,
            'session_type': sessionType,
            'description': description,
            'start_time': startTime.toIso8601String(),
            'duration_minutes': durationMinutes,
            'max_capacity': maxCapacity,
            'current_count': 0,
            'status': 'upcoming',
            'intensity_level': intensityLevel,
            'women_only': womenOnly,
          })
          .select()
          .single();

      // Add host as first member - trigger will increment current_count
      await _supabase.from('session_members').insert({
        'session_id': response['id'],
        'user_id': userProfile['id'],
        'status': 'joined',
      });

      // Re-fetch to get the updated count from trigger
      final updatedResponse = await _supabase
          .from('workout_sessions')
          .select('''
            *,
            host:host_user_id(id, name),
            gym:gym_id(name)
          ''')
          .eq('id', response['id'] as String)
          .single();

      return WorkoutSession.fromJson(updatedResponse);
    } on PostgrestException catch (e) {
      debugPrint('Error creating session: ${e.message}');
      throw Exception('Failed to create session: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error creating session: $e');
      throw Exception('Failed to create session');
    }
  }

  /// Join a session
  Future<void> joinSession(String sessionId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get session details
      final session = await _supabase
          .from('workout_sessions')
          .select('*')
          .eq('id', sessionId)
          .single();

      // Check if session is joinable
      if (session['status'] == 'cancelled') {
        throw Exception('Cannot join a cancelled session');
      }

      if (session['status'] == 'finished') {
        throw Exception('Cannot join a finished session');
      }

      // Check if already joined
      final existingMembership = await _supabase
          .from('session_members')
          .select()
          .eq('session_id', sessionId)
          .eq('user_id', user.id)
          .eq('status', 'joined')
          .maybeSingle();

      if (existingMembership != null) {
        throw Exception('You are already a member of this session');
      }

      // Check capacity
      if (session['current_count'] >= session['max_capacity']) {
        throw Exception('Session is full');
      }

      // Check for time conflicts
      final sessionStart = DateTime.parse(session['start_time']);
      final sessionEnd = sessionStart.add(
        Duration(minutes: session['duration_minutes'] as int),
      );

      // Check for time conflicts - fetch user's joined sessions
      final userMemberships = await _supabase
          .from('session_members')
          .select('session_id')
          .eq('user_id', user.id)
          .eq('status', 'joined');

      for (final membership in userMemberships) {
        final otherSessionId = membership['session_id'] as String;
        if (otherSessionId == sessionId) continue;

        // Fetch the other session details
        final otherSession = await _supabase
            .from('workout_sessions')
            .select('start_time, duration_minutes, status')
            .eq('id', otherSessionId)
            .single();

        if (otherSession['status'] == 'cancelled' ||
            otherSession['status'] == 'finished') {
          continue;
        }

        final otherStart = DateTime.parse(otherSession['start_time']);
        final otherEnd = otherStart.add(
          Duration(minutes: otherSession['duration_minutes'] as int),
        );

        // Check for overlap
        if (sessionStart.isBefore(otherEnd) && sessionEnd.isAfter(otherStart)) {
          throw Exception('You have another session at this time');
        }
      }

      // Join session - trigger will automatically increment current_count
      await _supabase.from('session_members').insert({
        'session_id': sessionId,
        'user_id': user.id,
        'status': 'joined',
      });
    } on PostgrestException catch (e) {
      debugPrint('Error joining session: ${e.message}');
      throw Exception('Failed to join session: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error joining session: $e');
      if (e is Exception) rethrow;
      throw Exception('Failed to join session');
    }
  }

  /// Leave a session
  Future<void> leaveSession(String sessionId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get session details
      final session = await _supabase
          .from('workout_sessions')
          .select('host_user_id, current_count')
          .eq('id', sessionId)
          .single();

      // Check if user is the host
      if (session['host_user_id'] == user.id) {
        throw Exception('Host cannot leave the session. Cancel it instead.');
      }

      // Update membership status - trigger will automatically decrement current_count
      await _supabase
          .from('session_members')
          .update({'status': 'cancelled'})
          .eq('session_id', sessionId)
          .eq('user_id', user.id);
    } on PostgrestException catch (e) {
      debugPrint('Error leaving session: ${e.message}');
      throw Exception('Failed to leave session: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error leaving session: $e');
      if (e is Exception) rethrow;
      throw Exception('Failed to leave session');
    }
  }

  /// Get session details with members
  Future<WorkoutSession?> getSession(String sessionId) async {
    try {
      final response = await _supabase
          .from('workout_sessions')
          .select('''
            *,
            host:host_user_id(id, name),
            gym:gym_id(name),
            members:session_members(id, user_id, status, joined_at, user:user_id(id, name))
          ''')
          .eq('id', sessionId)
          .maybeSingle();

      if (response == null) return null;
      return WorkoutSession.fromJson(response);
    } on PostgrestException catch (e) {
      debugPrint('Error fetching session: ${e.message}');
      throw Exception('Failed to fetch session: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error fetching session: $e');
      throw Exception('Failed to fetch session');
    }
  }

  /// Get user's sessions
  Future<List<WorkoutSession>> getUserSessions() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get user's memberships
      final memberships = await _supabase
          .from('session_members')
          .select('session_id')
          .eq('user_id', user.id)
          .eq('status', 'joined');

      if (memberships.isEmpty) return [];

      // Get session IDs
      final sessionIds = memberships
          .map((m) => m['session_id'] as String)
          .toList();

      // Fetch sessions separately
      final response = await _supabase
          .from('workout_sessions')
          .select('''
            *,
            host:host_user_id(id, name),
            gym:gym_id(name)
          ''')
          .inFilter('id', sessionIds)
          .order('start_time', ascending: true);

      return response
          .map((json) => WorkoutSession.fromJson(json))
          .where((s) => s.status != 'cancelled')
          .toList();
    } on PostgrestException catch (e) {
      debugPrint('Error fetching user sessions: ${e.message}');
      throw Exception('Failed to fetch sessions: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error fetching user sessions: $e');
      throw Exception('Failed to fetch sessions');
    }
  }

  /// Cancel a session (host only)
  Future<void> cancelSession(String sessionId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get session details
      final session = await _supabase
          .from('workout_sessions')
          .select('host_user_id, status')
          .eq('id', sessionId)
          .single();

      // Check if user is the host
      if (session['host_user_id'] != user.id) {
        throw Exception('Only the host can cancel the session');
      }

      // Check if session is already cancelled or finished
      if (session['status'] == 'cancelled') {
        throw Exception('Session is already cancelled');
      }

      if (session['status'] == 'finished') {
        throw Exception('Cannot cancel a finished session');
      }

      // Cancel all memberships
      await _supabase
          .from('session_members')
          .update({'status': 'cancelled'})
          .eq('session_id', sessionId)
          .eq('status', 'joined');

      // Update session status
      await _supabase
          .from('workout_sessions')
          .update({'status': 'cancelled'})
          .eq('id', sessionId);
    } on PostgrestException catch (e) {
      debugPrint('Error cancelling session: ${e.message}');
      throw Exception('Failed to cancel session: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error cancelling session: $e');
      if (e is Exception) rethrow;
      throw Exception('Failed to cancel session');
    }
  }

  /// Check if user is a member of a session
  Future<bool> isUserJoined(String sessionId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      final membership = await _supabase
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

  /// Subscribe to all session changes (create, update, delete)
  /// Returns a stream of session changes
  Stream<List<WorkoutSession>> subscribeToSessions({int? gymId}) {
    return _supabase.from('workout_sessions').stream(primaryKey: ['id']).map((
      data,
    ) {
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

  /// Subscribe to a specific session's changes
  Stream<WorkoutSession?> subscribeToSession(String sessionId) {
    return _supabase
        .from('workout_sessions')
        .stream(primaryKey: ['id'])
        .asyncMap((data) async {
          Map<String, dynamic>? session;
          for (final row in data) {
            if (row['id'] == sessionId) {
              session = row;
              break;
            }
          }

          if (session == null) return null;

          try {
            return await getSession(sessionId);
          } catch (e) {
            return WorkoutSession.fromJson(session);
          }
        });
  }

  /// Subscribe to session members changes
  Stream<List<dynamic>> subscribeToSessionMembers(String sessionId) {
    return _supabase
        .from('session_members')
        .stream(primaryKey: ['id'])
        .map(
          (data) => data.where((m) => m['session_id'] == sessionId).toList(),
        );
  }

  /// Subscribe to user's joined sessions
  Stream<List<WorkoutSession>> subscribeToUserSessions() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    // Subscribe to session_members table for this user
    return _supabase
        .from('session_members')
        .stream(primaryKey: ['id'])
        .map(
          (data) => data
              .where((m) => m['user_id'] == user.id && m['status'] == 'joined')
              .toList(),
        )
        .asyncMap((memberships) async {
          if (memberships.isEmpty) return <WorkoutSession>[];

          final sessionIds = memberships
              .map((m) => m['session_id'] as String)
              .toList();

          // Fetch full session details
          final response = await _supabase
              .from('workout_sessions')
              .select('''
                *,
                host:host_user_id(id, name),
                gym:gym_id(name)
              ''')
              .inFilter('id', sessionIds)
              .order('start_time', ascending: true);

          return response
              .map((json) => WorkoutSession.fromJson(json))
              .where((s) => s.status != 'cancelled')
              .toList();
        });
  }
}

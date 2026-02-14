// lib/services/session_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout_session.dart';
import 'supabase_service.dart';

class SessionService {
  final SupabaseClient _supabase;
  late final SupabaseService _api;

  static const Duration _listTtl = Duration(seconds: 25);
  static const Duration _detailsTtl = Duration(seconds: 12);

  final Map<String, _CacheEntry<List<WorkoutSession>>> _listCache =
    <String, _CacheEntry<List<WorkoutSession>>>{};
  final Map<String, _CacheEntry<WorkoutSession?>> _detailsCache =
    <String, _CacheEntry<WorkoutSession?>>{};
  final Map<String, Future<List<WorkoutSession>>> _listInFlight =
    <String, Future<List<WorkoutSession>>>{};
  final Map<String, Future<WorkoutSession?>> _detailsInFlight =
    <String, Future<WorkoutSession?>>{};

  SessionService(this._supabase) {
    _api = SupabaseService(_supabase);
  }

  String _listCacheKey({
    required int? gymId,
    required String? status,
    required String? sessionType,
    required String? dateFrom,
    required String? dateTo,
    required int limit,
    required int offset,
    required bool joinedOnly,
  }) {
    return [
      'gymId=${gymId ?? ""}',
      'status=${status ?? ""}',
      'type=${sessionType ?? ""}',
      'from=${dateFrom ?? ""}',
      'to=${dateTo ?? ""}',
      'limit=$limit',
      'offset=$offset',
      'joinedOnly=$joinedOnly',
    ].join('&');
  }

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
      await _api.joinSession(sessionId);
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
      await _api.leaveSession(sessionId);
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
  Future<WorkoutSession?> getSession(
    String sessionId, {
    bool forceRefresh = false,
  }) async {
    try {
      final cached = _detailsCache[sessionId];
      if (!forceRefresh && cached != null && !cached.isExpired(_detailsTtl)) {
        return cached.value;
      }

      if (!forceRefresh) {
        final inFlight = _detailsInFlight[sessionId];
        if (inFlight != null) return inFlight;
      }

      final future = () async {
        final response = await _api.getSession(sessionId);

        if (response['session'] == null) {
          _detailsCache[sessionId] = _CacheEntry<WorkoutSession?>(null);
          return null;
        }

        final parsed = WorkoutSession.fromJson(
          response['session'] as Map<String, dynamic>,
        );
        _detailsCache[sessionId] = _CacheEntry<WorkoutSession?>(parsed);
        return parsed;
      }();

      _detailsInFlight[sessionId] = future;
      return await future;
    } on PostgrestException catch (e) {
      debugPrint('Error fetching session: ${e.message}');
      throw Exception('Failed to fetch session: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error fetching session: $e');
      throw Exception('Failed to fetch session');
    } finally {
      _detailsInFlight.remove(sessionId);
    }
  }

  /// Get user's sessions
  Future<List<WorkoutSession>> getUserSessions({bool forceRefresh = false}) async {
    try {
      final sessions = await listSessions(
        status: 'upcoming',
        limit: 100,
        offset: 0,
        joinedOnly: true,
        forceRefresh: forceRefresh,
      );

      sessions.sort((a, b) => a.startTime.compareTo(b.startTime));
      return sessions;
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
      await _api.deleteSession(sessionId);
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
      final session = await getSession(sessionId);
      return session?.isUserJoined ?? false;
    } catch (e) {
      debugPrint('Error checking membership: $e');
      return false;
    }
  }

  /// List sessions with optional filters
  Future<List<WorkoutSession>> listSessions({
    int? gymId,
    String? status,
    String? sessionType,
    String? dateFrom,
    String? dateTo,
    int limit = 50,
    int offset = 0,
    bool joinedOnly = false,
    bool forceRefresh = false,
  }) async {
    final key = _listCacheKey(
      gymId: gymId,
      status: status,
      sessionType: sessionType,
      dateFrom: dateFrom,
      dateTo: dateTo,
      limit: limit,
      offset: offset,
      joinedOnly: joinedOnly,
    );

    final cached = _listCache[key];
    if (!forceRefresh && cached != null && !cached.isExpired(_listTtl)) {
      return cached.value;
    }

    if (!forceRefresh) {
      final inFlight = _listInFlight[key];
      if (inFlight != null) return inFlight;
    }

    final future = () async {
      final response = await _api.listSessions(
        gymId: gymId,
        status: status,
        sessionType: sessionType,
        dateFrom: dateFrom,
        dateTo: dateTo,
        limit: limit,
        offset: offset,
        joinedOnly: joinedOnly,
      );

      final parsed = (response['sessions'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WorkoutSession.fromJson)
          .toList();
      _listCache[key] = _CacheEntry<List<WorkoutSession>>(parsed);
      return parsed;
    }();

    _listInFlight[key] = future;
    try {
      return await future;
    } finally {
      _listInFlight.remove(key);
    }
  }

  /// Subscribe to all session changes (create, update, delete)
  /// Returns a stream of session changes
  Stream<List<WorkoutSession>> subscribeToSessions({int? gymId}) {
    return Stream.periodic(
      const Duration(seconds: 6),
      (_) => null,
    ).asyncMap((_) async {
      final sessions = await listSessions(
        gymId: gymId,
        status: 'upcoming',
        limit: 50,
      );
      return sessions
          .where((s) => s.status == 'upcoming')
          .where((s) => s.startTime.isAfter(DateTime.now()))
          .toList();
    }).startWithFuture(
      listSessions(gymId: gymId, status: 'upcoming', limit: 50),
    );
  }

  /// Subscribe to a specific session's changes
  Stream<WorkoutSession?> subscribeToSession(String sessionId) {
    return Stream.periodic(
      const Duration(seconds: 5),
      (_) => null,
    )
        .asyncMap((_) => getSession(sessionId))
        .startWithFuture(getSession(sessionId));
  }

  /// Subscribe to session members changes
  Stream<List<dynamic>> subscribeToSessionMembers(String sessionId) {
    return subscribeToSession(sessionId).map((session) {
      return (session?.members ?? const <SessionMember>[])
          .map(
            (member) => {
              'id': member.id,
              'session_id': member.sessionId,
              'user_id': member.userId,
              'status': member.status,
              'joined_at': member.joinedAt.toIso8601String(),
              'user': member.user,
            },
          )
          .toList();
    });
  }

  /// Subscribe to user's joined sessions
  Stream<List<WorkoutSession>> subscribeToUserSessions() {
    return Stream.periodic(
      const Duration(seconds: 6),
      (_) => null,
    ).asyncMap((_) => getUserSessions()).startWithFuture(getUserSessions());
  }
}

class _CacheEntry<T> {
  final T value;
  final DateTime createdAt;

  _CacheEntry(this.value) : createdAt = DateTime.now();

  bool isExpired(Duration ttl) => DateTime.now().difference(createdAt) > ttl;
}

extension _StreamStartWithFuture<T> on Stream<T> {
  Stream<T> startWithFuture(Future<T> futureValue) async* {
    yield await futureValue;
    yield* this;
  }
}

// lib/services/gym_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gym.dart';
import '../models/workout_session.dart';
import 'supabase_service.dart';

class GymService {
  final SupabaseClient _supabase;
  late final SupabaseService _api;

  static const Duration _gymSessionsTtl = Duration(seconds: 25);
  final Map<int, _CacheEntry<List<WorkoutSession>>> _gymSessionsCache =
      <int, _CacheEntry<List<WorkoutSession>>>{};
  final Map<int, Future<List<WorkoutSession>>> _gymSessionsInFlight =
      <int, Future<List<WorkoutSession>>>{};

  GymService(this._supabase) {
    _api = SupabaseService(_supabase);
  }

  /// Fetch all gyms with optional search
  Future<List<Gym>> getGyms({String? searchQuery}) async {
    try {
      final response = await _api.listGyms(search: searchQuery);
      final data = (response['gyms'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();

      return data.map((json) => Gym.fromJson(json)).toList();
    } on PostgrestException catch (e) {
      debugPrint('Error fetching gyms: ${e.message}');
      throw Exception('Failed to fetch gyms: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error fetching gyms: $e');
      throw Exception('Failed to fetch gyms');
    }
  }

  /// Get a single gym by ID
  Future<Gym?> getGymById(int id) async {
    try {
      final response = await _api.getGym(id);
      final gymJson = response['gym'] as Map<String, dynamic>?;

      if (gymJson == null) return null;
      return Gym.fromJson(gymJson);
    } on PostgrestException catch (e) {
      debugPrint('Error fetching gym: ${e.message}');
      throw Exception('Failed to fetch gym: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error fetching gym: $e');
      throw Exception('Failed to fetch gym');
    }
  }

  /// Get upcoming sessions for a gym
  Future<List<WorkoutSession>> getGymSessions(
    int gymId, {
    bool forceRefresh = false,
  }) async {
    try {
      final cached = _gymSessionsCache[gymId];
      if (!forceRefresh && cached != null && !cached.isExpired(_gymSessionsTtl)) {
        return cached.value;
      }

      if (!forceRefresh) {
        final inFlight = _gymSessionsInFlight[gymId];
        if (inFlight != null) return inFlight;
      }

      final future = () async {
      final response = await _api.listSessions(
        gymId: gymId,
        status: 'upcoming',
        limit: 50,
        offset: 0,
      );

      final sessions = (response['sessions'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WorkoutSession.fromJson)
          .toList();

        _gymSessionsCache[gymId] = _CacheEntry<List<WorkoutSession>>(sessions);
        return sessions;
      }();

      _gymSessionsInFlight[gymId] = future;
      try {
        return await future;
      } finally {
        _gymSessionsInFlight.remove(gymId);
      }
    } on PostgrestException catch (e) {
      debugPrint('Error fetching gym sessions: ${e.message}');
      throw Exception('Failed to fetch sessions: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected error fetching gym sessions: $e');
      throw Exception('Failed to fetch sessions');
    }
  }

  /// Search gyms by name or address
  Future<List<Gym>> searchGyms(String query) async {
    if (query.isEmpty) return getGyms();

    return getGyms(searchQuery: query);
  }
}

class _CacheEntry<T> {
  final T value;
  final DateTime createdAt;

  _CacheEntry(this.value) : createdAt = DateTime.now();

  bool isExpired(Duration ttl) => DateTime.now().difference(createdAt) > ttl;
}
